//
//  Query.swift
//
//
//  Created by Leko Murphy on 5/24/24.
//

import Combine
import Foundation
import SwiftData

public protocol QueryItem<T>: Equatable, Hashable {
    associatedtype T: BaseModel
    var localQuery: Predicate<T> { get }
    var remoteQuery: [URLQueryItem]? { get } // overall query assumed to be && of each individual query
}

public protocol QueryItemCombining: QueryItem {

    var queryItems: [any QueryItem<T>] { get }
    
    var localQuery: Predicate<T> { get }
    var remoteQuery: [URLQueryItem]? { get }
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
        let queryItems: [URLQueryItem] = queryItems.reduce([], { $0 + ($1.remoteQuery ?? []) })
        
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
