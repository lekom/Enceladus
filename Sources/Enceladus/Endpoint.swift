//
//  File.swift
//  
//
//  Created by Leko Murphy on 5/11/24.
//

import Foundation

struct Endpoint {
    
    let service: Service
    let path: String
    let requestMethod: RequestMethodType
}

extension Endpoint {
    
    var url: URL {
        return service.baseUrl.appendingPathComponent(path)
    }
}
