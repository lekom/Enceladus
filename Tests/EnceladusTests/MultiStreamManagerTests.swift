//
//  StreamManagerTests.swift
//
//
//  Created by Leko Murphy on 5/26/24.
//

import Combine
import EnceladusMocks
import Foundation
@testable import Enceladus
import XCTest

class MultiStreamManagerTests: XCTestCase {
    
    private var cancelables = Set<AnyCancellable>()
    
    private var secondCancelables = Set<AnyCancellable>()
    
    private var streamManager: MultiStreamManager!
    
    private var dbManager: MockDatabaseManager!
    private var networkManager: MockNetworkManager!
    
    override func setUp() {
        super.setUp()
        cancelables.removeAll()
        secondCancelables.removeAll()
        
        dbManager = MockDatabaseManager(
            modelWrappers: [
                ModelWrapper(MockBaseModel.self),
                ModelWrapper(ShortPollIntervalTestModel.self)
            ]
        )
        networkManager = MockNetworkManager()
        
        streamManager = MultiStreamManager(
            fetchProvider: ModelFetchProvider(
                databaseManager: dbManager,
                networkManager: networkManager
            )
        )
    }
    
    // MARK: Stream Model
    
    func testStreamEmpty() {
                
        let expectation = XCTestExpectation(description: "Stream")
        
        streamManager.streamModel(type: MockBaseModel.self, id: "1").sink(
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
        
        let testModels = [MockBaseModel(id: "1", value: 42)]
        testModels.forEach { try? dbManager.save($0) }
        
        let expectation = expectation(description: "Stream")
        
        streamManager.streamModel(type: MockBaseModel.self, id: "1").sink(
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
        
        let testModels = [MockBaseModel(id: "1", value: 42)]
        networkManager.models = testModels
        
        let expectation = expectation(description: "Stream")
        
        streamManager.streamModel(type: MockBaseModel.self, id: "1").sink(
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
        
        streamManager.streamModel(type: ShortPollIntervalTestModel.self, id: "1").sink(
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
        
        streamManager.streamList(type: MockBaseModel.self)
            .sink(
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
            MockBaseModel(id: "5", value: 5, lastCachedDate: .now),
            MockBaseModel(id: "6", value: 6, lastCachedDate: .now)
        ]
        
        let testModelsNetwork = [
            MockBaseModel(id: "1", value: 1),
            MockBaseModel(id: "2", value: 2),
            MockBaseModel(id: "3", value: 3)
        ]
        
        testModelsCached.forEach { try? dbManager.save($0) }
        networkManager.models = testModelsNetwork
        networkManager.networkDelay = 0.1 // give time for cache to come through first
        
        let expectationCache = XCTestExpectation(description: "StreamCache")
        let expectationNetwork = XCTestExpectation(description: "StreamNetwork")
        
        streamManager.streamList(type: MockBaseModel.self).sink(
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
    
    // deletes missing items from the network response
    func testStreamListDBDeleteOnMissingValues() {
       
        let testModelsCached = [
            MockBaseModel(id: "5", value: 5, lastCachedDate: .now),
            MockBaseModel(id: "6", value: 6, lastCachedDate: .now)
        ]
        
        let testModelsNetwork = [
            MockBaseModel(id: "5", value: 5)
        ]
        
        testModelsCached.forEach { try? dbManager.save($0) }
        networkManager.models = testModelsNetwork
        networkManager.networkDelay = 0.1 // give time for cache to come through first
        
        let expectationCache = XCTestExpectation(description: "StreamCache")
        let expectationNetwork = XCTestExpectation(description: "StreamNetwork")
        
        streamManager.streamList(
            type: MockBaseModel.self,
            query: ModelQuery(
                queryItems: [
                    OrQueryItem(queryItems: [
                        EqualQueryItem(\.value, 5),
                        EqualQueryItem(\.value, 6)
                    ])
                ]
            )
        ).sink(
            receiveValue: { result in
                switch result {
                case .loaded(let models):
                    if models.count == 1 {
                        XCTAssertTrue(models.contains(testModelsNetwork[0]))
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
            MockBaseModel(id: "1", value: 1, lastCachedDate: .now),
            MockBaseModel(id: "2", value: 2, lastCachedDate: .now),
            MockBaseModel(id: "3", value: 3, lastCachedDate: .now)
        ]
        
        networkManager.models = testModels
        
        let expectation = XCTestExpectation(description: "Stream")
        
        streamManager.streamList(
            type: MockBaseModel.self,
            query: ModelQuery(
                queryItems: [
                    OrQueryItem(
                        queryItems: [
                            EqualQueryItem(\.value, 2),
                            EqualQueryItem(\.value, 3)
                        ]
                    )
                ]
            )
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
        
        streamManager.streamList(
            type: ShortPollIntervalTestModel.self,
            query: ModelQuery(
                queryItems: [
                    OrQueryItem(
                        queryItems: [
                            EqualQueryItem(\.value, 2),
                            EqualQueryItem(\.value, 3)
                        ]
                    )
                ]
            )
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
    
    func testMultipleSubcribers() throws {
        
        streamManager.streamList(type: MockBaseModel.self)
            .sink { _ in }
            .store(in: &cancelables)
        
        streamManager.streamList(type: MockBaseModel.self)
            .sink { _ in }
            .store(in: &cancelables)
        
        streamManager.streamList(type: MockBaseModel.self)
            .sink { _ in }
            .store(in: &cancelables)
        
        streamManager.streamModel(type: MockBaseModel.self)
            .sink { _ in }
            .store(in: &cancelables)
        
        streamManager.streamModel(type: MockBaseModel.self)
            .sink { _ in }
            .store(in: &cancelables)
        
        streamManager.streamModel(type: MockBaseModel.self, id: "42")
            .sink { _ in }
            .store(in: &secondCancelables)
        
        streamManager.streamModel(type: MockBaseModel.self, id: "42")
            .sink { _ in }
            .store(in: &secondCancelables)
        
        streamManager.streamModel(type: MockBaseModel.self, id: "42")
            .sink { _ in }
            .store(in: &secondCancelables)
        
        streamManager.streamModel(type: MockBaseModel.self, id: "42")
            .sink { _ in }
            .store(in: &secondCancelables)
        
        // list, singleton and detail w/id query
        XCTAssertEqualEventually(streamManager.subjects.values.count, 3)
        
        let idStreamKey = try XCTUnwrap(
            (Array(streamManager.subscriberCounts.keys) as? [StreamKey<MockBaseModel>])?.first(where: { $0.query != nil })
        )
        
        XCTAssertEqualEventually(streamManager.subscriberCounts[idStreamKey], 4)
        
        XCTAssertEqualEventually(
            self.streamManager.getSubscriberCount(for: StreamKey(MockBaseModel.self, type: .list, query: nil)),
            3
        )
        
        XCTAssertEqualEventually(
            self.streamManager.getSubscriberCount(for: StreamKey(MockBaseModel.self, type: .detail, query: nil)),
            2
        )
        
        secondCancelables.removeFirst()
        
        XCTAssertEqualEventually(self.streamManager.subjects.values.count, 3)
        XCTAssertEqualEventually(
            self.streamManager.getSubscriberCount(for: idStreamKey),
            3
        )
        
        secondCancelables.removeFirst()
        
        XCTAssertEqualEventually(self.streamManager.subjects.values.count, 3)
        XCTAssertEqualEventually(
            self.streamManager.getSubscriberCount(for: idStreamKey),
            2
        )
        
        secondCancelables.removeFirst()
        
        XCTAssertEqualEventually(self.streamManager.subjects.values.count, 3)
        XCTAssertEqualEventually(
            self.streamManager.getSubscriberCount(for: idStreamKey),
            1
        )
        
        secondCancelables.removeFirst()
        
        XCTAssertEqualEventually(self.streamManager.subjects.values.count, 2)
        XCTAssertEqualEventually(
            self.streamManager.getSubscriberCount(for: idStreamKey),
            0
        )
    }
}
