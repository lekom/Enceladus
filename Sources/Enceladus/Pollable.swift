//
//  File.swift
//  
//
//  Created by Leko Murphy on 5/11/24.
//

import Foundation

protocol Pollable {
    
    /// The interval at which to poll the server for updates.
    var pollInterval: TimeInterval { get }
}
