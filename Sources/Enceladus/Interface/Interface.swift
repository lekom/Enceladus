//
//  File.swift
//  
//
//  Created by Leko Murphy on 5/31/24.
//

import Combine
import Foundation

/// Provides models from cache and network, either streamed or single fetches
public protocol ModelProviding {
    
    func streamModel<T: BaseModel>(_ modelType: T.Type, id: String) -> AnyPublisher<ModelQueryResult<T>, Never>
    func streamListModel<T: ListModel>(_ modelType: T.Type, query: ModelQuery<T>) -> AnyPublisher<ListModelQueryResult<T>, Never>
    
    func getModel<T: BaseModel>(_ modelType: T.Type, query: ModelQuery<T>) async -> Result<T, Error>
    func getList<T: ListModel>(_ modelType: T.Type, query: ModelQuery<T>) async -> Result<[T], Error>
}

#if DEBUG
var mockedModelProvider: ModelProviding?

/// Sets the model provider to be used in unit tests
public func mockModelProvider(_ provider: ModelProviding) {
    mockedModelProvider = provider
}
#endif

/// Dependency injection accessor for ModelProvider
public let getModelProvider: () -> ModelProviding = {
    
#if DEBUG
    if isUnitTesting {
        guard let mockedModelProvider else {
            fatalError("Mocked model provider not set")
        }
        
        return mockedModelProvider
    }
#endif
    
    return ModelProvider.shared
}
