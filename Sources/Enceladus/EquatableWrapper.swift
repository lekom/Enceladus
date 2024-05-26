//
//  File.swift
//  
//
//  Created by Leko Murphy on 5/26/24.
//

import Foundation

struct EquatableWrapper<T>: Equatable, Hashable {
    
    let value: T
    
    let equatableValue: any Equatable & Hashable
    
    init(equatableValue: any Equatable & Hashable, value: T) {
        self.value = value
        self.equatableValue = equatableValue
    }
    
    init(_ value: T) where T: Equatable & Hashable {
        self.value = value
        self.equatableValue = value
    }
    
    static func == (lhs: EquatableWrapper<T>, rhs: EquatableWrapper<T>) -> Bool {
        return lhs.equatableValue.isEqual(rhs.equatableValue)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(equatableValue)
    }
    
    static func equatable(_ equatableValue: any Equatable & Hashable, _ value: T) -> EquatableWrapper<T> {
        EquatableWrapper(equatableValue: equatableValue, value: value)
    }
}
