//
//  File.swift
//  
//
//  Created by Leko Murphy on 5/26/24.
//

import Foundation

public protocol StringConvertible {
    
    var stringValue: String { get }
}

extension String: StringConvertible {
    
    public var stringValue: String {
        return self
    }
}

extension Int: StringConvertible {
    
    public var stringValue: String {
        "\(self)"
    }
}
