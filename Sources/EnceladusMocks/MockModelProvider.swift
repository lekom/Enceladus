//
//  File.swift
//  
//
//  Created by Leko Murphy on 5/30/24.
//

import Combine
import Enceladus
import Foundation
import SwiftData

public class MockModelProvider: ModelProviding {
    
    // MARK: - Testable
    
    private var models: [any BaseModel] = []
    
    func cacheModel<T: BaseModel>(_ model: T) {
        models.append(model)
    }
    
    // MARK: - ModelProviding
    
    public func streamModel<T: BaseModel>(_ modelType: T.Type, id: String) -> AnyPublisher<ModelQueryResult<T>, Never> {
        Just(.loading).eraseToAnyPublisher()
    }
    
    public func streamListModel<T: ListModel>(_ modelType: T.Type, query: ModelQuery<T>?) -> AnyPublisher<ListModelQueryResult<T>, Never> {
        Just(.loading).eraseToAnyPublisher()
    }
    
    public func getModel<T: BaseModel>(_ modelType: T.Type, id: String) async -> Result<T, Error> {
        
        for model in models {
            if let model = model as? T, model.id == id {
                return .success(model)
            }
        }
        
        return .failure(MockError.modelNotFound)
    }
    
    public func getList<T: ListModel>(_ modelType: T.Type, query: Enceladus.ModelQuery<T>?) async -> Result<[T], Error> {
        .failure(MockError.modelNotFound)
    }
    
    public func streamModel<T: SingletonModel>(modelType: T.Type) -> AnyPublisher<ModelQueryResult<T>, Never> {
        Just(.loading).eraseToAnyPublisher()
    }
    
    public func streamFirstModel<T: ListModel>(_ modelType: T.Type, query: ModelQuery<T>?) -> AnyPublisher<ModelQueryResult<T>, Never> {
        Just(.loading).eraseToAnyPublisher()
    }
    
    public func getModel<T: SingletonModel>(_ modelType: T.Type) async -> Result<T, any Error> {
        .failure(MockError.modelNotFound)
    }
    
    public func getFirstModel<T: ListModel>(_ modelType: T.Type, query: ModelQuery<T>?) async -> Result<T, any Error> {
        .failure(MockError.modelNotFound)
    }
    
    public init() {}
    
    // MARK: - MockError
    
    enum MockError: Error {
        case modelNotFound
    }
}
