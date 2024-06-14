//
//  File.swift
//  
//
//  Created by Leko Murphy on 5/11/24.
//

import Foundation

public struct Endpoint {
    
    public let service: Service.Type
    
    public let path: String
    public let requestMethod: RequestMethodType
    
    public init(service: Service.Type, path: String, requestMethod: RequestMethodType) {
        self.service = service
        self.path = path
        self.requestMethod = requestMethod
    }
}

public extension Endpoint {
    
    var url: URL {
        return service.baseUrl.appendingPathComponent(path)
    }
}
