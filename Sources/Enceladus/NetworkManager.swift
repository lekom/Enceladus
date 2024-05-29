//
//  File.swift
//  
//
//  Created by Leko Murphy on 5/25/24.
//

import Combine
import Foundation

protocol NetworkManaging {
    
    func fetchModelDetail<T: BaseModel>(_ model: T.Type, id: StringConvertible) -> AnyPublisher<ModelQueryResult<T>, Never>
    
    func fetchModelList<T: ListModel>(_ model: T.Type, query: ListModelQuery<T>?) -> AnyPublisher<ListModelQueryResult<T>, Never>
}

class NetworkManager: NetworkManaging {
            
    func fetchModelDetail<T: BaseModel>(_ model: T.Type, id: StringConvertible) -> AnyPublisher<ModelQueryResult<T>, Never> {
        URLSession.shared.dataTaskPublisher(
            for: T.detail.url.appending(
                queryItems: [URLQueryItem(name: "id", value: id.stringValue)]
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
    func fetchModelList<T: ListModel>(_ model: T.Type, query: ListModelQuery<T>?) -> AnyPublisher<ListModelQueryResult<T>, Never> {
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
