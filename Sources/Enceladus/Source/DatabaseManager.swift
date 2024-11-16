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
    
    /// removes all persisted data from the table
    func reset()
    
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
        AsyncAwaitFuture<[T], Never> { promise in
            do {
                let result = try await fetch(modelType, predicate: predicate, sortedBy: sortDescriptor)
                promise(.success(result))
            } catch {
                promise(.success([])) // Return an empty array on failure
                assertionFailure("Failed to fetch models: \(error)")
            }
        }
        .eraseToAnyPublisher()
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
        AsyncAwaitFuture<[T], Never> { promise in
            do {
                let result = try await fetch(modelType, predicate: predicate, sortedBy: sortDescriptor)
                promise(.success(result))
            } catch {
                promise(.success([])) // Provide an empty array on failure
                assertionFailure("Failed to fetch models: \(error)")
            }
        }
        .eraseToAnyPublisher()
    }
    
    func delete<T: BaseModel>(_ model: T) throws {
        try delete(
            T.self,
            where: EqualQueryItem(T.idKeyPath, model.id).localQuery
        )
    }
}

struct DatabaseUpdateModel {
    let type: any BaseModel.Type
    let id: String
}

enum DatabaseUpdate {
    
    case modelUpdated(DatabaseUpdateModel)
    case modelsUpdated([DatabaseUpdateModel])
    case modelsDeleted([DatabaseUpdateModel])
    case allModelsDeleted(any BaseModel.Type)
    
    func isRelevant<M: BaseModel>(to modelType: M.Type, id: String? = nil) -> Bool {
        switch self {
        case .modelUpdated(let model):
            let isSameType = (model.type == modelType)
            return isSameType && (id == nil || id == model.id)
        case .modelsUpdated(let models), .modelsDeleted(let models):
            return models.contains { model in
                let isSameType = (model.type == modelType)
                return isSameType && (id == nil || id == model.id)
            }
        case .allModelsDeleted(let typeDeleted):
            return typeDeleted == modelType
        }
    }
}

class DatabaseManager: DatabaseManaging {
    
    var databaseUpdatePublisher: AnyPublisher<DatabaseUpdate, Never> {
        database.databaseUpdatePublisher
    }
        
    private var database: BaseModelActor!
    
    func register(modelContainer: ModelContainer) {
        do {
            try createAndStoreModelActor(for: modelContainer)
        } catch {
            assertionFailure("Failed to create model container: \(error)")
        }
    }
    
    func handleFetchedList<T: ListModel>(_ models: [T], query: ModelQuery<T>?) async throws -> [T] {
        return try await database.handleFetchedList(
            models,
            query: query
        )
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
        }
    }
    
    func save(_ model: any BaseModel) throws {
                
        Task {
            try await database.save(model)
        }
    }
    
    func delete<T: BaseModel>(
        models: [T]
    ) throws {
             
        Task {
            try await database.delete(models: models)
        }
    }
    
    func delete<T: BaseModel>(
        _ modelType: T.Type,
        where predicate: Predicate<T>
    ) throws {
                
        Task {
            let objectsToDelete = try await database.fetch(T.self, predicate: predicate)
            
            try await database.delete(modelType, where: predicate)
        }
    }
    
    func deleteAll<T: BaseModel>(_ modelType: T.Type) throws {
        
        Task {
            try await database.deleteAll(modelType)
        }
    }
    
    func reset() {
        Task {
            await database.reset()
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

final actor BaseModelActor {
        
    nonisolated let modelExecutor: any ModelExecutor
    nonisolated let modelContainer: ModelContainer
    
    private var modelContext: ModelContext { modelExecutor.modelContext }
    
    private let databaseUpdatePublishSubject = PassthroughSubject<DatabaseUpdate, Never>()
        
    nonisolated var databaseUpdatePublisher: AnyPublisher<DatabaseUpdate, Never> {
        databaseUpdatePublishSubject.eraseToAnyPublisher()
    }
    
    init(modelContainer: ModelContainer) {
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: ModelContext(modelContainer))
        self.modelContainer = modelContainer
    }
    
    func save<T: BaseModel>(_ models: [T]) throws {
        
        for model in models {
            model.lastCachedDate = .now
            modelContext.insert(model)
        }
                    
        let update = models.map { DatabaseUpdateModel(type: T.self, id: $0.id) }
        
        try modelContext.save()
        
        databaseUpdatePublishSubject.send(
            .modelsUpdated(update)
        )
    }
    
    func save(_ model: any BaseModel) throws {
        
        modelContext.insert(model)
        
        model.lastCachedDate = .now
        
        let update = DatabaseUpdateModel(type: type(of: model), id: model.id)
        
        try modelContext.save()
        
        databaseUpdatePublishSubject.send(
            .modelUpdated(update)
        )
    }
    
    func delete<T: BaseModel>(
        models: [T]
    ) throws {
        
        guard models.count > 0 else { return }
        
        for model in models {
            modelContext.delete(model)
        }
        
        let update = models.map { DatabaseUpdateModel(type: T.self, id: $0.id) }
        
        try modelContext.save()
        
        databaseUpdatePublishSubject.send(
            .modelsDeleted(
                update
            )
        )
    }
    
    func delete<T: BaseModel>(
        _ modelType: T.Type,
        where predicate: Predicate<T>
    ) throws {
                
        let objectsToDelete = try fetch(T.self, predicate: predicate)
        
        for object in objectsToDelete {
            modelContext.delete(object)
        }
        
        let update = objectsToDelete.map { DatabaseUpdateModel(type: T.self, id: $0.id) }
        
        try modelContext.save()
        
        databaseUpdatePublishSubject.send(
            .modelsDeleted(
                update
            )
        )
    }
    
    func deleteAll<T: BaseModel>(_ modelType: T.Type) throws {
        
        try modelContext.delete(model: T.self)
        
        try modelContext.save()
        
        databaseUpdatePublishSubject.send(
            .allModelsDeleted(T.self)
        )
    }
    
    func reset() {
        modelContext.container.deleteAllData()
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
    
    func handleFetchedList<T: ListModel>(
        _ models: [T],
        query: ModelQuery<T>?
    ) async throws -> [T] {
        
        var modelsToDelete = try await fetch(
            T.self,
            predicate: query?.localQuery
        ).reduce(into: [:]) {
            $0[$1.id] = $1
        }
        
        for (index, model) in models.enumerated() {
            model.index = index
            modelsToDelete.removeValue(forKey: model.id)
        }
        
        try modelContext.transaction {
            try save(models)
            
            let models: [T] = modelsToDelete.values.map { $0 }
            
            try delete(models: models)
        }
        
        try await modelContext.save()
        
        // TODO: eventually allow sort descriptor to be passed in
        let cachedModels = try await fetch(
            T.self,
            predicate: query?.localQuery,
            sortedBy: [
//                    SortDescriptor(\T.index),
//                    SortDescriptor(\T.id) // use id to break ties
            ]
        )
                
        return cachedModels
    }
}
