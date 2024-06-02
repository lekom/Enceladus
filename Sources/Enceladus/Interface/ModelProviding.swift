//
//  File.swift
//  
//
//  Created by Leko Murphy on 6/1/24.
//

import Combine
import Foundation

/// Provides models from cache and network, either streamed or single fetches
public protocol ModelProviding {
    
    func streamModel<T: BaseModel>(_ modelType: T.Type, id: String) -> AnyPublisher<ModelQueryResult<T>, Never>
    func streamModel<T: SingletonModel>(modelType: T.Type) -> AnyPublisher<ModelQueryResult<T>, Never>
    
    func streamFirstModel<T: ListModel>(_ modelType: T.Type, query: ModelQuery<T>?) -> AnyPublisher<ModelQueryResult<T>, Never>
    func streamListModel<T: ListModel>(_ modelType: T.Type, query: ModelQuery<T>?) -> AnyPublisher<ListModelQueryResult<T>, Never>
    
    func getModel<T: BaseModel>(_ modelType: T.Type, id: String) async -> Result<T, Error>
    func getModel<T: SingletonModel>(_ modelType: T.Type) async -> Result<T, Error>
    
    func getFirstModel<T: ListModel>(_ modelType: T.Type, query: ModelQuery<T>?) async -> Result<T, Error>
    func getList<T: ListModel>(_ modelType: T.Type, query: ModelQuery<T>?) async -> Result<[T], Error>
}
