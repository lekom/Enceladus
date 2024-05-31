//
//  File.swift
//  
//
//  Created by Leko Murphy on 5/31/24.
//

import Foundation
import SwiftData

/// combines multiple query items with the AND operator into a single query item
public struct AndQueryItem<T: BaseModel>: QueryItem, QueryItemCombining {
    
    public let queryItems: [any QueryItem<T>]
}

/// combines multiple query items with the OR operator into a single query item
public struct OrQueryItem<T: BaseModel>: QueryItem, QueryItemCombining {
    
    public let queryItems: [any QueryItem<T>]
    
    // Override to use OR instead of default AND
    public var localQuery: Predicate<T> {
        queryItems
            .map { $0.localQuery }
            .reduce(Predicate<T>.false) { partialResult, next in
                #Predicate { model in
                    partialResult.evaluate(model) || next.evaluate(model)
                }
            }
    }
    
    public var remoteQuery: [URLQueryItem]? {
        return nil // remote OR query not supported
    }
}
