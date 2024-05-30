//
//  File.swift
//  
//
//  Created by Leko Murphy on 5/30/24.
//

import Foundation

var isUnitTesting: Bool {
    ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
}
