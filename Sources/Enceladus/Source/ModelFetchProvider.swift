//
//  File.swift
//  
//
//  Created by Leko Murphy on 5/11/24.
//

import Combine
import Foundation

/// Manages the fetching of local and remote data as well as updating local data with remote data
protocol ModelFetchProviding {
    
    func streamList<T: ListModel>(
        _ modelType: T.Type,
        query: ModelQuery<T>?,
        sortDescriptors: [SortDescriptor<T>]?
    ) -> AnyPublisher<ListModelQueryResult<T>, Never>
    
    func streamModel<T: BaseModel>(_ modelType: T.Type, id: String) -> AnyPublisher<ModelQueryResult<T>, Never>
    
    func streamModel<T: SingletonModel>(_ modelType: T.Type) -> AnyPublisher<ModelQueryResult<T>, Never>
    
    func getList<T: ListModel>(
        _ modelType: T.Type,
        query: ModelQuery<T>?,
        limit: Int?,
        sortDescriptors: [SortDescriptor<T>]?
    ) async -> Result<[T], Error>
    
    func getModel<T: BaseModel>(_ modelType: T.Type, id: String) async -> Result<T, Error>
    
    func getModel<T: SingletonModel>(_ modelType: T.Type) async -> Result<T, Error>
}

/// Manages the fetching of local and remote data as well as updating local data with remote data
struct ModelFetchProvider: ModelFetchProviding {
    
    let databaseManager: DatabaseManager
    let networkManager: NetworkManaging
    
