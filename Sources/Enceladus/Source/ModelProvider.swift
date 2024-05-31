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
    
    func streamListModel<T: ListModel>(_ modelType: T.Type, query: ModelQuery<T>) -> AnyPublisher<ListModelQueryResult<T>, Never> {
        streamManager.streamList(type: T.self, query: query)
    }
    
    func getModel<T: BaseModel>(_ modelType: T.Type, query: ModelQuery<T>) async -> Result<T, Error> {
        await fetchProvider.getModel(T.self, query: query)
    }
    
    func getList<T: ListModel>(_ modelType: T.Type, query: ModelQuery<T>) async -> Result<[T], Error> {
        await fetchProvider.getList(T.self, query: query)
    }
}
