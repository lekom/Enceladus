//
//  File.swift
//  
//
//  Created by Leko Murphy on 5/11/24.
//

import Combine
import Foundation

protocol QueryManaging {
    
    func fetchModelList<T: ListModel>(_ modelType: T.Type, polls: Bool, query: ModelQuery<T>?) -> AnyPublisher<ListModelQueryResult<T>, Never>
    func fetchModel<T: BaseModel>(_ modelType: T.Type, polls: Bool, query: ModelQuery<T>?) -> AnyPublisher<ModelQueryResult<T>, Never>
}

/// Manages the fetching of local and remote data as well as updating local data with remote data
struct QueryManager: QueryManaging {
    
    let databaseManager: DatabaseManaging
    let networkManager: NetworkManaging
    
    func fetchModelList<T>(_ modelType: T.Type, polls: Bool, query: ModelQuery<T>?) -> AnyPublisher<ListModelQueryResult<T>, Never> {
        
        timeTrigger(T.self, polls: polls)
            .flatMap { _ in
                networkManager.fetchModelList(T.self, query: query)
                    .map { result in
                        switch result {
                        case .loaded(let models):
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
                                
                                // TODO: apply sort eventually
                                let cachedModels = try databaseManager.fetch(
                                    T.self,
                                    predicate: query?.localQuery
                                )
                                
                                return .loaded(cachedModels)
                            } catch {
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
                    if let loaded = freshModelsPrefix(T.self, query: query) {
                        .loaded(loaded)
                    } else {
                        .loading
                    }
                }()
            )
            .eraseToAnyPublisher()
    }
    
    func fetchModel<T>(_ modelType: T.Type, polls: Bool, query: ModelQuery<T>?) -> AnyPublisher<ModelQueryResult<T>, Never> {
        timeTrigger(T.self, polls: polls)
            .flatMap { _ in
                networkManager.fetchModelDetail(T.self, query: query)
                    .map { result in
                        switch result {
                        case .loaded(let model):
                            try? databaseManager.save(model)
                            
                            do {
                                let cachedModels = try databaseManager.fetch(
                                    T.self,
                                    predicate: query?.localQuery
                                )
                                assert(cachedModels.count == 1, "multiple models found for model detail query")
                                if let first = cachedModels.first {
                                    return .loaded(first)
                                } else {
                                    return .error(NetworkError.modelNotFound)
                                }
                            } catch {
                                return .error(error)
                            }
                            
                        case .error(let error):
                            switch error as? NetworkError {
                            case .modelNotFound:
                                if let query {
                                    try? databaseManager.delete(
                                        T.self,
                                        where: query.localQuery
                                    )
                                }
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
                    if let loaded = freshModelsPrefix(T.self, query: query)?.first {
                        .loaded(loaded)
                    } else {
                        .loading
                    }
                }()
            )
            .eraseToAnyPublisher()
    }
    
    private func freshModelsPrefix<T: BaseModel>(_ type: T.Type, query: ModelQuery<T>?) -> [T]? {
        guard
            let cachedModels = try? databaseManager.fetch(T.self, predicate: query?.localQuery),
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
    
    private func timeTrigger<T: BaseModel>(_ type: T.Type, polls: Bool) -> AnyPublisher<Date, Never> {
        if polls {
            return Timer.publish(every: T.pollInterval, on: .main, in: .common)
                .autoconnect()
                .prepend(.now)
                .eraseToAnyPublisher()
        } else {
            return Just(.now).eraseToAnyPublisher()
        }
    }
}
