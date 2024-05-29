//
//  File.swift
//  
//
//  Created by Leko Murphy on 5/29/24.
//

import Foundation

extension Equatable {
    
    func isEqual(_ other: any Equatable) -> Bool {
        guard let other = other as? Self else {
            return false
        }
        return self == other
    }
}
