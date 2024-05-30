//
//  File.swift
//  
//
//  Created by Leko Murphy on 5/26/24.
//

import Foundation

protocol StringConvertible {
    
    var stringValue: String { get }
}

extension String: StringConvertible {
    
    var stringValue: String {
        return self
    }
}
