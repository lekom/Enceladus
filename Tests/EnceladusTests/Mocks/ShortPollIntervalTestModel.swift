//
//  ShortPollIntervalTestModel.swift
//
//
//  Created by Leko Murphy on 5/26/24.
//

import Foundation
@testable import Enceladus
import EnceladusMocks
import SwiftData

@Model
final class ShortPollIntervalTestModel: Codable, ListModel, Equatable {
    
    var index: Int = 0
        
    @Attribute(.unique)
    let id: String
    
    let value: Int
    
    var lastCachedDate: Date? = nil
    
    enum CodingKeys: StringConvertible, CodingKey {
        case id
        case value
    }
    
    static var detail: Endpoint {
        Endpoint(
            service: MockService(),
            path: "",
            requestMethod: .get
        )
    }
    
    static var list: Endpoint {
        Endpoint(
            service: MockService(),
            path: "",
            requestMethod: .get
        )
    }
        
    static var cacheDuration: TimeInterval { 120 }
    
    static var remoteQueryableKeys: [AnyKeyPath : StringConvertible] {
        [\MockBaseModel.id : CodingKeys.id]
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
    
    static func isEqual(lhs: ShortPollIntervalTestModel, rhs: ShortPollIntervalTestModel) -> Bool {
        lhs.id == rhs.id && lhs.value == rhs.value
    }
}

extension ShortPollIntervalTestModel: PollableModel {
    
    static var pollingInterval: TimeInterval { 0.001 }
}
