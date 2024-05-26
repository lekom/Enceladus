//
//  StreamManagerTests.swift
//
//
//  Created by Leko Murphy on 5/26/24.
//

import Combine
import Foundation
@testable import Enceladus
import XCTest

class StreamManagerTests: XCTestCase {
    
    private var cancelables = Set<AnyCancellable>()
    
    private var modelProvider: ModelProvider!
    
    private var dbManager: MockDatabaseManager!
    private var networkManager: MockNetworkManager!
    
    override func setUp() {
        super.setUp()
        cancelables.removeAll()
        
        dbManager = MockDatabaseManager(
            modelWrappers: [
                ModelWrapper(TestModel.self),
                ModelWrapper(ShortPollIntervalTestModel.self)
            ]
        )
        networkManager = MockNetworkManager()
        
        modelProvider = ModelProvider(
            databaseManager: dbManager,
            networkManager: networkManager
        )
    }
    
    // MARK: Stream Model
    
    func testStreamEmpty() {
                
        let expectation = XCTestExpectation(description: "Stream")
        
        modelProvider.streamModel(type: TestModel.self, id: "1").sink(
            receiveValue: { result in
                switch result {
                case .loaded:
                    XCTFail("should be no model cached")
                case .error(let error):
                    XCTAssertEqual(error as? NetworkError, .modelNotFound)
                    expectation.fulfill()
                case .loading:
                    break
                }
            }
        )
        .store(in: &cancelables)
        
        wait(for: [expectation], timeout: 1)
    }
    
    func testStreamCacheDB() {
        
        let testModels = [TestModel(id: "1", value: 42)]
        dbManager.models = testModels
        
        let expectation = expectation(description: "Stream")
        
        modelProvider.streamModel(type: TestModel.self, id: "1").sink(
            receiveValue: { result in
                switch result {
                case .loaded(let value):
                    XCTAssertEqual(value, testModels.first)
                    expectation.fulfill()
                case .error:
                    break
                case .loading:
                    break
                }
            }
        )
        .store(in: &cancelables)
        
        wait(for: [expectation], timeout: 1)
    }
    
    func testStreamCacheNetwork() {
        
        let testModels = [TestModel(id: "1", value: 42)]
        networkManager.models = testModels
        
        let expectation = expectation(description: "Stream")
        
        modelProvider.streamModel(type: TestModel.self, id: "1").sink(
            receiveValue: { result in
                switch result {
                case .loaded(let value):
                    XCTAssertEqual(value, testModels.first)
                    expectation.fulfill()
                case .error:
                    break
                case .loading:
                    break
                }
            }
        )
        .store(in: &cancelables)
        
        wait(for: [expectation], timeout: 1)
    }
    
    func testStreamCacheNetworkRepeated() {
        
        let testModels = [ShortPollIntervalTestModel(id: "1", value: 42)]
        networkManager.models = testModels
        
        let expectation = expectation(description: "Stream")
        expectation.expectedFulfillmentCount = 25
        expectation.assertForOverFulfill = false
        
        modelProvider.streamModel(type: ShortPollIntervalTestModel.self, id: "1").sink(
            receiveValue: { result in
                switch result {
                case .loaded(let value):
                    XCTAssertEqual(value, testModels.first)
                    expectation.fulfill()
                case .error:
                    break
                case .loading:
                    break
                }
            }
        )
        .store(in: &cancelables)
        
        wait(for: [expectation], timeout: 1)
    }
    
    // MARK: Stream list
    
    func testStreamListEmpty() {
        
        let expectation = XCTestExpectation(description: "Stream")
        
        modelProvider.streamCollection(type: TestModel.self).sink(
            receiveValue: { result in
                switch result {
                case .loaded(let models):
                    XCTAssertEqual(models, [])
                    expectation.fulfill()
                case .error(let error):
                    XCTFail("un expected error: \(error.localizedDescription)")
                case .loading:
                    break
                }
            }
        )
        .store(in: &cancelables)
        
        wait(for: [expectation], timeout: 1)
    }
    
