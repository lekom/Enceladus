//
//  ShortPollIntervalTestModel.swift
//
//
//  Created by Leko Murphy on 5/26/24.
//

import Foundation

import Foundation
@testable import Enceladus
import SwiftData

@Model
final class ShortPollIntervalTestModel: Codable, ListModel, Equatable {
        
    @Attribute(.unique)
    let id: String
    
    let value: Int
    
    let lastCachedDate: Date = Date.now
    
    enum CodingKeys: StringConvertible, CodingKey {
        case id
        case value
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
    
    static var pollInterval: TimeInterval { 0.001 }
    
    static var cacheDuration: TimeInterval { 120 }
    
    static var keyPathMap: [AnyKeyPath : StringConvertible] {
        [\TestModel.id : CodingKeys.id]
    }
    
    init(id: String, value: Int = 0) {
        self.id = id
        self.value = value
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
    
    static func isEqual(lhs: ShortPollIntervalTestModel, rhs: ShortPollIntervalTestModel) -> Bool {
        lhs.id == rhs.id && lhs.value == rhs.value
    }
}
