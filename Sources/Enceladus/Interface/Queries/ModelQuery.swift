//
//  File.swift
//  
//
//  Created by Leko Murphy on 5/31/24.
//

import Foundation

public struct ModelQuery<T: BaseModel>: QueryItemCombining {
    
    public let queryItems: [any QueryItem<T>]
    
    init(queryItems: [any QueryItem<T>]) {
        self.queryItems = queryItems
    }
    
    static func equals(_ keyPath: KeyPath<T, String>, _ value: String) -> ModelQuery<T> {
        ModelQuery(queryItems: [EqualQueryItem(keyPath, value)])
    }
}
