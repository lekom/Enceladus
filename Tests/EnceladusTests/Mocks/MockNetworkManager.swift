//
//  File.swift
//  
//
//  Created by Leko Murphy on 5/26/24.
//

import Combine
@testable import Enceladus
import Foundation

class MockNetworkManager: NetworkManaging {

    var networkDelay: DispatchQueue.SchedulerTimeType.Stride = 0
    var models: [any BaseModel] = []
    
    init(models: [any BaseModel] = []) {
        self.models = models
    }
    
    func fetchModelDetail<T: BaseModel>(
        _ model: T.Type,
        id: String
    ) -> AnyPublisher<ModelQueryResult<T>, Never> {
        
        let model: T? = models
            .compactMap { $0 as? T }
            .first { model in
                model.id == id
            }
        
        let result: ModelQueryResult<T> = if let model {
            .loaded(model)
        } else {
            .error(NetworkError.modelNotFound)
        }
        
        return Just(result).delay(for: networkDelay, scheduler: DispatchQueue.main).eraseToAnyPublisher()
    }
    
    func fetchModelList<T: ListModel>(_ model: T.Type, query: ModelQuery<T>?) -> AnyPublisher<ListModelQueryResult<T>, Never> {
        Just(
            .loaded(
                models
                    .compactMap { $0 as? T }
                    .filter {
                        guard let predicate = query?.localQuery else { return true }
                        return (try? predicate.evaluate($0)) ?? false
                    }
            )
        )
        .delay(for: networkDelay, scheduler: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    func fetchModelDetail<T: BaseModel>(_ model: T.Type, id: String) async -> Result<T, any Error> {
        let model: T? = models
            .compactMap { $0 as? T }
            .first { model in
                model.id == id
            }
        
        if let model {
            return .success(model)
        } else {
            return .failure(NetworkError.modelNotFound)
        }
    }
    
    func fetchModelList<T: ListModel>(_ model: T.Type, query: ModelQuery<T>?) async -> Result<[T], any Error> {
        let models = models
            .compactMap { $0 as? T }
            .filter {
                guard let predicate = query?.localQuery else { return true }
                return (try? predicate.evaluate($0)) ?? false
            }
        
        return .success(models)
    }
    
    func fetchModelDetail<T: SingletonModel>(_ model: T.Type) -> AnyPublisher<ModelQueryResult<T>, Never> {
        let model: T? = models
            .compactMap { $0 as? T }
            .first
        
        let result: ModelQueryResult<T> = if let model {
            .loaded(model)
        } else {
            .error(NetworkError.modelNotFound)
        }
        
        return Just(result).delay(for: networkDelay, scheduler: DispatchQueue.main).eraseToAnyPublisher()
    }
    
    func fetchModelDetail<T>(_ model: T.Type) async -> Result<T, any Error> where T : Enceladus.BaseModel, T : Enceladus.DefaultQueryable {
        let model: T? = models
            .compactMap { $0 as? T }
            .first
        
        if let model {
            return .success(model)
        } else {
            return .failure(NetworkError.modelNotFound)
        }
    }
}
