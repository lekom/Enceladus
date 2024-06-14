//
//  File.swift
//  
//
//  Created by Leko Murphy on 5/30/24.
//

import Enceladus
import Foundation
import SwiftData

@Model
public class MockBaseModel: ListModel {
    
    public var index: Int = 0
    public var lastCachedDate: Date? = nil
        
    @Attribute(.unique)
    public let id: String
    
    public let value: Int
        
    enum CodingKeys: StringConvertible, CodingKey {
        case id
        case value
        case lastCachedDate
    }
    
    public static var detail: Endpoint {
        Endpoint(
            service: MockService.self,
            path: "",
            requestMethod: .get
        )
    }
    
    public static var list: Endpoint {
        Endpoint(
            service: MockService.self,
            path: "",
            requestMethod: .get
        )
    }
    
    public static var pollInterval: TimeInterval { 30 }
    
    public static var cacheDuration: TimeInterval { 120 }
    
    public static var remoteQueryableKeys: [AnyKeyPath: StringConvertible] {
        [\MockBaseModel.id : CodingKeys.id]
    }
    
    public init(id: String, value: Int = 0, lastCachedDate: Date? = .now, index: Int = 0) {
        self.id = id
        self.value = value
        self.lastCachedDate = lastCachedDate
        self.index = index
    }
    
    // MARK: - Codable
    
    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        value = try container.decode(Int.self, forKey: .value)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(value, forKey: .value)
    }
    
    public static func isEqual(lhs: MockBaseModel, rhs: MockBaseModel) -> Bool {
        lhs.id == rhs.id && lhs.value == rhs.value
    }
}

extension MockBaseModel: DefaultQueryable {}
