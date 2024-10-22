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
    ) async throws -> [T]
    
    func fetch<T: BaseModel>(
        _ modelType: T.Type,
        predicate: Predicate<T>?,
        sortedBy sortDescriptor: [SortDescriptor<T>]?
    ) -> AnyPublisher<[T], Never>
    
    func fetch<T: ListModel>(
        _ modelType: T.Type,
        predicate: Predicate<T>?,
        sortedBy sortDescriptor: [SortDescriptor<T>]?
    ) async throws -> [T]
    
    func fetch<T: ListModel>(
        _ modelType: T.Type,
        predicate: Predicate<T>?,
        sortedBy sortDescriptor: [SortDescriptor<T>]?
    ) -> AnyPublisher<[T], Never>
    
    func register(modelContainer: ModelContainer)
    
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
    ) async throws -> [T] {
        try await fetch(modelType, predicate: predicate, sortedBy: nil)
    }
    
    func fetch<T: BaseModel>(
        _ modelType: T.Type,
        predicate: Predicate<T>?,
        sortedBy sortDescriptor: [SortDescriptor<T>]?
    ) -> AnyPublisher<[T], Never> {
        let subject = PassthroughSubject<[T], Never>()
        Task {
            do {
                let result = try await fetch(modelType, predicate: predicate, sortedBy: sortDescriptor)
                subject.send(result)
            } catch {
                subject.send([])
                assertionFailure("Failed to fetch models: \(error)")
            }
        }
        return subject.eraseToAnyPublisher()
    }
    
    func fetch<T: BaseModel>(
        _ modelType: T.Type
    ) async throws -> [T] {
        try await fetch(modelType, predicate: nil)
    }
    
    func fetch<T: ListModel>(
        _ modelType: T.Type,
        predicate: Predicate<T>?,
        sortedBy sortDescriptor: [SortDescriptor<T>]?
    ) -> AnyPublisher<[T], Never> {
        let subject = PassthroughSubject<[T], Never>()
        Task {
            do {
                let result = try await fetch(modelType, predicate: predicate, sortedBy: sortDescriptor)
                subject.send(result)
            } catch {
                subject.send([])
                assertionFailure("Failed to fetch models: \(error)")
            }
        }
        return subject.eraseToAnyPublisher()
    }
    
    func delete<T: BaseModel>(_ model: T) throws {
        try delete(
            T.self,
            where: EqualQueryItem(T.idKeyPath, model.id).localQuery
        )
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
        
    private var database: BaseModelActor!
    
    private let databaseUpdatePublishSubject = PassthroughSubject<DatabaseUpdate, Never>()
        
    var databaseUpdatePublisher: AnyPublisher<DatabaseUpdate, Never> {
        databaseUpdatePublishSubject.eraseToAnyPublisher()
    }
    
    func register(modelContainer: ModelContainer) {
        do {
            try createAndStoreModelActor(for: modelContainer)
        } catch {
            assertionFailure("Failed to create model container: \(error)")
        }
    }
    
    func fetch<T: BaseModel>(
        _ modelType: T.Type,
        predicate: Predicate<T>? = nil,
        sortedBy sortDescriptor: [SortDescriptor<T>]? = nil
    ) async throws -> [T] {
                
        return try await database.fetch(
            T.self,
            predicate: predicate,
            sortedBy: sortDescriptor
        )
    }
    
    func fetch<T: ListModel>(
        _ modelType: T.Type,
        predicate: Predicate<T>? = nil,
        sortedBy sortDescriptor: [SortDescriptor<T>]? = nil
    ) async throws -> [T] {
            
        return try await database.fetch(
            T.self,
            predicate: predicate,
            sortedBy: sortDescriptor
        )
    }
    
    private func defaultListSortDescriptor<T: ListModel>() -> [SortDescriptor<T>] {
        [
//            SortDescriptor(\T.index),
//            SortDescriptor(\T.id) // use id to break ties
        ]
    }
    
    func save<T: BaseModel>(_ models: [T]) throws {
        
        Task {
            try await database.save(models)
            
            databaseUpdatePublishSubject.send(.modelsUpdated(models))
        }
    }
    
    func save(_ model: any BaseModel) throws {
                
        Task {
            try await database.save(model)
            
            databaseUpdatePublishSubject.send(.modelUpdated(model))
        }
    }
    
    func delete<T: BaseModel>(
        models: [T]
    ) throws {
             
        Task {
            try await database.delete(models: models)
            
            databaseUpdatePublishSubject.send(.modelsDeleted(models))
        }
    }
    
    func delete<T: BaseModel>(
        _ modelType: T.Type,
        where predicate: Predicate<T>
    ) throws {
                
        Task {
            let objectsToDelete = try await database.fetch(T.self, predicate: predicate)
            
            try await database.delete(modelType, where: predicate)
            
            databaseUpdatePublishSubject.send(.modelsDeleted(objectsToDelete))
        }
    }
    
    func deleteAll<T: BaseModel>(_ modelType: T.Type) throws {
        
        Task {
            try await database.deleteAll(modelType)
                        
            databaseUpdatePublishSubject.send(.allModelsDeleted(T.self))
        }
    }
    
    // MARK: - Initialization of model containers (only done once at app launch)
    
    @discardableResult
    private func createAndStoreModelActor(
        for modelContainer: ModelContainer
    ) {
                
        database = try BaseModelActor(
            modelContainer: modelContainer
        )
    }
}

@ModelActor
actor BaseModelActor {
        
    func save<T: BaseModel>(_ models: [T]) throws {
        for model in models {
            model.lastCachedDate = .now
            modelContext.insert(model)
        }
                    
        try modelContext.save()
    }
    
    func save(_ model: any BaseModel) throws {
        
        modelContext.insert(model)
        
        model.lastCachedDate = .now
        
        try modelContext.save()
    }
    
    func delete<T: BaseModel>(
        models: [T]
    ) throws {
                
        for model in models {
            modelContext.delete(model)
        }
        
        try modelContext.save()
    }
    
    func delete<T: BaseModel>(
        _ modelType: T.Type,
        where predicate: Predicate<T>
    ) throws {
                
        let objectsToDelete = try fetch(T.self, predicate: predicate)
        
        for object in objectsToDelete {
            modelContext.delete(object)
        }
        
        try modelContext.save()
    }
    
    func deleteAll<T: BaseModel>(_ modelType: T.Type) throws {
        
        try modelContext.delete(model: T.self)
        
        try modelContext.save()
    }
    
    func fetch<T: BaseModel>(
        _ modelType: T.Type,
        predicate: Predicate<T>? = nil,
        sortedBy sortDescriptor: [SortDescriptor<T>]? = nil
    ) throws -> [T] {
                
        let fetchDescriptor = FetchDescriptor<T>(
            predicate: predicate,
            sortBy: sortDescriptor ?? []
        )
        
        return try modelContext.fetch(fetchDescriptor)
    }
    
    func fetch<T: ListModel>(
        _ modelType: T.Type,
        predicate: Predicate<T>? = nil,
        sortedBy sortDescriptor: [SortDescriptor<T>]? = nil
    ) throws -> [T] {
                
        let fetchDescriptor = FetchDescriptor<T>(
            predicate: predicate,
            sortBy: sortDescriptor ?? []
        )
        
        return try modelContext.fetch(fetchDescriptor)
    }
}
