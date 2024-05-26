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
    
    var models: [any BaseModel] = []
    
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
            .compactMap { $0 as? T}
            .filter { (try? predicate?.evaluate($0)) ?? true }
    }

    func save(_ model: any BaseModel) throws {
        models += [model]
    }
    
    func delete<T>(_ modelType: T.Type, id: String) throws where T : Enceladus.BaseModel {
        models.removeAll(where: { $0.id == id })
    }
    
    func deleteAll<T>(_ modelType: T.Type) throws where T : BaseModel {
        models.removeAll(where: { $0 is T })
    }
}
