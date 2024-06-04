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
    
    func configureHeadersProvider(_ provider: (() -> [String: String])?)
}

class NetworkManager: NetworkManaging {
            
    private var headersProvider: (() -> [String: String])?
    
    func fetchModelDetail<T: SingletonModel>(_ model: T.Type) async -> Result<T, Error> {
        await fetchModelDetail(T.self, urlQueryItems: nil)
    }
    
    func fetchModelDetail<T: BaseModel>(_ model: T.Type, id: String) async -> Result<T, Error> {
        await fetchModelDetail(T.self, urlQueryItems: [URLQueryItem(name: "id", value: id)])
    }
    
    func fetchModelList<T: ListModel>(_ model: T.Type, query: ModelQuery<T>?) async -> Result<[T], Error> {
        
        let request = urlRequest(for: T.list.url.appending(queryItems: query?.remoteQuery ?? []))
        
        do {
            let (data, _) = try await URLSession.shared.data(
                for: request
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
        fetchModelDetail(T.self, urlQueryItems: nil)
    }
    
    // TODO: handle pagination w/index
    func fetchModelList<T: ListModel>(_ model: T.Type, query: ModelQuery<T>?) -> AnyPublisher<ListModelQueryResult<T>, Never> {
        URLSession.shared.dataTaskPublisher(
            for: urlRequest(
                for:  T.list.url.appending(
                    queryItems: query?.remoteQuery ?? []
                )
            )
        )
        .map { $0.data }
        .decode(type: [T].self, decoder: JSONDecoder())
        .map { items in
            items.enumerated().forEach { $1.index = $0 }
            return .loaded(items)
        }
        .catch { Just(.error($0)) }
        .eraseToAnyPublisher()
    }
    
    func configureHeadersProvider(_ provider: (() -> [String: String])?) {
        headersProvider = provider
    }
    
    // MARK: Helpers
    
    private func fetchModelDetail<T: BaseModel>(_ model: T.Type, urlQueryItems: [URLQueryItem]?) async -> Result<T, Error> {
        do {
            let (data, _) = try await URLSession.shared.data(
                for: urlRequest(
                    for: T.detail.url.appending(
                        queryItems: urlQueryItems ?? []
                    )
                )
            )
            return .success(try JSONDecoder().decode(T.self, from: data))
        } catch {
            return .failure(error)
        }
    }
    
    private func fetchModelDetail<T: BaseModel>(
        _ model: T.Type,
        urlQueryItems: [URLQueryItem]?
    ) -> AnyPublisher<ModelQueryResult<T>, Never> {
        URLSession.shared.dataTaskPublisher(
            for: urlRequest(
                for: T.detail.url.appending(
                    queryItems: urlQueryItems ?? []
                )
            )
        )
        .map { $0.data }
        .decode(type: T.self, decoder: JSONDecoder())
        .map { .loaded($0) }
        .catch { Just(.error($0)) }
        .eraseToAnyPublisher()
    }
    
    private func urlRequest(for url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        headersProvider?().forEach { key, value in
            request.addValue(value, forHTTPHeaderField: key)
        }
        return request
    }
}

enum NetworkError: Error {
    case modelNotFound
}
