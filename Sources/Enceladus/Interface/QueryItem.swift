//
//  Query.swift
//
//
//  Created by Leko Murphy on 5/24/24.
//

import Combine
import Foundation
import SwiftData

public typealias EquatableQueryValue = Equatable & Hashable & Codable & StringConvertible

public protocol QueryItemCombining: Hashable, Equatable {
    associatedtype T: BaseModel
    var queryItems: [any QueryItem<T>] { get }
}

public extension QueryItemCombining {
    
    var localQuery: Predicate<T> {
        queryItems
            .map { $0.localQuery }
            .reduce(Predicate<T>.true) { partialResult, item in
                #Predicate { model in
                    partialResult.evaluate(model) && item.evaluate(model)
                }
            }
    }
    
    var remoteQuery: [URLQueryItem]? {
        let queryItems = queryItems.compactMap { $0.remoteQuery }
        
        guard queryItems.count > 0 else {
            return nil
        }
        
        return queryItems
    }
    
    func hash(into hasher: inout Hasher) {
        queryItems.forEach {
            hasher.combine($0)
        }
    }
    
    static func ==(lhs: Self, rhs: Self) -> Bool {
        lhs.queryItems.elementsEqual(rhs.queryItems, by: { $0.isEqual($1) })
    }
}

public struct ModelQuery<T: BaseModel>: QueryItemCombining {
    
    public let queryItems: [any QueryItem<T>]
    
    init(queryItems: [any QueryItem<T>]) {
        self.queryItems = queryItems
    }
}

public protocol QueryItem<T>: Equatable, Hashable {
    associatedtype T: BaseModel
    var localQuery: Predicate<T> { get }
    var remoteQuery: URLQueryItem? { get }
}

public struct AndQueryItem<T: BaseModel>: QueryItem, QueryItemCombining {
    
    public let queryItems: [any QueryItem<T>]
    
    public var localQuery: Predicate<T> {
        queryItems
            .map { $0.localQuery }
            .reduce(Predicate<T>.true) { partialResult, next in
                #Predicate { model in
                    partialResult.evaluate(model) && next.evaluate(model)
                }
            }
    }
    
    public var remoteQuery: URLQueryItem? {
        return nil // remote OR query not supported
    }
}

public struct OrQueryItem<T: BaseModel>: QueryItem, QueryItemCombining {
    
    public let queryItems: [any QueryItem<T>]
    
    public var localQuery: Predicate<T> {
        queryItems
            .map { $0.localQuery }
            .reduce(Predicate<T>.false) { partialResult, next in
                #Predicate { model in
                    partialResult.evaluate(model) || next.evaluate(model)
                }
            }
    }
    
    public var remoteQuery: URLQueryItem? {
        return nil // remote OR query not supported
    }
}

public struct EqualQueryItem<T: BaseModel, V: EquatableQueryValue>: QueryItem {
    
    let keyPath: KeyPath<T, V>
    let value: V
    
    public var localQuery: Predicate<T> {
        return Predicate<T> {
            PredicateExpressions.build_Equal(
                lhs: PredicateExpressions.build_KeyPath(
                    root: PredicateExpressions.build_Arg($0),
                    keyPath: keyPath
                ),
                rhs: PredicateExpressions.build_Arg(value)
            )
        }
    }
    
    public var remoteQuery: URLQueryItem? {
        guard let key = T.remoteQueryableKeys[keyPath] else {
            return nil
        }
        return URLQueryItem(
            name: key.stringValue,
            value: String(value.stringValue)
        )
    }
}
