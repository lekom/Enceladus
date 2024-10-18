//
//  File.swift
//  
//
//  Created by Leko Murphy on 5/11/24.
//

import Foundation

public enum RequestMethodType: String, Codable, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}
