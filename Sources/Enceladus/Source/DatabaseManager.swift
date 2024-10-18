//
//  DatabaseManager.swift
//
//
//  Created by Leko Murphy on 5/25/24.
//

import Combine
import Foundation
import SwiftData

protocol DatabaseManaging {
    
    func fetch<T: BaseModel>(
        _ modelType: T.Type,
        predicate: Predicate<T>?,
        sortedBy sortDescriptor: [SortDescriptor<T>]?
    ) throws -> [T]
    
    func fetch<T: ListModel>(
        _ modelType: T.Type,
        predicate: Predicate<T>?,
        sortedBy sortDescriptor: [SortDescriptor<T>]?
    ) throws -> [T]
    
    func register(_ modelType: any BaseModel.Type)
    
    func save<T: BaseModel>(_ models: [T]) throws 
    func save(_ model: any BaseModel) throws
    
    func delete<T: BaseModel>(_ modelType: T.Type, where predicate: Predicate<T>) throws
    func delete<T: BaseModel>(models: [T]) throws
    
    func deleteAll<T: BaseModel>(_ modelType: T.Type) throws
    
    var databaseUpdatePublisher: AnyPublisher<DatabaseUpdate, Never> { get }
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

enum DatabaseUpdate {
    
    case modelUpdated(any BaseModel)
    case modelsUpdated([any BaseModel])
    case modelsDeleted([any BaseModel])
    case allModelsDeleted(any BaseModel.Type)
    
    func isRelevant<M: BaseModel>(to modelType: M.Type, id: String? = nil) -> Bool {
        switch self {
        case .modelUpdated(let model):
            let isSameType = (type(of: model) == modelType)
            return isSameType && (id == nil || id == model.id)
        case .modelsUpdated(let models), .modelsDeleted(let models):
            return models.contains { model in
                let isSameType = (type(of: model) == modelType)
                return isSameType && (id == nil || id == model.id)
            }
        case.allModelsDeleted(let typeDeleted):
            return typeDeleted == modelType
        }
    }
}

class DatabaseManager: DatabaseManaging {
        
    private var modelContexts: [ModelWrapper: ModelContext] = [:]
    
    private let databaseUpdatePublishSubject = PassthroughSubject<DatabaseUpdate, Never>()
        
    var databaseUpdatePublisher: AnyPublisher<DatabaseUpdate, Never> {
        databaseUpdatePublishSubject.eraseToAnyPublisher()
    }
        
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
        
        let context = modelContext(for: T.self)
        
        let fetchDescriptor = FetchDescriptor<T>(
            predicate: predicate,
            sortBy: sortDescriptor ?? []
        )
        
        return try context.fetch(fetchDescriptor)
    }
    
    func fetch<T: ListModel>(
        _ modelType: T.Type,
        predicate: Predicate<T>? = nil,
        sortedBy sortDescriptor: [SortDescriptor<T>]? = nil
    ) throws -> [T] {
        
        let context = modelContext(for: T.self)
        
        let fetchDescriptor = FetchDescriptor<T>(
            predicate: predicate,
            sortBy: sortDescriptor ?? []
        )
        
        return try context.fetch(fetchDescriptor)
    }
    
    private func defaultListSortDescriptor<T: ListModel>() -> [SortDescriptor<T>] {
        [
//            SortDescriptor(\T.index),
//            SortDescriptor(\T.id) // use id to break ties
        ]
    }
    
    func save<T: BaseModel>(_ models: [T]) throws {
        let context = modelContext(for: T.self)
        
        for model in models {
            model.lastCachedDate = .now
            context.insert(model)
        }
                    
        try context.save()
        
        databaseUpdatePublishSubject.send(.modelsUpdated(models))
    }
    
    func save(_ model: any BaseModel) throws {
        
        let context = modelContext(for: type(of: model))
        context.insert(model)
        
        model.lastCachedDate = .now
        
        try context.save()
        
        databaseUpdatePublishSubject.send(.modelUpdated(model))
    }
    
    func delete<T: BaseModel>(
        models: [T]
    ) throws {
        let context = modelContext(for: T.self)
                
        for model in models {
            context.delete(model)
        }
        
        try context.save()
        
        databaseUpdatePublishSubject.send(.modelsDeleted(models))
    }
    
    func delete<T: BaseModel>(
        _ modelType: T.Type,
        where predicate: Predicate<T>
    ) throws {
        
        let context = modelContext(for: T.self)
        
        let objectsToDelete = try fetch(T.self, predicate: predicate)
        
        for object in objectsToDelete {
            context.delete(object)
        }
        
        try context.save()
        
        databaseUpdatePublishSubject.send(.modelsDeleted(objectsToDelete))
    }
    
    func deleteAll<T: BaseModel>(_ modelType: T.Type) throws {
        let context = modelContext(for: T.self)
        
        try context.delete(model: T.self)
        
        try context.save()
        
        databaseUpdatePublishSubject.send(.allModelsDeleted(T.self))
    }
    
    // MARK: Model Container Access
    
    private func modelContext(for model: any BaseModel.Type) -> ModelContext {
    
        guard let context = modelContexts[ModelWrapper(model)] else {
            fatalError("Model container not found for \(model)")
        }
        return context
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
        let context = ModelContext(container)
        modelContexts[ModelWrapper(model)] = context
    }
}
