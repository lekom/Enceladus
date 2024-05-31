//
//  File.swift
//  
//
//  Created by Leko Murphy on 5/25/24.
//

import Combine
import Foundation

protocol NetworkManaging {
    
    func fetchModelDetail<T: BaseModel>(_ model: T.Type, query: ModelQuery<T>?) -> AnyPublisher<ModelQueryResult<T>, Never>
    func fetchModelList<T: ListModel>(_ model: T.Type, query: ModelQuery<T>?) -> AnyPublisher<ListModelQueryResult<T>, Never>
    
    func fetchModelDetail<T: BaseModel>(_ model: T.Type, query: ModelQuery<T>?) async -> Result<T, Error>
    func fetchModelList<T: ListModel>(_ model: T.Type, query: ModelQuery<T>?) async -> Result<[T], Error>
}

class NetworkManager: NetworkManaging {
            
    func fetchModelDetail<T: BaseModel>(_ model: T.Type, query: ModelQuery<T>?) async -> Result<T, Error> {
        do {
            let (data, _) = try await URLSession.shared.data(
                for: URLRequest(url: T.detail.url.appending(queryItems: query?.remoteQuery ?? []))
            )
            return .success(try JSONDecoder().decode(T.self, from: data))
        } catch {
            return .failure(error)
        }
    }
    
    func fetchModelList<T: ListModel>(_ model: T.Type, query: ModelQuery<T>?) async -> Result<[T], Error> {
        do {
            let (data, _) = try await URLSession.shared.data(
                for: URLRequest(url: T.list.url.appending(queryItems: query?.remoteQuery ?? []))
            )
            return .success(try JSONDecoder().decode([T].self, from: data))
        } catch {
            return .failure(error)
        }
    }
    
    func fetchModelDetail<T: BaseModel>(_ model: T.Type, query: ModelQuery<T>?) -> AnyPublisher<ModelQueryResult<T>, Never> {
        URLSession.shared.dataTaskPublisher(
            for: T.detail.url.appending(
                queryItems: query?.remoteQuery ?? []
            )
        )
        .map { $0.data }
        .decode(type: T.self, decoder: JSONDecoder())
        .map { .loaded($0) }
        .catch { Just(.error($0)) }
        .prepend(.loading) // start with loading state
        .eraseToAnyPublisher()
    }
    
    // TODO: handle pagination w/index
    func fetchModelList<T: ListModel>(_ model: T.Type, query: ModelQuery<T>?) -> AnyPublisher<ListModelQueryResult<T>, Never> {
        URLSession.shared.dataTaskPublisher(
            for: T.list.url.appending(
                queryItems: query?.remoteQuery ?? []
            )
        )
        .map { $0.data }
        .decode(type: [T].self, decoder: JSONDecoder())
        .map { items in
            items.enumerated().forEach { $1.index = $0 }
            return .loaded(items)
        }
        .catch { Just(.error($0)) }
        .prepend(.loading) // start with loading state
        .eraseToAnyPublisher()
    }
}

enum NetworkError: Error {
    case modelNotFound
}
