//
//  ModelProvider.swift
//
//
//  Created by Leko Murphy on 5/11/24.
//

import Combine
import SwiftData
import Foundation

protocol ModelProviding {
    
    func streamModel<T: BaseModel>(type: T.Type, id: String) -> AnyPublisher<ModelQueryResult<T>, Never>
    
    func streamCollection<T: BaseModel>(type: T.Type, query: ModelQuery<T>?) -> AnyPublisher<ListModelQueryResult<T>, Never>
}

class ModelProvider: ModelProviding {
        
    private var cancellables: [AnyHashable: AnyCancellable] = [:]
    private var subjects: [AnyHashable: CurrentValueSubject<Any, Never>] = [:]
    private var subscriberCounts: [AnyHashable: Int] = [:]
    
    private let databaseManager: DatabaseManaging
    private let networkManager: NetworkManaging
    
    private let queue = DispatchQueue(label: "com.enceladus.streammanager")
    
    init(databaseManager: DatabaseManaging, networkManager: NetworkManaging) {
        self.databaseManager = databaseManager
        self.networkManager = networkManager
    }
    
    func streamModel<T: BaseModel>(type: T.Type, id: String) -> AnyPublisher<ModelQueryResult<T>, Never> {
        let key = StreamKey<T>(
            model: ModelWrapper(type),
            isList: false,
            query: ModelQuery(
                urlQueryItems: [URLQueryItem(name: "id", value: id)],
                predicate: .equatable("\(String(reflecting: T.self))-id-\(id)", #Predicate { $0.id == id })
            )
        )
        
        let subject: CurrentValueSubject<Any, Never>
        
        if let existingSubject = subjects[key] {
            subject = existingSubject
        } else {
            assert(
                subscriberCounts[key] == nil || subscriberCounts[key] == 0,
                "There should be no subscriber if subjects is nil"
            )
            subject = CurrentValueSubject<Any, Never>(ModelQueryResult<T>.loading)
            setSubject(subject, for: key)
        }
        
        incrementSubscriberCount(for: key)
        
        if getCancellable(for: key) == nil {
            startPollingModelDetail(type: type, id: id, key: key)
        }
        
        return subject
            .map { model in
                guard let result = model as? ModelQueryResult<T> else {
                    assertionFailure("Unexpected model type")
                    return .error(StreamManagerError.modelMismatchInternalError)
                }
                return result
            }
            .handleEvents(
                receiveCancel: { [weak self] in
                    guard let self = self else { return }
                    self.subscriberCounts[key]! -= 1
                    if self.subscriberCounts[key]! == 0 {
                        self.stopPolling(key: key)
                    }
                }
            )
            .eraseToAnyPublisher()
    }
    
    func streamCollection<T: BaseModel>(type: T.Type, query: ModelQuery<T>? = nil) -> AnyPublisher<ListModelQueryResult<T>, Never> {
        let key = StreamKey(
            model: ModelWrapper(type),
            isList: true,
            query: query
        )
        
        let subject: CurrentValueSubject<Any, Never>
        
        if let existingSubject = subjects[key] {
            subject = existingSubject
        } else {
            assert(
                subscriberCounts[key] == nil || subscriberCounts[key] == 0,
                "There should be no subscriber if subjects is nil"
            )
            subject = CurrentValueSubject<Any, Never>(ListModelQueryResult<T>.loading)
            setSubject(subject, for: key)
        }
        
        incrementSubscriberCount(for: key)
        
        if getCancellable(for: key) == nil {
            startPollingModelList(type: type, key: key)
        }
        
        return subject
            .map { model in
                guard let result = model as? ListModelQueryResult<T> else {
                    assertionFailure("Unexpected model type")
                    return .error(StreamManagerError.modelMismatchInternalError)
                }
                return result
            }
            .handleEvents(
                receiveCancel: { [weak self] in
                    guard let self = self else { return }
                    self.subscriberCounts[key]! -= 1
                    if self.subscriberCounts[key]! == 0 {
                        self.stopPolling(key: key)
                    }
                }
            )
            .eraseToAnyPublisher()
    }
    
    private func startPollingModelDetail<T: BaseModel>(type: T.Type, id: StringConvertible, key: StreamKey<T>) {
        
        let pollInterval = type.pollInterval
        
        cancellables[key] = Timer.publish(every: pollInterval, on: .main, in: .common)
            .autoconnect()
            .prepend(.now)
            .flatMap { [weak self, networkManager] _ -> AnyPublisher<ModelQueryResult<T>, Never> in
                if let cachedModel: T = try? self?.fetchCachedModels(for: key.query?.predicate.value).first {
                    return Just(.loaded(cachedModel))
                        .eraseToAnyPublisher()
                } else {
                    return networkManager.fetchModelDetail(T.self, id: id)
                        .handleEvents(
                            receiveOutput: { [weak self] fetchedModel in
                                switch fetchedModel {
                                case .loaded(let model):
                                    try? self?.databaseManager.save(model)
                                case .error(let error):
                                    switch error as? NetworkError {
                                    case .modelNotFound:
                                        try? self?.databaseManager.delete(T.self, id: id.stringValue)
                                    case .none:
                                        break
                                    }
                                default:
                                    break
                                }
                            }
                        )
                        .eraseToAnyPublisher()
                }
            }
            .sink(
                receiveValue: { [weak self] model in
                    self?.subjects[key]?.send(model)
                }
            )
    }
    
    private func startPollingModelList<T: ListModel>(type: T.Type, key: StreamKey<T>) {
        
        let pollInterval = type.pollInterval
        
        cancellables[key] = Timer.publish(every: pollInterval, on: .main, in: .common)
            .autoconnect()
            .prepend(.now)
            .flatMap { [weak self, networkManager] _ -> AnyPublisher<ListModelQueryResult<T>, Never> in
                networkManager.fetchModelList(T.self, query: key.query)
                    .handleEvents(
                        receiveOutput: { [weak self] fetchedModels in
                            switch fetchedModels {
                            case .loaded(let models):
                                try? self?.databaseManager.deleteAll(T.self)
                                for model in models {
                                    try? self?.databaseManager.save(model)
                                }
                            default:
                                break
                            }
                        }
                    )
                    .eraseToAnyPublisher()
            }
            .prepend(
                // Start with cached values if all are fresh, otherwise show loading until next network fetch
                {
                    guard let cachedModels = try? fetchCachedModels(for: key.query?.predicate.value), cachedModels.count > 0 else {
                        return .loading
                    }
                    
                    let freshModels = cachedModels.filter { abs($0.lastCachedDate.timeIntervalSinceNow) < T.cacheDuration }
                    
                    if freshModels.count == cachedModels.count {
                        return .loaded(freshModels)
                    } else {
                        return .loading
                    }
                }()
            )
            .sink(
                receiveValue: { [weak self] models in
                    self?.subjects[key]?.send(models)
                }
            )
    }
    
    private func stopPolling(key: AnyHashable) {
        cancellables[key]?.cancel()
        cancellables[key] = nil
    }
    
    private func fetchCachedModels<T: BaseModel>(for predicate: Predicate<T>?) throws -> [T] {
        try databaseManager.fetch(
            T.self,
            predicate: predicate
        )
    }
    
    enum StreamManagerError: Error {
        
        case modelMismatchInternalError
    }
    
    // MARK: - Thread safe access
    
    private func getSubject(for key: AnyHashable) -> CurrentValueSubject<Any, Never>? {
        var subject: CurrentValueSubject<Any, Never>?
        queue.sync {
            subject = subjects[key]
        }
        return subject
    }
    
    private func setSubject(_ subject: CurrentValueSubject<Any, Never>, for key: AnyHashable) {
        queue.sync {
            subjects[key] = subject
        }
    }
    
    private func getCancellable(for key: AnyHashable) -> AnyCancellable? {
        var cancellable: AnyCancellable?
        queue.sync {
            cancellable = cancellables[key]
        }
        return cancellable
    }
    
    private func setCancellable(_ cancellable: AnyCancellable, for key: AnyHashable) {
        queue.sync {
            cancellables[key] = cancellable
        }
    }
    
    private func getSubscriberCount(for key: AnyHashable) -> Int {
        var count: Int = 0
        queue.sync {
            count = subscriberCounts[key] ?? 0
        }
        return count
    }
    
    private func incrementSubscriberCount(for key: AnyHashable) {
        queue.sync {
            subscriberCounts[key, default: 0] += 1
        }
    }
    
    private func decrementSubscriberCount(for key: AnyHashable) {
        queue.sync {
            guard let count = subscriberCounts[key], count > 0 else {
                assertionFailure("Subscriber count should not be zero or nil")
                return
            }
            subscriberCounts[key] = count - 1
        }
    }
    
    // MARK: - Stream Key
    
    struct StreamKey<T: BaseModel>: Hashable {
        
        let model: ModelWrapper
        
        let isList: Bool
        
        let query: ModelQuery<T>?
    }
}