    func testStreamListDBHasAFew() {
       
        let testModelsCached = [
            TestModel(id: "5", value: 5),
            TestModel(id: "6", value: 6)
        ]
        
        let testModelsNetwork = [
            TestModel(id: "1", value: 1),
            TestModel(id: "2", value: 2),
            TestModel(id: "3", value: 3)
        ]
        
        dbManager.models = testModelsCached
        networkManager.models = testModelsNetwork
        networkManager.networkDelay = 0.1 // give time for cache to come through first
        
        let expectationCache = XCTestExpectation(description: "StreamCache")
        let expectationNetwork = XCTestExpectation(description: "StreamNetwork")
        
        modelProvider.streamCollection(type: TestModel.self).sink(
            receiveValue: { result in
                switch result {
                case .loaded(let models):
                    if models.count == 3 {
                        XCTAssertTrue(models.contains(testModelsNetwork[0]))
                        XCTAssertTrue(models.contains(testModelsNetwork[1]))
                        XCTAssertTrue(models.contains(testModelsNetwork[2]))
                        expectationNetwork.fulfill()
                    } else if models.count == 2 {
                        XCTAssertTrue(models.contains(testModelsCached[0]))
                        XCTAssertTrue(models.contains(testModelsCached[1]))
                        expectationCache.fulfill()
                    }
                case .error(let error):
                    XCTFail("un expected error: \(error.localizedDescription)")
                case .loading:
                    break
                }
            }
        )
        .store(in: &cancelables)
        
        wait(for: [expectationCache, expectationNetwork], timeout: 1)
    }
    
    func testStreamListDBHasAFewFiltered() {
        
        let testModels = [
            TestModel(id: "1", value: 1),
            TestModel(id: "2", value: 2),
            TestModel(id: "3", value: 3)
        ]
        
        networkManager.models = testModels
        
        let expectation = XCTestExpectation(description: "Stream")
        
        modelProvider.streamCollection(
            type: TestModel.self,
            query: ModelQuery(
                urlQueryItems: nil,
                predicate: .equatable("foo", #Predicate { $0.value >= 2 }))
        ).sink(
            receiveValue: { result in
                switch result {
                case .loaded(let models):
                    XCTAssertEqual(models.count, 2)
                    XCTAssertTrue(models.contains(testModels[1]))
                    XCTAssertTrue(models.contains(testModels[2]))
                    expectation.fulfill()
                case .error(let error):
                    XCTFail("un expected error: \(error.localizedDescription)")
                case .loading:
                    break
                }
            }
        )
        .store(in: &cancelables)
        
        wait(for: [expectation], timeout: 1)
    }
    
    func testStreamListDBHasAFewFilteredRepeated() {
        
        let testModels = [
            ShortPollIntervalTestModel(id: "1", value: 1),
            ShortPollIntervalTestModel(id: "2", value: 2),
            ShortPollIntervalTestModel(id: "3", value: 3)
        ]
        
        networkManager.models = testModels
        
        let expectation = XCTestExpectation(description: "Stream")
        expectation.assertForOverFulfill = false
        expectation.expectedFulfillmentCount = 25
        
        modelProvider.streamCollection(
            type: ShortPollIntervalTestModel.self,
            query: ModelQuery(
                urlQueryItems: nil,
                predicate: .equatable("foo", #Predicate { $0.value >= 2 }))
        ).sink(
            receiveValue: { result in
                switch result {
                case .loaded(let models):
                    XCTAssertEqual(models.count, 2)
                    XCTAssertTrue(models.contains(testModels[1]))
                    XCTAssertTrue(models.contains(testModels[2]))
                    expectation.fulfill()
                case .error(let error):
                    XCTFail("un expected error: \(error.localizedDescription)")
                case .loading:
                    break
                }
            }
        )
        .store(in: &cancelables)
        
        wait(for: [expectation], timeout: 1)
    }
}
