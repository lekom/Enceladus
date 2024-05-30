//
//  TestModel.swift
//
//
//  Created by Leko Murphy on 5/25/24.
//

import Foundation
@testable import Enceladus
import SwiftData

@Model
final class TestModel: Codable, ListModel, Equatable {
    
    var index: Int = 0
    var lastCachedDate: Date? = nil
        
    @Attribute(.unique)
    let id: String
    
    let value: Int
        
    enum CodingKeys: StringConvertible, CodingKey {
        case id
        case value
        case lastCachedDate
    }
    
    static var detail: Endpoint {
        Endpoint(
            service: TestService(),
            path: "",
            requestMethod: .get
        )
    }
    
    static var list: Endpoint {
        Endpoint(
            service: TestService(),
            path: "",
            requestMethod: .get
        )
    }
    
    static var pollInterval: TimeInterval { 30 }
    
    static var cacheDuration: TimeInterval { 120 }
    
    static var remoteQueryableKeys: [AnyKeyPath: StringConvertible] {
        [\TestModel.id : CodingKeys.id]
    }
    
    init(id: String, value: Int = 0, lastCachedDate: Date? = .now) {
        self.id = id
        self.value = value
        self.lastCachedDate = lastCachedDate
    }
    
    // MARK: - Codable
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        value = try container.decode(Int.self, forKey: .value)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(value, forKey: .value)
    }
    
    static func isEqual(lhs: TestModel, rhs: TestModel) -> Bool {
        lhs.id == rhs.id && lhs.value == rhs.value
    }
}
