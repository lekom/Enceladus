//
//  File.swift
//  
//
//  Created by Leko Murphy on 5/11/24.
//

import Foundation

enum ModelQueryResult<M: BaseModel> {
    
    case loading
    case loaded(M)
    case error(Error)
    
    var value: M? {
        switch self {
        case .loaded(let model):
            return model
        default:
            return nil
        }
    }
}

enum ListModelQueryResult<M: ListModel> {
    
    case loading
    case loaded([M])
    case error(Error)
    
    var value: [M]? {
        switch self {
        case .loaded(let models):
            return models
        default:
            return nil
        }
    }
}
