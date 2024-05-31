//
//  File.swift
//  
//
//  Created by Leko Murphy on 5/30/24.
//

import Combine
import Foundation

#if DEBUG
var mockedModelProvider: ModelProviding?

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

public protocol ModelProviding {
    
    func streamModel<T: BaseModel>(_ modelType: T.Type, id: String) -> AnyPublisher<ModelQueryResult<T>, Never>
    func streamListModel<T: ListModel>(_ modelType: T.Type, query: ModelQuery<T>) -> AnyPublisher<ListModelQueryResult<T>, Never>
    
    func getModel<T: BaseModel>(_ modelType: T.Type, query: ModelQuery<T>) async -> Result<T, Error>
    func getList<T: ListModel>(_ modelType: T.Type, query: ModelQuery<T>) async -> Result<[T], Error>
}

internal struct ModelProvider: ModelProviding {
    
    static let shared = ModelProvider(
        databaseManager: DatabaseManager(),
        networkManager: NetworkManager()
    )
    
    private let databaseManager: DatabaseManaging
    private let networkManager: NetworkManaging
    private let fetchProvider: ModelFetchProviding
    private let streamManager: MultiStreamManaging
    
    init(databaseManager: DatabaseManaging, networkManager: NetworkManaging) {
        self.databaseManager = databaseManager
        self.networkManager = networkManager
        let fetchProvider = ModelFetchProvider(
            databaseManager: databaseManager,
            networkManager: networkManager
        )
        self.fetchProvider = fetchProvider
        self.streamManager = MultiStreamManager(fetchProvider: fetchProvider)
    }
    
    func streamModel<T: BaseModel>(_ modelType: T.Type, id: String) -> AnyPublisher<ModelQueryResult<T>, Never> {
        streamManager.streamModel(type: T.self, id: id)
    }
    
    func streamListModel<T: ListModel>(_ modelType: T.Type, query: ModelQuery<T>) -> AnyPublisher<ListModelQueryResult<T>, Never> {
        streamManager.streamList(type: T.self, query: query)
    }
    
    func getModel<T: BaseModel>(_ modelType: T.Type, query: ModelQuery<T>) async -> Result<T, Error> {
        // TODO: implement
        .failure(NetworkError.modelNotFound)
    }
    
    func getList<T: ListModel>(_ modelType: T.Type, query: ModelQuery<T>) async -> Result<[T], Error> {
        // TODO: implement
        .failure(NetworkError.modelNotFound)
    }
}
