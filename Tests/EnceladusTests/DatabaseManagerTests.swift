import XCTest
@testable import Enceladus
import EnceladusMocks
import SwiftData

final class DatabaseManagerTests: XCTestCase {
    
    func testSimpleFetch() throws {
        
        let databaseManager = DatabaseManager(
            models: [MockBaseModel.self],
            configuration: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        
        let model1 = MockBaseModel(id: "1")
        let model2 = MockBaseModel(id: "2")
        let model3 = MockBaseModel(id: "3")
        
        try databaseManager.save(model1)
        try databaseManager.save(model2)
        try databaseManager.save(model3)
        
        let fetchedModels = try databaseManager.fetch(
            MockBaseModel.self,
            predicate: #Predicate { $0.id == "1" }
        )
        print(fetchedModels.map { $0.id })
        XCTAssertEqual(fetchedModels, [model1])
    }
    
    func testComplexFetch() throws {
        
        let databaseManager = DatabaseManager(
            models: [MockBaseModel.self],
            configuration: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        
        let model1 = MockBaseModel(id: "1", value: 1)
        let model2 = MockBaseModel(id: "2", value: 2)
        let model3 = MockBaseModel(id: "3", value: 3)
        let model4 = MockBaseModel(id: "4", value: 4)
        
        try databaseManager.save(model1)
        try databaseManager.save(model2)
        try databaseManager.save(model3)
        try databaseManager.save(model4)
        
        let fetchedModels = try databaseManager.fetch(
            MockBaseModel.self,
            predicate: #Predicate {
                $0.value >= 3 || $0.id == "1"
            }
        )
        print(fetchedModels.map { $0.id })
        XCTAssertTrue(fetchedModels.count == 3)
        XCTAssertTrue(fetchedModels.contains(model1))
        XCTAssertTrue(fetchedModels.contains(model3))
        XCTAssertTrue(fetchedModels.contains(model4))
    }
}

