//
//  File.swift
//  
//
//  Created by Leko Murphy on 6/1/24.
//

import Combine
import Foundation
import SwiftData

/// Provides models from cache and network, either streamed or single fetches
public protocol ModelProviding {
    
    /// Streams a model by unique identifier
    /// - Parameters:
    ///  - modelType: The type of model to fetch
    ///  - id: The id of the model to fetch
    /// - Returns: A publisher providing the model query result
    func streamModel<T: BaseModel>(_ modelType: T.Type, id: String) -> AnyPublisher<ModelQueryResult<T>, Never>
    
    /// Streams a singleton model from the cache or remotely
    /// - Parameters:
    ///  - modelType: The type of model to fetch
    /// - Returns: A publisher providing the model query result
    func streamModel<T: SingletonModel>(modelType: T.Type) -> AnyPublisher<ModelQueryResult<T>, Never>
    
    /// Streams a list of models from the cache or remotely
    /// - Parameters:
    ///  - modelType: The type of model to fetch
    ///  - query: The query to filter the list
    ///  - limit: The maximum number of models to fetch.  If `nil` all fresh cache items matching the query will be returned, as well as the full result of any remote response
    ///  - sortDescriptors: The sort descriptors to apply to the requested data before taking the first result
    /// - Returns: A publisher providing the model query result
    func streamFirstModel<T: ListModel>(
        _ modelType: T.Type,
        query: ModelQuery<T>?,
        sortDescriptors: [SortDescriptor<T>]?
    ) -> AnyPublisher<ModelQueryResult<T>, Never>
    
    /// Streams a list of models from the cache or remotely
    /// - Parameters:
    ///  - modelType: The type of model to fetch
    ///  - query: The query to filter the list
    ///  - limit: The maximum number of models to return in the results
    ///  - sortDescriptors: The sort descriptors to apply to the requested data
    /// - Returns: A publisher providing the list query result
    func streamListModel<T: ListModel>(
        _ modelType: T.Type,
        query: ModelQuery<T>?,
        limit: Int?,
        sortDescriptors: [SortDescriptor<T>]?
    ) -> AnyPublisher<ListModelQueryResult<T>, Never>
    
    /// Fetches a singleton model from the cache or remotely
    /// - Parameters:
    ///  - modelType: The type of model to fetch
    ///  - id: The id of the model to fetch
    /// - Returns: Result of the model query
    func getModel<T: BaseModel>(_ modelType: T.Type, id: String) async -> Result<T, Error>
    
    /// Fetches a singleton model from the cache or remotely
    /// - Parameters:
    ///  - modelType: The type of model to fetch
    /// - Returns: Result of the model query
    func getModel<T: SingletonModel>(_ modelType: T.Type) async -> Result<T, Error>
    
    /// Fetches the first model matching the given query from the cache or remotely
    /// - Parameters:
    ///  - modelType: The type of model to fetch
    ///  - query: The query to filter the list
    /// - Returns: Result of the list query
    func getFirstModel<T: ListModel>(
        _ modelType: T.Type,
        query: ModelQuery<T>?,
        sortDescriptors: [SortDescriptor<T>]?
    ) async -> Result<T, Error>
    
    /// Fetches a list of models from the cache or network
    /// - Parameters:
    ///  - modelType: The type of model to fetch
    ///  - query: The query to filter the list
    ///  - limit: The maximum number of models to fetch.  Cached models are only returned if set and there are enough to fill the query, otherwise this will fulfill the query with remote request.
    ///  - sortDescriptors: The sort descriptors to apply to the requested data
    /// - Returns: Result of the list query.
    func getList<T: ListModel>(
        _ modelType: T.Type,
        query: ModelQuery<T>?,
        limit: Int?,
        sortDescriptors: [SortDescriptor<T>]?
    ) async -> Result<[T], Error>
    
    /// Global configuration for the model provider.  Call once at app launch to perform any necessary setup.
    /// Not required if using the default ModelProvider without any request headers
    /// - Parameters:
    ///  - headersProvider: A closure that will be called on every network request to provide headers
    func configure(
        modelContainer: ModelContainer,
        headersProvider: (() -> [String: String])?
    )
}

// MARK: - Defaults

extension ModelProviding {
    
    func streamListModel<T: ListModel>(
        _ modelType: T.Type,
        query: ModelQuery<T>? = nil,
        limit: Int? = nil,
        sortDescriptors: [SortDescriptor<T>]? = nil
    ) -> AnyPublisher<ListModelQueryResult<T>, Never> {
        streamListModel(modelType, query: query, limit: limit, sortDescriptors: sortDescriptors)
    }
    
    func streamFirstModel<T: ListModel>(
        _ modelType: T.Type,
        query: ModelQuery<T>? = nil,
        sortDescriptors: [SortDescriptor<T>]? = nil
    ) -> AnyPublisher<ModelQueryResult<T>, Never> {
        streamFirstModel(modelType, query: query, sortDescriptors: sortDescriptors)
    }
    
    func getList<T: ListModel>(
        _ modelType: T.Type,
        query: ModelQuery<T>? = nil,
        limit: Int? = nil,
        sortDescriptors: [SortDescriptor<T>]? = nil
    ) async -> Result<[T], Error> {
        await getList(modelType, query: query, limit: limit, sortDescriptors: sortDescriptors)
    }
    
    func getFirstModel<T: ListModel>(
        _ modelType: T.Type,
        query: ModelQuery<T>? = nil,
        sortDescriptors: [SortDescriptor<T>]? = nil
    ) async -> Result<T, Error> {
        await getFirstModel(modelType, query: query, sortDescriptors: sortDescriptors)
    }
}
