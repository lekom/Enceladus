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
    
    let databaseManager: DatabaseManaging
    let networkManager: NetworkManaging
    
    func streamList<T>(
        _ modelType: T.Type,
        query: ModelQuery<T>?,
        sortDescriptors: [SortDescriptor<T>]?
    ) -> AnyPublisher<ListModelQueryResult<T>, Never> {
        
        let databaseUpdates = databaseManager.databaseUpdatePublisher.filter { $0.isRelevant(to: modelType) }
        
        return timeTrigger(for: T.self)
            .flatMap { _ in
                networkManager.fetchModelList(T.self, query: query)
                    .handleEvents(receiveOutput: { result in
                        switch result {
                        case .loaded(let models):
                            handleFetchedList(models, query: query)
                        case .error(let error):
                            assertionFailure(error.localizedDescription)
                        case .loading:
                            assertionFailure("should not be loading")
                        }
                    })
                    .flatMap { _ in
                        return databaseUpdates.map { _ in
                            if let loaded = freshModels(
                                T.self,
                                predicate: query?.localQuery,
                                sortedBy: sortDescriptors
                            ) {
                                return .loaded(loaded)
                            } else {
                                return .loaded([])
                            }
                        }
                        .debounce(for: 0.05, scheduler: DispatchQueue.main)
                    }
            }
            .prepend(
                {
                    if let loaded = freshModels(
                        T.self,
                        predicate: query?.localQuery,
                        sortedBy: sortDescriptors
                    ) {
                        .loaded(loaded)
                    } else {
                        .loading
                    }
                }()
            )
            .eraseToAnyPublisher()
    }
    
    func streamModel<T: SingletonModel>(_ modelType: T.Type) -> AnyPublisher<ModelQueryResult<T>, Never> {
        
        let databaseUpdates = databaseManager.databaseUpdatePublisher.filter { $0.isRelevant(to: modelType) }
        
        return timeTrigger(for: T.self)
            .flatMap { _ in
                networkManager.fetchModelDetail(T.self)
                    .handleEvents(receiveOutput: { result in
                        switch result {
                        case .loaded(let model):
                            handleFetchedSingletonModel(model)
                        case .error(let error):
                            switch error as? NetworkError {
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
                    })
                    .flatMap { result in
                        databaseUpdates.map { _ in
                            if let loaded = freshModels(T.self)?.first {
                                return .loaded(loaded)
                            } else {
                                return .error(NetworkError.modelNotFound)
                            }
                        }
                        .debounce(for: 0.05, scheduler: DispatchQueue.main)
                    }
            }
            .prepend(
                {
                    if let loaded = freshModels(T.self)?.first {
                        .loaded(loaded)
                    } else {
                        .loading
                    }
                }()
            )
            .eraseToAnyPublisher()
    }
    
    func streamModel<T: BaseModel>(_ modelType: T.Type, id: String) -> AnyPublisher<ModelQueryResult<T>, Never> {
        
        func streamFirst<G: ListModel>(type: G.Type) -> AnyPublisher<ModelQueryResult<T>, Never> {
            streamList(
                G.self,
                query: .equals(\.id, id),
                sortDescriptors: nil
            )
            .filter { !$0.isLoading }
            .map { result -> ModelQueryResult<T> in
                switch result {
                case .loaded(let models):
                    if let loaded = models.first as? T {
                        return .loaded(loaded)
                    } else {
                        return .error(NetworkError.modelNotFound)
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
                    .error(NetworkError.detailUrlMissing)
                )
                .eraseToAnyPublisher()
            }
        }
        
        let databaseUpdates = databaseManager.databaseUpdatePublisher.filter { $0.isRelevant(to: modelType, id: id) }
        
        return timeTrigger(for: T.self)
            .flatMap { _ in
                networkManager.fetchModelDetail(T.self, id: id)
                    .filter { !$0.isLoading }
                    .handleEvents(receiveOutput: { result in
                        switch result {
                        case .loaded(let model):
                            handleFetchedModel(model)
                        case .error(let error):
                            switch error as? NetworkError {
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
                    })
                    .flatMap { result in
                        databaseUpdates.map { _ in
                            if let loaded = freshModels(T.self, predicate: idQuery(id))?.first {
                                return .loaded(loaded)
                            } else {
                                return .error(NetworkError.modelNotFound)
                            }
                        }
                    }
            }
            .prepend(
                {
                    if let loaded = freshModels(T.self, predicate: idQuery(id))?.first {
                        return .loaded(loaded)
                    } else {
                        return .loading
                    }
                }()
            )
            .eraseToAnyPublisher()
    }
    
    func getList<T: ListModel>(
        _ modelType: T.Type,
        query: ModelQuery<T>?,
        limit: Int? = nil,
        sortDescriptors: [SortDescriptor<T>]? = nil
    ) async -> Result<[T], Error> {
        if
            let models = freshModels(
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
        if let model = freshModels(
            T.self,
            predicate: idQuery(id)
        )?.first {
            return .success(model)
        } else {
            return await networkManager.fetchModelDetail(T.self, id: id)
        }
    }
    
    func getModel<T: SingletonModel>(_ modelType: T.Type) async -> Result<T, Error> {
        if let model = freshModels(T.self)?.first {
            return .success(model)
        } else {
            return await networkManager.fetchModelDetail(T.self)
        }
    }
    
    private func freshModels<T: BaseModel>(
        _ type: T.Type,
        predicate: Predicate<T>? = nil,
        sortedBy sortDescriptor: [SortDescriptor<T>]? = nil
    ) -> [T]? {
        guard
            let cachedModels = try? databaseManager.fetch(
                T.self,
                predicate: predicate,
                sortedBy: sortDescriptor
            ),
            cachedModels.count > 0
        else {
            return nil
        }
        
        let freshModels = cachedModels.filter {
            guard let cachedDate = $0.lastCachedDate else {
                assertionFailure("model in cache without cache date set")
                return false
            }
            return abs(cachedDate.timeIntervalSinceNow) < T.cacheDuration
        }
        
        if freshModels.count > 0 {
            return freshModels
        } else {
            return nil
        }
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
    private func handleFetchedSingletonModel<T: SingletonModel>(_ model: T) -> Result<T, Error> {
        try? databaseManager.save(model)
        
        do {
            let cachedModels = try databaseManager.fetch(T.self)
            if let first = cachedModels.first {
                return .success(first)
            } else {
                return .failure(NetworkError.modelNotFound)
            }
        } catch {
            return .failure(error)
        }
    }
    
    @discardableResult
    private func handleFetchedModel<T: BaseModel>(_ model: T) -> Result<T, Error> {
        try? databaseManager.save(model)
        
        do {
            let cachedModels = try databaseManager.fetch(
                T.self,
                predicate: idQuery(model.id)
            )
            if let first = cachedModels.first {
                return .success(first)
            } else {
                return .failure(NetworkError.modelNotFound)
            }
        } catch {
            return .failure(error)
        }
    }
    
    @discardableResult
    private func handleFetchedList<T: ListModel>(_ models: [T], query: ModelQuery<T>?) -> Result<[T], Error> {
        do {
            var modelsToDelete = try databaseManager.fetch(
                T.self,
                predicate: query?.localQuery
            ).reduce(into: [:]) {
                $0[$1.id] = $1
            }
            
            for model in models {
                modelsToDelete.removeValue(forKey: model.id)
            }
            
            try databaseManager.save(models)
            
            let models: [T] = modelsToDelete.values.map { $0 }
            
            try databaseManager.delete(models: models)
            
            // TODO: eventually allow sort descriptor to be passed in
            let cachedModels = try databaseManager.fetch(
                T.self,
                predicate: query?.localQuery,
                sortedBy: [
//                    SortDescriptor(\T.index),
//                    SortDescriptor(\T.id) // use id to break ties
                ]
            )
                        
            return .success(cachedModels)
        } catch {
            return .failure(error)
        }
    }
    
    private func idQuery<T: BaseModel>(_ id: String) -> Predicate<T> {
        #Predicate { $0.id == id }
    }
}
