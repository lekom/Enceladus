//
//  DatabaseManager.swift
//
//
//  Created by Leko Murphy on 5/25/24.
//

import Foundation
import SwiftData

protocol DatabaseManaging {
    
    func fetch<T: BaseModel>(
        _ modelType: T.Type,
        predicate: Predicate<T>?,
        sortedBy sortDescriptor: [SortDescriptor<T>]?
    ) throws -> [T]
    
    func save(_ model: any BaseModel) throws
    
    func delete<T: BaseModel>(_ modelType: T.Type, where predicate: Predicate<T>) throws
    
    func deleteAll<T: BaseModel>(_ modelType: T.Type) throws
}

// Defaults
extension DatabaseManaging {
    
    func fetch<T: BaseModel>(
        _ modelType: T.Type,
        predicate: Predicate<T>?
    ) throws -> [T] {
        try fetch(modelType, predicate: predicate, sortedBy: nil)
    }
    
    func fetch<T: BaseModel>(
        _ modelType: T.Type
    ) throws -> [T] {
        try fetch(modelType, predicate: nil)
    }
    
    func delete<T: BaseModel>(_ model: T) throws {
        try delete(T.self, where: #Predicate { $0.id == model.id })
    }
}

class DatabaseManager: DatabaseManaging {
        
    private var modelContainers: [ModelWrapper: ModelContainer] = [:]
    
    init(
        models: [any BaseModel.Type] = [],
        configuration: ModelConfiguration? = nil
    ) {
        do {
            for model in models {
                try createAndStoreModelContainer(for: model, configuration: configuration)
            }
        } catch {
            assertionFailure("Failed to create model container: \(error)")
        }
    }
    
    func fetch<T: BaseModel>(
        _ modelType: T.Type,
        predicate: Predicate<T>? = nil,
        sortedBy sortDescriptor: [SortDescriptor<T>]? = nil
    ) throws -> [T] {
        let container = try modelContainer(for: T.self)
        let context = ModelContext(container)
        
        let fetchDescriptor = FetchDescriptor<T>(
            predicate: predicate,
            sortBy: sortDescriptor ?? []
        )
        
        return try context.fetch(fetchDescriptor)
    }
    
    func save(_ model: any BaseModel) throws {
        let container = try modelContainer(for: type(of: model))
        let context = ModelContext(container)
        context.insert(model)
        
        try context.save()
    }
    
    func delete<T: BaseModel>(
        _ modelType: T.Type,
        where predicate: Predicate<T>
    ) throws {
        let container = try modelContainer(for: T.self)
        let context = ModelContext(container)

        try context.delete(
            model: T.self,
            where: predicate
        )
        
        try context.save()
    }
    
    func deleteAll<T: BaseModel>(_ modelType: T.Type) throws {
        let container = try modelContainer(for: T.self)
        let context = ModelContext(container)

        try context.delete(model: T.self)
    }
    
    private func modelContainer(for type: any BaseModel.Type) throws -> ModelContainer {
        let wrapper = ModelWrapper(type)
        guard let container = modelContainers[wrapper] else {
            fatalError("Model container not found for \(type)")
        }
        return container
    }
    
    @discardableResult
    private func createAndStoreModelContainer(
        for model: any BaseModel.Type,
        configuration: ModelConfiguration?
    ) throws -> ModelContainer {
        if let configuration {
            let container = try ModelContainer(for: model, configurations: configuration)
            modelContainers[ModelWrapper(model)] = container
            return container
        } else {
            let container = try ModelContainer(for: model)
            modelContainers[ModelWrapper(model)] = container
            return container
        }
    }
}
