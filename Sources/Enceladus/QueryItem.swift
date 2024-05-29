//
//  Query.swift
//
//
//  Created by Leko Murphy on 5/24/24.
//

import Combine
import Foundation
import SwiftData

typealias EquatableQueryValue = Equatable & Hashable & Codable & StringConvertible

protocol QueryItemCombining: Hashable, Equatable {
    associatedtype T: BaseModel
    var queryItems: [any QueryItem<T>] { get }
}

extension QueryItemCombining {
    
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

class ModelQuery<T: BaseModel>: QueryItemCombining {
    
    let queryItems: [any QueryItem<T>]
    
    init(queryItems: [any QueryItem<T>]) {
        self.queryItems = queryItems
    }
    
    func hash(into hasher: inout Hasher) {
        queryItems.forEach {
            hasher.combine($0)
        }
    }
    
    static func ==(lhs: ModelQuery, rhs: ModelQuery) -> Bool {
        lhs.queryItems.elementsEqual(rhs.queryItems, by: { $0.isEqual($1) })
    }
}

class ListModelQuery<T: BaseModel>: QueryItemCombining {
    
    let queryItems: [any QueryItem<T>]
    
    init(queryItems: [any QueryItem<T>]) {
        self.queryItems = queryItems
    }
    
    func hash(into hasher: inout Hasher) {
        queryItems.forEach {
            hasher.combine($0)
        }
    }
    
    static func ==(lhs: ListModelQuery, rhs: ListModelQuery) -> Bool {
        lhs.queryItems.elementsEqual(rhs.queryItems, by: { $0.isEqual($1) })
    }
}

protocol QueryItem<T>: Equatable, Hashable {
    associatedtype T: BaseModel
    var localQuery: Predicate<T> { get }
    var remoteQuery: URLQueryItem? { get }
}

struct AndQueryItem<T: BaseModel>: QueryItem, QueryItemCombining {
    
    var queryItems: [any QueryItem<T>]
    
    var localQuery: Predicate<T> {
        queryItems
            .map { $0.localQuery }
            .reduce(Predicate<T>.true) { partialResult, next in
                #Predicate { model in
                    partialResult.evaluate(model) && next.evaluate(model)
                }
            }
    }
    
    var remoteQuery: URLQueryItem? {
        return nil // remote OR query not supported
    }
}

struct OrQueryItem<T: BaseModel>: QueryItem, QueryItemCombining {
    
    var queryItems: [any QueryItem<T>]
    
    var localQuery: Predicate<T> {
        queryItems
            .map { $0.localQuery }
            .reduce(Predicate<T>.false) { partialResult, next in
                #Predicate { model in
                    partialResult.evaluate(model) || next.evaluate(model)
                }
            }
    }
    
    var remoteQuery: URLQueryItem? {
        return nil // remote OR query not supported
    }
}

struct EqualQueryItem<T: BaseModel, V: EquatableQueryValue>: QueryItem {
    
    let keyPath: KeyPath<T, V>
    let value: V
    
    var localQuery: Predicate<T> {
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
    
    var remoteQuery: URLQueryItem? {
        guard let key = T.remoteQueryableKeys[keyPath] else {
            return nil
        }
        return URLQueryItem(
            name: key.stringValue,
            value: String(value.stringValue)
        )
    }
}
