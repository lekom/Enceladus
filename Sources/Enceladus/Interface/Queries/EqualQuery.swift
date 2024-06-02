//
//  File.swift
//  
//
//  Created by Leko Murphy on 5/31/24.
//

import Foundation
import SwiftData

public typealias EquatableQueryValue = Equatable & Hashable & Codable & StringConvertible

public struct EqualQueryItem<T: BaseModel, V: EquatableQueryValue>: QueryItem {
    
    let keyPath: KeyPath<T, V>
    let value: V
    
    init(_ keyPath: KeyPath<T, V>, _ value: V) {
        self.keyPath = keyPath
        self.value = value
    }
    
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
    
    public var remoteQuery: [URLQueryItem]? {
        guard let key = T.remoteQueryableKeys[keyPath] else {
            return nil
        }
        return [
            URLQueryItem(
                name: key.stringValue,
                value: String(value.stringValue)
            )
        ]
    }
}
