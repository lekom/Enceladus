//
//  File.swift
//  
//
//  Created by Leko Murphy on 6/2/24.
//

import Foundation

struct StreamKey<T: BaseModel>: Hashable {
    
    init(model: ModelWrapper, type: StreamType, query: ModelQuery<T>?) {
        self.model = model
        self.type = type
        self.query = query
    }
    
    init(_ modelType: T.Type, type: StreamType, query: ModelQuery<T>?) {
        self.model = ModelWrapper(modelType)
        self.type = type
        self.query = query
    }
    
    let model: ModelWrapper
    
    let type: StreamType
    
    let query: ModelQuery<T>?
    
    enum StreamType: Hashable {
        case list(limit: Int?, sortDescriptors: [SortDescriptor<T>]?)
        case detail
        case first
    }
    
    var limit: Int? {
        guard case let .list(limit, _) = type else { return nil }
        return limit
    }
    
    var sortDescriptors: [SortDescriptor<T>]? {
        guard case let .list(_, sortDescriptors) = type else { return nil }
        return sortDescriptors
    }
}
