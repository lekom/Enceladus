//
//  ModelProvider.swift
//
//
//  Created by Leko Murphy on 5/11/24.
//

import Combine
import SwiftData
import Foundation

/// Manages multiple streams of data to share publishers of the same model type and query.
protocol MultiStreamManaging {
    
    func streamModel<T: BaseModel>(type: T.Type, id: String) -> AnyPublisher<ModelQueryResult<T>, Never>
    func streamModel<T: SingletonModel>(type: T.Type) -> AnyPublisher<ModelQueryResult<T>, Never>
    func streamList<T: ListModel>(
        type: T.Type,
        query: ModelQuery<T>?,
        limit: Int?,
        sortDescriptors: [SortDescriptor<T>]?
    ) -> AnyPublisher<ListModelQueryResult<T>, Never>
}

/// Manages multiple streams of data to share publishers of the same model type and query.
class MultiStreamManager: MultiStreamManaging {
        
    private var cancellables: [AnyHashable: AnyCancellable] = [:]
    
    private(set) internal var subjects: [AnyHashable: CurrentValueSubject<Any, Never>] = [:]
    private(set) internal var subscriberCounts: [AnyHashable: Int] = [:]
    
    private let fetchProvider: ModelFetchProviding
    
    private let queue = DispatchQueue(label: "com.enceladus.streammanager")
    
    init(fetchProvider: ModelFetchProviding) {
        self.fetchProvider = fetchProvider
    }
    
    // MARK: - MultiStreamManaging
    
    func streamModel<T: SingletonModel>(type: T.Type) -> AnyPublisher<ModelQueryResult<T>, Never> {
        
        assert(Thread.isMainThread)
        
        let key = StreamKey<T>(
            model: ModelWrapper(type),
            type: .detail,
            query: nil
        )
        
        let subject: CurrentValueSubject<Any, Never>
        
        if let existingSubject = getSubject(for: key) {
            subject = existingSubject
        } else {
            assert(
                getSubscriberCount(for: key) == 0,
                "There should be no subscriber if subjects is nil"
            )
            subject = CurrentValueSubject<Any, Never>(ModelQueryResult<T>.loading)
            setSubject(subject, for: key)
        }
        
        incrementSubscriberCount(for: key)
        
        if getCancellable(for: key) == nil {
            startPollingModelDetail(type: type, key: key)
        }
        
        return setupPublisher(
            subject: subject.eraseToAnyPublisher(),
            key: key
        )
    }
    
    func streamModel<T: BaseModel>(type: T.Type, id: String) -> AnyPublisher<ModelQueryResult<T>, Never> {
        
        assert(Thread.isMainThread)
        
        let key = StreamKey<T>(
            model: ModelWrapper(type),
            type: .detail,
            query: ModelQuery(
                queryItems: [
                    EqualQueryItem(T.idKeyPath, id)
                ]
            )
        )
        
        let subject: CurrentValueSubject<Any, Never>
        
        if let existingSubject = getSubject(for: key) {
            subject = existingSubject
        } else {
            assert(
                getSubscriberCount(for: key) == 0,
                "There should be no subscriber if subjects is nil"
            )
            subject = CurrentValueSubject<Any, Never>(ModelQueryResult<T>.loading)
            setSubject(subject, for: key)
        }
        
        incrementSubscriberCount(for: key)
        
        if getCancellable(for: key) == nil {
            startPollingModelDetail(type: type, id: id, key: key)
        }
        
        return setupPublisher(
            subject: subject.eraseToAnyPublisher(),
            key: key
        )
    }
    
    func streamList<T: ListModel>(
        type: T.Type,
        query: ModelQuery<T>?,
        limit: Int?,
        sortDescriptors: [SortDescriptor<T>]?
    ) -> AnyPublisher<ListModelQueryResult<T>, Never> {
        
        assert(Thread.isMainThread)
        
        let key = StreamKey(
            model: ModelWrapper(type),
            type: .list(limit: limit, sortDescriptors: sortDescriptors),
            query: query
        )
        
        let subject: CurrentValueSubject<Any, Never>
        
        if let existingSubject = getSubject(for: key) {
            subject = existingSubject
        } else {
            assert(
                getSubscriberCount(for: key) == 0,
                "There should be no subscriber if subjects is nil"
            )
            subject = CurrentValueSubject<Any, Never>(ListModelQueryResult<T>.loading)
            setSubject(subject, for: key)
        }
        
        incrementSubscriberCount(for: key)
        
        if getCancellable(for: key) == nil {
            startPollingModelList(type: type, key: key)
        }
        
        return setupPublisher(
            subject: subject.eraseToAnyPublisher(),
            key: key
        )
    }
    
    // MARK: - Private Helpers
    
    private func startPollingModelDetail<T: SingletonModel>(type: T.Type, key: StreamKey<T>) {
                
        cancellables[key] = fetchProvider.streamModel(T.self)
            .receive(on: queue)
            .sink(
                receiveValue: { [weak self] model in
                    self?.subjects[key]?.send(model)
                }
            )
    }
    
    private func startPollingModelDetail<T: BaseModel>(type: T.Type, id: String, key: StreamKey<T>) {
                
        cancellables[key] = fetchProvider.streamModel(T.self, id: id)
            .receive(on: queue)
            .sink(
                receiveValue: { [weak self] model in
                    self?.subjects[key]?.send(model)
                }
            )
    }
    
    private func startPollingModelList<T: ListModel>(type: T.Type, key: StreamKey<T>) {
        
        cancellables[key] = fetchProvider.streamList(
            T.self,
            query: key.query,
            sortDescriptors: key.sortDescriptors
        )
        .receive(on: queue)
        .sink(
            receiveValue: { [weak self] models in
                self?.subjects[key]?.send(models.loadedPrefix(key.limit))
            }
        )
    }
    
    private func setupPublisher<T, V>(subject: AnyPublisher<Any, Never>, key: StreamKey<T>) -> AnyPublisher<V, Never> {
        subject
            .map {
                guard let result = $0 as? V else {
                    assertionFailure("Unexpected model type")
                    return StreamManagerError.modelMismatchInternalError as! V
                }
                return result
            }
            .handleEvents(
                receiveCompletion: {_ in 
                    print("[encel] completed \(T.typeName)")
                },
                receiveCancel: { [weak self] in
                    
                    print("[encel] canceled \(T.typeName)")
                    
                    guard let self = self else { return }
                    queue.async {
                        assert((self.subscriberCounts[key] ?? 0) > 0, "should not get cancel if no subscribers")
                        self.subscriberCounts[key] = (self.subscriberCounts[key] ?? 0) - 1
                        
                        if self.subscriberCounts[key] == 0 {
                            self.cancellables[key]?.cancel()
                            self.cancellables[key] = nil
                            
                            self.subjects[key] = nil
                        }
                    }
                }
            )
            .eraseToAnyPublisher()
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
    
    func getSubscriberCount(for key: AnyHashable) -> Int {
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
    
    // MARK: - Error
    
    enum StreamManagerError: Error {
        
        case modelMismatchInternalError
    }
}
