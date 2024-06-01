//
//  File.swift
//  
//
//  Created by Leko Murphy on 6/1/24.
//

import Foundation

protocol PollableModel {
    
    static var pollingInterval: TimeInterval { get }    
}
