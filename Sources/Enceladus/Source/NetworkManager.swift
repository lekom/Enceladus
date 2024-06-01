//
//  File.swift
//  
//
//  Created by Leko Murphy on 5/25/24.
//

import Combine
import Foundation

protocol NetworkManaging {
    
    func fetchModelDetail<T: BaseModel>(_ model: T.Type, id: String) -> AnyPublisher<ModelQueryResult<T>, Never>
    func fetchModelDetail<T: SingletonModel>(_ model: T.Type) -> AnyPublisher<ModelQueryResult<T>, Never>
    func fetchModelList<T: ListModel>(_ model: T.Type, query: ModelQuery<T>?) -> AnyPublisher<ListModelQueryResult<T>, Never>
    
    func fetchModelDetail<T: BaseModel>(_ model: T.Type, id: String) async -> Result<T, Error>
    func fetchModelDetail<T: SingletonModel>(_ model: T.Type) async -> Result<T, Error>
    func fetchModelList<T: ListModel>(_ model: T.Type, query: ModelQuery<T>?) async -> Result<[T], Error>
}

class NetworkManager: NetworkManaging {
            
    func fetchModelDetail<T: SingletonModel>(_ model: T.Type) async -> Result<T, Error> {
        await fetchModelDetail(T.self)
    }
    
    func fetchModelDetail<T: BaseModel>(_ model: T.Type, id: String) async -> Result<T, Error> {
        await fetchModelDetail(T.self, urlQueryItems: [URLQueryItem(name: "id", value: id)])
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
    
    func fetchModelDetail<T: BaseModel>(_ model: T.Type, id: String) -> AnyPublisher<ModelQueryResult<T>, Never> {
        fetchModelDetail(T.self, urlQueryItems: [URLQueryItem(name: "id", value: id)])
    }
    
    func fetchModelDetail<T: SingletonModel>(_ model: T.Type) -> AnyPublisher<ModelQueryResult<T>, Never> {
        fetchModelDetail(T.self)
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
    
    // MARK: Helpers
    
    private func fetchModelDetail<T: BaseModel>(_ model: T.Type, urlQueryItems: [URLQueryItem]? = nil) async -> Result<T, Error> {
        do {
            let (data, _) = try await URLSession.shared.data(
                for: URLRequest(
                    url: T.detail.url.appending(
                        queryItems: urlQueryItems ?? []
                    )
                )
            )
            return .success(try JSONDecoder().decode(T.self, from: data))
        } catch {
            return .failure(error)
        }
    }
    
    private func fetchModelDetail<T: BaseModel>(_ model: T.Type, urlQueryItems: [URLQueryItem]? = nil) -> AnyPublisher<ModelQueryResult<T>, Never> {
        URLSession.shared.dataTaskPublisher(
            for: URLRequest(
                url: T.detail.url.appending(
                    queryItems: urlQueryItems ?? []
                )
            )
        )
        .map { $0.data }
        .decode(type: T.self, decoder: JSONDecoder())
        .map { .loaded($0) }
        .catch { Just(.error($0)) }
        .prepend(.loading) // start with loading state
        .eraseToAnyPublisher()
    }
}

enum NetworkError: Error {
    case modelNotFound
}
