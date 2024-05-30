//
//  File.swift
//  
//
//  Created by Leko Murphy on 5/26/24.
//

import Foundation
@testable import Enceladus
import SwiftData

class MockDatabaseManager: DatabaseManaging {
    
    var models: [String: any BaseModel] = [:]
    
    private var modelContainers: [ModelWrapper: ModelContainer] = [:]
    
    init(modelWrappers: [ModelWrapper]) {
        for modelWrapper in modelWrappers {
            modelContainers[modelWrapper] = try? ModelContainer(
                for: modelWrapper.model.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        }
    }
    
    func fetch<T: BaseModel>(_ modelType: T.Type, predicate: Predicate<T>?, sortedBy: [SortDescriptor<T>]?) throws -> [T] {
        models
            .values
            .compactMap { $0 as? T}
            .filter { (try? predicate?.evaluate($0)) ?? true }
    }

    func save(_ model: any BaseModel) throws {
        models[model.id] = model
    }
    
    func delete<T>(_ modelType: T.Type, where predicate: Predicate<T>) throws where T : Enceladus.BaseModel {
//        try models.removeAll { model in
//            if let model = model as? T {
//                return try predicate.evaluate(model)
//            }
//            return false
//        }
        
        let models = models
        for (id, model) in models {
            if let model = model as? T, try predicate.evaluate(model) {
                self.models.removeValue(forKey: id)
            }
        }
    }
    
    func deleteAll<T>(_ modelType: T.Type) throws where T : BaseModel {
        let models = models
        for (id, model) in models {
            if model is T {
                self.models.removeValue(forKey: id)
            }
        }
    }
}
