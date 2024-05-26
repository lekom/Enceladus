//
//  File.swift
//  
//
//  Created by Leko Murphy on 5/11/24.
//

import Foundation

class ModelWrapper: Hashable, Equatable {
    
    let model: any BaseModel.Type
    
    init(_ model: any BaseModel.Type) {
        self.model = model
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(model))
    }
    
    static func == (lhs: ModelWrapper, rhs: ModelWrapper) -> Bool {
        return lhs.model == rhs.model
    }
}
