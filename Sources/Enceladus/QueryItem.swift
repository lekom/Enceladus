//
//  Query.swift
//
//
//  Created by Leko Murphy on 5/24/24.
//

import Combine
import Foundation
import SwiftData

struct ModelQuery<T: BaseModel>: Hashable {
    
    let urlQueryItems: [URLQueryItem]?
    
    let predicate: EquatableWrapper<Predicate<T>>
}

extension Equatable {
    
    func isEqual(_ other: any Equatable) -> Bool {
        guard let other = other as? Self else {
            return false
        }
        return self == other
    }
}

extension Comparable {
    
    func isLessThan(_ other: any Comparable) -> Bool {
        guard let other = other as? Self else {
            return false
        }
        return self < other
    }
}
