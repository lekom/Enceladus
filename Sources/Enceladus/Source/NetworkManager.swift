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
            let (data, response) = try await URLSession.shared.data(
                for: request
            )
            
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200..<400:
                    let itemsMap = try JSONDecoder().decode([String: [T]].self, from: data)
                    guard let items = itemsMap[T.nestedListKey] else {
                        return .failure(EnceladusNetworkError.malformedListResponse)
                    }
                    return .success(items)
                case 401:
                    return .failure(EnceladusNetworkError.unauthorized)
                default:
                    // TODO: forward error from backend response
                    return .failure(EnceladusNetworkError.genericError(details: "Something went wrong"))
                }
            } else {
                return .failure(EnceladusNetworkError.genericError(details: "Unknown response type"))
            }
            
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
        .tryMap { output in
            if let httpResponse = output.response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200..<400:
                    break
                case 401:
                    throw EnceladusNetworkError.unauthorized
                default:
                    throw EnceladusNetworkError.genericError(details: "Something went wrong")
                }
            }
            return output.data
        }
        .decode(type: [String: [T]].self, decoder: JSONDecoder())
        .map { itemsMap in
            guard let items = itemsMap[T.nestedListKey] else {
                return .error(EnceladusNetworkError.malformedListResponse)
            }
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
        
        guard var detailUrl = T.detail?.url else {
            return .failure(EnceladusNetworkError.detailUrlMissing)
        }
        
        if let T = T.self as? DetailPathRewritable.Type {
            detailUrl = rewritePath(for: T.self, detailUrl: detailUrl, urlQueryItems: urlQueryItems)
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(
                for: urlRequest(
                    for: detailUrl.appending(
                        queryItems: urlQueryItems ?? []
                    )
                )
            )
            
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200..<400:
                    return .success(try JSONDecoder().decode(T.self, from: data))
                case 401:
                    return .failure(EnceladusNetworkError.unauthorized)
                default:
                    // TODO: forward error from backend response
                    return .failure(EnceladusNetworkError.genericError(details: "Something went wrong"))
                }
            } else {
                return .failure(EnceladusNetworkError.genericError(details: "Unknown response type"))
            }
        } catch {
            return .failure(error)
        }
    }
    
    private func fetchModelDetail<T: BaseModel>(
        _ model: T.Type,
        urlQueryItems: [URLQueryItem]?
    ) -> AnyPublisher<ModelQueryResult<T>, Never> {
        
        guard var detailUrl = T.detail?.url else {
            return Just(.error(EnceladusNetworkError.detailUrlMissing)).eraseToAnyPublisher()
        }
        
        if let T = T.self as? DetailPathRewritable.Type {
            detailUrl = rewritePath(for: T.self, detailUrl: detailUrl, urlQueryItems: urlQueryItems)
        }
        
        let request = urlRequest(
            for: detailUrl
        )
        
        if let nestedDetailKey = T.nestedDetailKey {
            return URLSession.shared.dataTaskPublisher(
                for: request
            )
            .tryMap { output in
                if let httpResponse = output.response as? HTTPURLResponse {
                    switch httpResponse.statusCode {
                    case 200..<400:
                        break
                    case 401:
                        throw EnceladusNetworkError.unauthorized
                    default:
                        throw EnceladusNetworkError.genericError(details: "Something went wrong")
                    }
                }
                return output.data
            }
            .decode(type: [String: T].self, decoder: JSONDecoder())
            .map { dict in
                guard let item = dict[nestedDetailKey] else {
                    return .error(EnceladusNetworkError.malformedDetailResponse)
                }
                return .loaded(item)
            }
            .catch { Just(.error($0)) }
            .eraseToAnyPublisher()
        } else {
            return URLSession.shared.dataTaskPublisher(
                for: request
            )
            .tryMap { output in
                if let httpResponse = output.response as? HTTPURLResponse {
                    switch httpResponse.statusCode {
                    case 200..<400:
                        break
                    case 401:
                        throw EnceladusNetworkError.unauthorized
                    default:
                        throw EnceladusNetworkError.genericError(details: "Something went wrong")
                    }
                }
                return output.data
            }
            .decode(type: T.self, decoder: JSONDecoder())
            .map { .loaded($0) }
            .catch { Just(.error($0)) }
            .eraseToAnyPublisher()
        }
    }
    
    private func rewritePath<T: DetailPathRewritable>(
        for modelType: T.Type,
        detailUrl: URL,
        urlQueryItems: [URLQueryItem]?
    ) -> URL {
        var detailUrl = detailUrl
        var urlQueryItems = urlQueryItems
        
        var components = detailUrl.pathComponents.filter { $0 != "/" }
        for rewriteKey in T.pathRewrites {
            guard var rewriteIndex = components.firstIndex(of: "{\(rewriteKey)}") else {
                assertionFailure("path rewrite not found in url path")
                continue
            }
            guard let value = urlQueryItems?.first(where: { $0.name == rewriteKey })?.value else {
                assertionFailure("no key found matching path rewrite")
                continue
            }
            components[rewriteIndex] = value
            urlQueryItems?.removeAll(where: { $0.name == rewriteKey })
        }
        
        detailUrl = detailUrl.removingAllPathComponents()
        
        var path = components.joined(separator: "/")
        
        detailUrl = detailUrl.appending(path: path).withTrailingSlash()
        
        if let urlQueryItems, !urlQueryItems.isEmpty {
            return detailUrl.appending(
                queryItems: urlQueryItems
            )
        } else {
            return detailUrl
        }
    }
    
    private func urlRequest(for url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        headersProvider?().forEach { key, value in
            request.addValue(value, forHTTPHeaderField: key)
        }
        return request
    }
}

private extension URL {
    /// Removes all path components from the URL
    func removingAllPathComponents() -> URL {
        var newURL = self
        while newURL.pathComponents.count > 1 { // To avoid removing the root "/"
            newURL.deleteLastPathComponent()
        }
        return newURL
    }
    
    /// Returns a URL with a trailing slash if it doesn't already have one
    func withTrailingSlash() -> URL {
        var urlString = self.absoluteString
        if !urlString.hasSuffix("/") {
            urlString.append("/")
        }
        return URL(string: urlString) ?? self
    }
}
