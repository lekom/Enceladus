//
//  File.swift
//  
//
//  Created by Leko Murphy on 6/2/24.
//

import Foundation
import XCTest

/// Asserts that the given expression eventually becomes true.
func XCTAssertEventually(_ expression: @autoclosure () throws -> Bool, timeout: TimeInterval = 1, file: StaticString = #file, line: UInt = #line) {
    let timeoutDate = Date(timeIntervalSinceNow: timeout)
    var lastError: Error?
    while Date() < timeoutDate {
        do {
            if try expression() {
                return
            }
        } catch {
            lastError = error
        }
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
    }
    XCTFail("Expression did not become true before timeout", file: file, line: line)
    if let lastError = lastError {
        XCTFail(lastError.localizedDescription, file: file, line: line)
    }
}

func XCTAssertEqualEventually<T: Equatable>(_ expression1: @autoclosure () throws -> T, _ expression2: @autoclosure () throws -> T, timeout: TimeInterval = 1, file: StaticString = #file, line: UInt = #line) {
    XCTAssertEventually(try expression1() == expression2(), timeout: timeout, file: file, line: line)
}
