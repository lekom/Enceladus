//
//  File.swift
//  
//
//  Created by Leko Murphy on 5/29/24.
//

import Foundation

extension Comparable {
    
    func isLessThan(_ other: any Comparable) -> Bool {
        guard let other = other as? Self else {
            return false
        }
        return self < other
    }
}