    func streamList<T>(
        _ modelType: T.Type,
        query: ModelQuery<T>?,
        sortDescriptors: [SortDescriptor<T>]?
    ) -> AnyPublisher<ListModelQueryResult<T>, Never> {
        
        let databaseUpdates = databaseManager.databaseUpdatePublisher.filter { $0.isRelevant(to: modelType) }
                
        let cachedModels: AnyPublisher<[T], Never> = cachedModelsPublisher(
            T.self,
            predicate: query?.localQuery,
            sortedBy: sortDescriptors
        ).eraseToAnyPublisher()
                
        var isFirst = true
        
        return cachedModels.combineLatest(timeTrigger(for: T.self))
            .flatMap { models, _ in
                let fetch: AnyPublisher<ListModelQueryResult<T>, Never> = networkManager
                    .fetchModelList(T.self, query: query)
                    .handleEvents(receiveOutput: { result in
                        Task {
                            switch result {
                            case .loaded(let models):
                                await handleFetchedList(models, query: query)
                            case .error(let error):
                                // TODO: Log Error
                                #if DEBUG
                                print("Network error: \(error.localizedDescription)")
                                #endif
                                break
                            case .loading:
                                assertionFailure("should not be loading")
                            }
                        }
                    })
                    .flatMap { result in
                        guard case .loaded = result else {
                            return Just(result).eraseToAnyPublisher()
                        }
                        
                        return databaseUpdates.flatMap { _ in
                            cachedModelsPublisher(
                                T.self,
                                predicate: query?.localQuery,
                                sortedBy: sortDescriptors
                            )
                            .map { .loaded($0) }
                            .eraseToAnyPublisher()
                        }
                        .debounce(for: 0.05, scheduler: DispatchQueue.main)
                        .eraseToAnyPublisher()
                    }
                    .eraseToAnyPublisher()

                if isFirst {
                    isFirst = false
                    return fetch.prepend(.loaded(models)).eraseToAnyPublisher()
                } else {
                    return fetch.eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
    }
    
    func streamModel<T: SingletonModel>(_ modelType: T.Type) -> AnyPublisher<ModelQueryResult<T>, Never> {
        
        let databaseUpdates = databaseManager.databaseUpdatePublisher.filter { $0.isRelevant(to: modelType) }
        
        let cachedModels: AnyPublisher<[T], Never> = cachedModelsPublisher(T.self)
            .eraseToAnyPublisher()
        
        var isFirst = true
        
        return cachedModels.combineLatest(timeTrigger(for: T.self))
            .flatMap { cachedModels, _ in
                
                let fetch: AnyPublisher<ModelQueryResult<T>, Never> = networkManager.fetchModelDetail(T.self)
                    .handleEvents(receiveOutput: { result in
                        Task {
                            switch result {
                            case .loaded(let model):
                                await handleFetchedSingletonModel(model)
                            case .error(let error):
                                switch error as? EnceladusNetworkError {
                                case .modelNotFound:
                                    try? databaseManager.deleteAll(
                                        T.self
                                    )
                                default:
                                    break
                                }
                            case .loading:
                                assertionFailure("loading should only be prepended to initial stream")
                            }
                        }
                    })
                    .flatMap { result in
                        guard case .loaded = result else {
                            return Just(result).eraseToAnyPublisher()
                        }
                        
                        return databaseUpdates.flatMap { _ in
                            cachedModelsPublisher(
                                T.self
                            )
                            .map { values -> ModelQueryResult<T> in
                                if let first = values.first {
                                    return .loaded(first)
                                } else {
                                    return .error(EnceladusNetworkError.modelNotFound)
                                }
                            }
                        }
                        .eraseToAnyPublisher()
                    }
                    .eraseToAnyPublisher()
                
                if isFirst, let firstCachedModel = cachedModels.first {
                    isFirst = false
                    return fetch.prepend(.loaded(firstCachedModel)).eraseToAnyPublisher()
                } else {
                    return fetch.eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
    }
    
    func streamModel<T: BaseModel>(_ modelType: T.Type, id: String) -> AnyPublisher<ModelQueryResult<T>, Never> {
        
        func streamFirst<G: ListModel>(type: G.Type) -> AnyPublisher<ModelQueryResult<T>, Never> {
            streamList(
                G.self,
                query: .equals(G.idKeyPath, id),
                sortDescriptors: nil
            )
            .filter { !$0.isLoading }
            .map { result -> ModelQueryResult<T> in
                switch result {
                case .loaded(let models):
                    if let loaded = models.first as? T {
                        return .loaded(loaded)
                    } else {
                        return .error(EnceladusNetworkError.modelNotFound)
                    }
                case .error(let error):
                    return .error(error)
                case .loading:
                    assertionFailure("loading should be filtered out")
                    return .loading
                }
            }
            .eraseToAnyPublisher()
        }
        
        guard T.detail != nil else {
            if let P = T.self as? any ListModel.Type {
                return streamFirst(type: P.self)
            } else {
                return Just(
                    .error(EnceladusNetworkError.detailUrlMissing)
                )
                .eraseToAnyPublisher()
            }
        }
        
        let cachedModel: AnyPublisher<T?, Never> = cachedModelsPublisher(
            T.self,
            predicate: idQuery(id),
            sortedBy: nil
        ).map { $0.first }.eraseToAnyPublisher()
                
        var isFirst = true
        
        let databaseUpdates = databaseManager.databaseUpdatePublisher.filter { $0.isRelevant(to: modelType, id: id) }
        
        return cachedModel.combineLatest(timeTrigger(for: T.self))
            .flatMap { cachedModel, _ in
                let fetch = networkManager.fetchModelDetail(T.self, id: id)
                    .filter { !$0.isLoading }
                    .handleEvents(receiveOutput: { result in
                        Task {
                            switch result {
                            case .loaded(let model):
                                await handleFetchedModel(model)
                            case .error(let error):
                                switch error as? EnceladusNetworkError {
                                case .modelNotFound:
                                    try? databaseManager.delete(
                                        T.self,
                                        where: idQuery(id)
                                    )
                                default:
                                    assertionFailure(error.localizedDescription)
                                }
                            case .loading:
                                assertionFailure("loading should only be prepended to initial stream")
                            }
                        }
                    })
                    .flatMap { result in
                        guard case .loaded = result else {
                            return Just(result).eraseToAnyPublisher()
                        }
                        
                        return databaseUpdates.flatMap { _ in
                            cachedModelsPublisher(
                                T.self,
                                predicate: idQuery(id)
                            )
                            .map { values -> ModelQueryResult<T> in
                                if let first = values.first {
                                    return .loaded(first)
                                } else {
                                    return .error(EnceladusNetworkError.modelNotFound)
                                }
                            }
                        }
                        .eraseToAnyPublisher()
                    }
                
                if isFirst, let cachedModel {
                    isFirst = false
                    return fetch.prepend(.loaded(cachedModel)).eraseToAnyPublisher()
                } else {
                    return fetch.eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
    }
    
    func getList<T: ListModel>(
        _ modelType: T.Type,
        query: ModelQuery<T>?,
        limit: Int? = nil,
        sortDescriptors: [SortDescriptor<T>]? = nil
    ) async -> Result<[T], Error> {
        if
            let models = await fetchCachedModels(
                T.self,
                predicate: query?.localQuery,
                sortedBy: sortDescriptors
            ),
            let limit,
            models.count >= limit
        {
            return .success(Array(models.prefix(limit)))
        } else {
            return await networkManager.fetchModelList(T.self, query: query)
        }
    }
    
    func getModel<T: BaseModel>(_ modelType: T.Type, id: String) async -> Result<T, Error> {
        if let model = await fetchCachedModels(
            T.self,
            predicate: idQuery(id)
        )?.first {
            return .success(model)
        } else {
            return await networkManager.fetchModelDetail(T.self, id: id)
        }
    }
    
    func getModel<T: SingletonModel>(_ modelType: T.Type) async -> Result<T, Error> {
        if let model = await fetchCachedModels(T.self)?.first {
            return .success(model)
        } else {
            return await networkManager.fetchModelDetail(T.self)
        }
    }
    
    private func fetchCachedModels<T: BaseModel>(
        _ type: T.Type,
        predicate: Predicate<T>? = nil,
        sortedBy sortDescriptor: [SortDescriptor<T>]? = nil
    ) async -> [T]? {
        guard
            let cachedModels = try? await databaseManager.fetch(
                T.self,
                predicate: predicate,
                sortedBy: sortDescriptor
            ),
            cachedModels.count > 0
        else {
            return nil
        }
        
        if cachedModels.count > 0 {
            return cachedModels
        } else {
            return nil
        }
    }
    
    private func cachedModelsPublisher<T: BaseModel>(
        _ type: T.Type,
        predicate: Predicate<T>? = nil,
        sortedBy sortDescriptor: [SortDescriptor<T>]? = nil
    ) -> AnyPublisher<[T], Never> {
        AsyncAwaitFuture<[T], Never> { promise in
            let cachedModels = await fetchCachedModels(
                T.self,
                predicate: predicate,
                sortedBy: sortDescriptor
            )
            promise(.success(cachedModels ?? []))
        }
        .eraseToAnyPublisher()
    }
    
    private func timeTrigger<T: BaseModel>(for type: T.Type) -> AnyPublisher<Date, Never> {
        if let T = T.self as? PollableModel.Type {
            return Timer.publish(every: T.pollingInterval, on: .main, in: .common)
                .autoconnect()
                .prepend(.now)
                .eraseToAnyPublisher()
        } else {
            return Just(.now).eraseToAnyPublisher()
        }
    }
    
    @discardableResult
    private func handleFetchedSingletonModel<T: SingletonModel>(_ model: T) async -> Result<T, Error> {
        try? databaseManager.save(model)
        
        do {
            let cachedModels = try await databaseManager.fetch(T.self)
            if let first = cachedModels.first {
                return .success(first)
            } else {
                return .failure(EnceladusNetworkError.modelNotFound)
            }
        } catch {
            return .failure(error)
        }
    }
    
    @discardableResult
    private func handleFetchedModel<T: BaseModel>(_ model: T) async -> Result<T, Error> {
        try? databaseManager.save(model)
        
        do {
            let cachedModels = try await databaseManager.fetch(
                T.self,
                predicate: idQuery(model.id)
            )
            if let first = cachedModels.first {
                return .success(first)
            } else {
                return .failure(EnceladusNetworkError.modelNotFound)
            }
        } catch {
            return .failure(error)
        }
    }
    
    @discardableResult
    private func handleFetchedList<T: ListModel>(_ models: [T], query: ModelQuery<T>?) async -> Result<[T], Error> {
        do {
            let cachedModels = try await databaseManager.handleFetchedList(models, query: query)
                        
            return .success(cachedModels)
        } catch {
            return .failure(error)
        }
    }
    
    private func idQuery<T: BaseModel>(_ id: String) -> Predicate<T> {
        EqualQueryItem(T.idKeyPath, id).localQuery
    }
}
