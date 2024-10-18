
import Combine
import Foundation
import SwiftData

public protocol BaseModel: Equatable, Identifiable, Codable, PersistentModel {
    
    var id: String { get }
    
    /// The date the model was last fetched from the server.
    var lastCachedDate: Date? { get set }
    
    /// The endpoint to fetch the model from the server.
    static var detail: Endpoint? { get }
    
    /// The interval at which the model should be cached (seconds)
    static var cacheDuration: TimeInterval { get }
    
    /// A map of KeyPaths to the remote queryable key value
    static var remoteQueryableKeys: [AnyKeyPath: StringConvertible] { get }
    
    /// Explicit equality
    static func isEqual(lhs: Self, rhs: Self) -> Bool
}

public extension BaseModel {
    
    static var remoteQueryableKeys: [AnyKeyPath: StringConvertible] {
        [:]
    }
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        Self.isEqual(lhs: lhs, rhs: rhs)
    }
}

public protocol ListModel: BaseModel {
    
    /// The endpoint to fetch a list of models from the server.
    static var list: Endpoint { get }
    
    /// The index of the model in the list.
    var index: Int { get set }
    
    static var nestedKey: String { get }
}

extension ListModel {
    
    public static var nestedKey: String {
        "results"
    }
}

/// Models that should only have one instance in the cache.  Detail API does not require an id.
public typealias SingletonModel = BaseModel & DefaultQueryable

/// Models that are able to be fetched without any query provided
public protocol DefaultQueryable {}
