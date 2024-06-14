//
//  File.swift
//  
//
//  Created by Leko Murphy on 5/11/24.
//

import Foundation

public enum ModelQueryResult<M: BaseModel> {
    
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
}

public enum ListModelQueryResult<M: ListModel> {
    
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
}
