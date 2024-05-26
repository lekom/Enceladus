
import Combine
import Foundation
import SwiftData

protocol BaseModel: Identifiable, Codable, PersistentModel {
    
    @Attribute(.unique)
    var id: String { get }
    
    /// The date the model was last fetched from the server.
    var lastCachedDate: Date { get }
    
    /// The endpoint to fetch the model from the server.
    static var detail: Endpoint { get }
    
    /// The interval at which the model should be polled for changes (seconds)
    static var pollInterval: TimeInterval { get }
    
    /// The interval at which the model should be cached (seconds)
    static var cacheDuration: TimeInterval { get }
    
    /// A map of KeyPaths to CodingKeys string value
    static var keyPathMap: [AnyKeyPath: StringConvertible] { get }
    
    /// Explicit equality
    static func isEqual(lhs: Self, rhs: Self) -> Bool
}

extension BaseModel {
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        Self.isEqual(lhs: lhs, rhs: rhs)
    }
}

protocol ListModel: BaseModel {
    
    /// The endpoint to fetch a list of models from the server.
    static var list: Endpoint { get }
}
