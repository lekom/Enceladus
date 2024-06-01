//
//  File.swift
//  
//
//  Created by Leko Murphy on 5/30/24.
//

import Combine
import Foundation

struct ModelProvider: ModelProviding {

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
    
    func streamModel<T: SingletonModel>(modelType: T.Type) -> AnyPublisher<ModelQueryResult<T>, Never> {
        streamManager.streamModel(type: T.self)
    }
    
    func streamFirstModel<T: ListModel>(_ modelType: T.Type, query: ModelQuery<T>) -> AnyPublisher<ModelQueryResult<T>, Never> {
        streamListModel(modelType.self, query: query)
            .map { result in
                switch result {
                case .loaded(let models):
                    if let first = models.first {
                        return .loaded(first)
                    } else {
                        return .error(NetworkError.modelNotFound)
                    }
                case .loading:
                    return .loading
                case .error(let error):
                    return .error(error)
                }
            }
            .eraseToAnyPublisher()
    }
    
    func streamListModel<T: ListModel>(_ modelType: T.Type, query: ModelQuery<T>) -> AnyPublisher<ListModelQueryResult<T>, Never> {
        streamManager.streamList(type: T.self, query: query)
    }
    
    func getModel<T: BaseModel>(_ modelType: T.Type, id: String) async -> Result<T, Error> {
        await fetchProvider.getModel(T.self, id: id)
    }
    
    func getModel<T: SingletonModel>(_ modelType: T.Type) async -> Result<T, any Error> {
        await fetchProvider.getModel(T.self)
    }
    
    func getFirstModel<T: ListModel>(_ modelType: T.Type, query: ModelQuery<T>) async -> Result<T, Error> {
        let list = await getList(T.self, query: query)
        
        switch list {
        case .success(let models):
            if let first = models.first {
                return .success(first)
            } else {
                return .failure(NetworkError.modelNotFound)
            }
        case .failure(let error):
            return .failure(error)
        }
    }
    
    func getList<T: ListModel>(_ modelType: T.Type, query: ModelQuery<T>) async -> Result<[T], Error> {
        await fetchProvider.getList(T.self, query: query)
    }
}
