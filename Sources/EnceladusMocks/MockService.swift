//
//  File.swift
//  
//
//  Created by Leko Murphy on 5/25/24.
//

import Foundation
import Enceladus

public struct MockService: Service {
    
    public var baseUrl: URL = URL(string: "https://google.com")!
    
    public init() {}
}
