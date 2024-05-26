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
        id: any StringConvertible
    ) -> AnyPublisher<ModelQueryResult<T>, Never> {
        
        let result: ModelQueryResult<T> = if let model = models.first(where: { $0.id == id.stringValue }) as? T {
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
                        guard let predicate = query?.predicate else { return true }
                        return (try? predicate.value.evaluate($0)) ?? false
                    }
            )
        )
        .delay(for: networkDelay, scheduler: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
}
