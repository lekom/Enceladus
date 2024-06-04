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
        
        timeTrigger(for: T.self)
            .flatMap { _ in
                networkManager.fetchModelList(T.self, query: query)
                    .map { result in
                        switch result {
                        case .loaded(let models):
                            let result = handleFetchedList(models, query: query)
                            switch result {
                                case .success(let models):
                                    return .loaded(models)
                                case .failure(let error):
                                    return .error(error)
                            }
                        case .loading:
                            return .loading
                        case .error(let error):
                            return .error(error)
                        }
                    }
            }
            .prepend(
                {
                    if let loaded = freshModels(
                        T.self,
                        predicate: query?.localQuery,
                        sortedBy: sortDescriptors ?? defaultListSortDescriptor()
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
        timeTrigger(for: T.self)
            .flatMap { _ in
                networkManager.fetchModelDetail(T.self)
                    .map { result in
                        switch result {
                        case .loaded(let model):
                            let result = handleFetchedModel(model)
                            switch result {
                                case .success(let model):
                                    return .loaded(model)
                                case .failure(let error):
                                    return .error(error)
                            }
                        case .error(let error):
                            switch error as? NetworkError {
                            case .modelNotFound:
                                try? databaseManager.deleteAll(
                                    T.self
                                )
                            case .none:
                                break
                            }
                            
                            return .error(error)
                        case .loading:
                            return .loading
                        }
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
        timeTrigger(for: T.self)
            .flatMap { _ in
                networkManager.fetchModelDetail(T.self, id: id)
                    .map { result in
                        switch result {
                        case .loaded(let model):
                            let result = handleFetchedModel(model)
                            switch result {
                                case .success(let model):
                                    return .loaded(model)
                                case .failure(let error):
                                    return .error(error)
                            }
                        case .error(let error):
                            switch error as? NetworkError {
                            case .modelNotFound:
                                try? databaseManager.delete(
                                    T.self,
                                    where: idQuery(id)
                                )
                            case .none:
                                break
                            }
                            
                            return .error(error)
                        case .loading:
                            return .loading
                        }
                    }
            }
            .prepend(
                {
                    if let loaded = freshModels(T.self, predicate: idQuery(id))?.first {
                        .loaded(loaded)
                    } else {
                        .loading
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
                sortedBy: sortDescriptors ?? defaultListSortDescriptor()
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
    
    private func handleFetchedList<T: ListModel>(_ models: [T], query: ModelQuery<T>?) -> Result<[T], Error> {
        do {
            var modelsToDelete = try databaseManager.fetch(
                T.self,
                predicate: query?.localQuery
            ).reduce(into: [:]) {
                $0[$1.id] = $1
            }
            
            for model in models {
                model.lastCachedDate = .now
                try databaseManager.save(model)
                modelsToDelete[model.id] = nil
            }
            
            for model in modelsToDelete.values {
                try databaseManager.delete(model)
            }
            
            // TODO: eventually allow sort descriptor to be passed in
            let cachedModels = try databaseManager.fetch(
                T.self,
                predicate: query?.localQuery,
                sortedBy: [
                    SortDescriptor(\T.index),
                    SortDescriptor(\T.id) // use id to break ties
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
    
    private func defaultListSortDescriptor<T: ListModel>() -> [SortDescriptor<T>] {
        [
            SortDescriptor(\T.index),
            SortDescriptor(\T.id) // use id to break ties
        ]
    }
}
