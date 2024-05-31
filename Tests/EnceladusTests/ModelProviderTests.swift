//
//  File.swift
//  
//
//  Created by Leko Murphy on 5/30/24.
//

import Enceladus
import EnceladusMocks
import Foundation
import XCTest

class ModelProviderTests: XCTestCase {
    
    func testAccessor() {
        mockModelProvider(MockModelProvider())
        
        let modelProvider = getModelProvider()
        
        XCTAssertTrue(modelProvider is MockModelProvider)
    }
}
