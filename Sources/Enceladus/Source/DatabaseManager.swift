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
    
    func register(_ modelType: any BaseModel.Type)
    
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
    
    func register(_ modelType: any BaseModel.Type) {
        do {
            try createAndStoreModelContainer(for: modelType, configuration: nil)
        } catch {
            assertionFailure("Failed to create model container: \(error)")
        }
    }
    
    func fetch<T: BaseModel>(
        _ modelType: T.Type,
        predicate: Predicate<T>? = nil,
        sortedBy sortDescriptor: [SortDescriptor<T>]? = nil
    ) throws -> [T] {
        let container = modelContainer(for: T.self)
        let context = ModelContext(container)
        
        let fetchDescriptor = FetchDescriptor<T>(
            predicate: predicate,
            sortBy: sortDescriptor ?? []
        )
        
        return try context.fetch(fetchDescriptor)
    }
    
    func save(_ model: any BaseModel) throws {
        let container = modelContainer(for: type(of: model))
        let context = ModelContext(container)
        context.insert(model)
        
        model.lastCachedDate = .now
        
        try context.save()
    }
    
    func delete<T: BaseModel>(
        _ modelType: T.Type,
        where predicate: Predicate<T>
    ) throws {
        let container = modelContainer(for: T.self)
        let context = ModelContext(container)

        try context.delete(
            model: T.self,
            where: predicate
        )
        
        try context.save()
    }
    
    func deleteAll<T: BaseModel>(_ modelType: T.Type) throws {
        let container = modelContainer(for: T.self)
        let context = ModelContext(container)

        try context.delete(model: T.self)
    }
    
    // MARK: Model Container Access
    
    private func modelContainer(for model: any BaseModel.Type) -> ModelContainer {
    
        guard let container = modelContainers[ModelWrapper(model)] else {
            fatalError("Model container not found for \(model)")
        }
        return container
    }
    
    // MARK: - Initialization of model containers (only done once at app launch)
    
    @discardableResult
    private func createAndStoreModelContainer(
        for model: any BaseModel.Type,
        configuration: ModelConfiguration?
    ) throws -> ModelContainer {
        if let configuration {
            let container = try ModelContainer(for: model, configurations: configuration)
            setModelContainer(container, for: model)
            return container
        } else {
            let container = try ModelContainer(for: model)
            setModelContainer(container, for: model)
            return container
        }
    }
    
    private func setModelContainer(_ container: ModelContainer, for model: any BaseModel.Type) {
        modelContainers[ModelWrapper(model)] = container
    }
}
