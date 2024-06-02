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
    
    enum StreamType {
        case list
        case detail
        case first
    }
}
