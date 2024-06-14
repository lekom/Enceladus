//
//  File.swift
//  
//
//  Created by Leko Murphy on 6/1/24.
//

import Foundation

public protocol PollableModel {
    
    static var pollingInterval: TimeInterval { get }    
}
