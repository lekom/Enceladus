//
//  File.swift
//  
//
//  Created by Leko Murphy on 5/11/24.
//

import Foundation

protocol Persistable {
    
    /// The duration in seconds that the data should be cached for
    var cacheDuration: TimeInterval { get }
}
