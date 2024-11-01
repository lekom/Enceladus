//
//  File.swift
//  
//
//  Created by Leko Murphy on 5/11/24.
//

import Foundation

public enum ModelQueryResult<M: BaseModel>: Equatable {
    
    case loading
    case loaded(M)
    case error(Error)
    
    public var value: M? {
        switch self {
        case .loaded(let model):
            return model
        default:
            return nil
        }
    }
    
    public var isLoading: Bool {
        switch self {
        case .loading:
            return true
        case .loaded, .error:
            return false
        }
    }
    
    public static func ==(lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading):
            return true
        case (.loaded(let lhsModel), .loaded(let rhsModel)):
            return lhsModel == rhsModel
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

public enum ListModelQueryResult<M: ListModel>: Equatable {
    
    case loading
    case loaded([M])
    case error(Error)
    
    public var value: [M]? {
        switch self {
        case .loaded(let models):
            return models
        default:
            return nil
        }
    }
    
    func loadedPrefix(_ maxLength: Int?) -> Self {
        guard let maxLength = maxLength else {
            return self
        }
        
        switch self {
        case .loaded(let models):
            return .loaded(Array(models.prefix(maxLength)))
        default:
            return self
        }
    }
    
    public var isLoading: Bool {
        switch self {
        case .loading:
            return true
        case .loaded, .error:
            return false
        }
    }
    
    public static func ==(lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading):
            return true
        case (.loaded(let lhsModels), .loaded(let rhsModels)):
            return lhsModels == rhsModels
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
    
    public func mapLoaded(_ transform: ([M]) -> [M]) -> ListModelQueryResult<M> {
        switch self {
        case .loading:
            return .loading
        case .loaded(let models):
            return .loaded(transform(models))
        case .error(let error):
            return .error(error)
        }
    }
}
