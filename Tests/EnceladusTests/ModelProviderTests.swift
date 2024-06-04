//
//  File.swift
//  
//
//  Created by Leko Murphy on 5/30/24.
//

import Combine
@testable import Enceladus
@testable import EnceladusMocks
import Foundation
import XCTest

class ModelProviderTests: XCTestCase {
    
    private var cancellables: Set<AnyCancellable> = []
    
    private var modelProvider: ModelProvider!
    
    private var databaseManager: MockDatabaseManager!
    private var networkManager: MockNetworkManager!
    
    override func setUp() {
        super.setUp()
        
        cancellables.forEach { $0.cancel() }
        cancellables = []
        
        databaseManager = MockDatabaseManager(modelWrappers: [ModelWrapper(MockBaseModel.self)])
        networkManager = MockNetworkManager()
        
        modelProvider = ModelProvider(
            databaseManager: databaseManager,
            networkManager: networkManager
        )
    }
    
    func testAccessor() {
        mockModelProvider(MockModelProvider())
        
        let modelProvider = getModelProvider()
        
        XCTAssertTrue(modelProvider is MockModelProvider)
    }
    
    // MARK: - STREAM models (CACHED)
    
    func testStreamModelById() {
        let testModels = [
            MockBaseModel(id: "1"),
            MockBaseModel(id: "2"),
            MockBaseModel(id: "3")
        ]
           
        testModels
            .forEach {
                try? databaseManager.save($0)
            }
        
        let streamModelIdExpectation = expectation(description: "Stream model by id")
        
        modelProvider.streamModel(MockBaseModel.self, id: "2")
            .sink { result in
                switch result {
                case .loaded(let model):
                    XCTAssertEqual(model.id, "2")
                    streamModelIdExpectation.fulfill()
                default:
                    break
                }
            }
            .store(in: &cancellables)
        
        wait(for: [streamModelIdExpectation], timeout: 1)
    }
    
    func testStreamList() {
        let testModels = [
            MockBaseModel(id: "1"),
            MockBaseModel(id: "2"),
            MockBaseModel(id: "3")
        ]
           
        testModels
            .forEach {
                try? databaseManager.save($0)
            }
        
        let expectation = expectation(description: "Stream")
        expectation.expectedFulfillmentCount = 2
        
        modelProvider.streamListModel(MockBaseModel.self)
            .sink { result in
                switch result {
                case .loaded(let models):
                    if models.count == 3 { // initially cached with 3 items
                        expectation.fulfill()
                    } else if models.count == 0 { // network manager returns none
                        expectation.fulfill()
                    }
                default:
                    break
                }
            }
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1)
    }
    
    func testStreamSingleton() {
        let testModels = [
            MockBaseModel(id: "1")
        ]
           
        testModels
            .forEach {
                try? databaseManager.save($0)
            }
        
        let expectation = expectation(description: "Stream")
        
        modelProvider.streamModel(modelType: MockBaseModel.self)
            .sink { result in
                switch result {
                case .loaded(let model):
                    XCTAssertEqual(model.id, "1")
                    expectation.fulfill()
                case .loading:
                    break
                case .error:
                    break
                }
            }
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1)
    }
    
    func testStreamListFirstResult() {
        let testModels = [
            MockBaseModel(id: "1", index: 2),
            MockBaseModel(id: "2", index: 1),
            MockBaseModel(id: "3", index: 0)
        ]
           
        testModels
            .forEach {
                try? databaseManager.save($0)
            }
        
        let expectation = expectation(description: "Stream")
        
        modelProvider.streamFirstModel(MockBaseModel.self, query: nil)
            .sink { result in
                switch result {
                case .loaded(let model):
                    XCTAssertEqual(model.id, "3")
                    expectation.fulfill()
                case .loading:
                    break
                case .error:
                    break
                }
            }
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1)
    }
    
    // MARK: - GET models (CACHED)
    
    func testGetModelById() async {
        
        let testModels = [
            MockBaseModel(id: "1"),
            MockBaseModel(id: "2"),
            MockBaseModel(id: "3")
        ]
           
        testModels
            .forEach {
                try? databaseManager.save($0)
            }
        
        let result = await modelProvider.getModel(MockBaseModel.self, id: "2")
        
        switch result {
        case .success(let model):
            XCTAssertEqual(model.id, "2")
        case .failure:
            XCTFail("Should not be error")
        }
    }
    
    func testGetSingleton() async {
        let testModels = [
            MockBaseModel(id: "1")
        ]
           
        testModels
            .forEach {
                try? databaseManager.save($0)
            }
        
        let result = await modelProvider.getModel(MockBaseModel.self)
        
        switch result {
        case .success(let model):
            XCTAssertEqual(model.id, "1")
        case .failure:
            XCTFail("Should not be error")
        }
    }
    
    func testGetFirstModel() async {
        let testModels = [
            MockBaseModel(id: "1", index: 2),
            MockBaseModel(id: "2", index: 1),
            MockBaseModel(id: "3", index: 0)
        ]
           
        testModels
            .forEach {
                try? databaseManager.save($0)
            }
        
        let result = await modelProvider.getFirstModel(MockBaseModel.self, query: nil)
        
        switch result {
        case .success(let model):
            XCTAssertEqual(model.id, "3")
        case .failure:
            XCTFail("Should not be error")
        }
    }
    
    func testGetList() async {
        let testModels = [
            MockBaseModel(id: "1", index: 2),
            MockBaseModel(id: "2", index: 1),
            MockBaseModel(id: "3", index: 0)
        ]
           
        testModels
            .forEach {
                try? databaseManager.save($0)
            }
        
        let result = await modelProvider.getList(MockBaseModel.self, query: nil, limit: 3, sortDescriptors: nil)
        
        switch result {
        case .success(let models):
            XCTAssertEqual(models, testModels.reversed())
        case .failure:
            XCTFail("Should not be error")
        }
    }
    
    // MARK: - STREAM models (NETWORK)
    
    func testStreamModelByIdNetwork() {
        let testModels = [
            MockBaseModel(id: "1"),
            MockBaseModel(id: "2"),
            MockBaseModel(id: "3")
        ]
           
        networkManager.models = testModels
        
        let streamModelIdExpectation = expectation(description: "Stream model by id")
        
        modelProvider.streamModel(MockBaseModel.self, id: "2")
            .sink { result in
                switch result {
                case .loaded(let model):
                    print("FOO")
                    XCTAssertEqual(model.id, "2")
                    streamModelIdExpectation.fulfill()
                case .loading:
                    print("loading")
                    break
                case .error:
                    XCTFail("Should not be error")
                }
            }
            .store(in: &cancellables)
        
        wait(for: [streamModelIdExpectation], timeout: 1)
    }
    
    func testStreamListNetwork() {
        let testModels = [
            MockBaseModel(id: "1"),
            MockBaseModel(id: "2"),
            MockBaseModel(id: "3")
        ]
           
        networkManager.models = testModels
        
        let expectation = expectation(description: "Stream")
        
        modelProvider.streamListModel(MockBaseModel.self, query: nil)
            .sink { result in
                switch result {
                case .loaded(let models):
                    if models == testModels {
                        expectation.fulfill()
                    } else {
                        XCTFail("wrong models")
                    }
                case .loading:
                    break
                case .error:
                    XCTFail("Should not be error")
                }
            }
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1)
    }
    
    func testStreamSingletonNetwork() {
        let testModels = [
            MockBaseModel(id: "1")
        ]
           
        networkManager.models = testModels
        
        let expectation = expectation(description: "Stream")
        
        modelProvider.streamModel(modelType: MockBaseModel.self)
            .sink { result in
                switch result {
                case .loaded(let model):
                    XCTAssertEqual(model.id, "1")
                    expectation.fulfill()
                case .loading:
                    break
                case .error:
                    XCTFail("Should not be error")
                }
            }
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1)
    }
    
    func testStreamListFirstResultNetwork() {
        let testModels = [
            MockBaseModel(id: "1", index: 2),
            MockBaseModel(id: "2", index: 1),
            MockBaseModel(id: "3", index: 0)
        ]
           
        networkManager.models = testModels
        
        let expectation = expectation(description: "Stream")
        
        modelProvider.streamFirstModel(MockBaseModel.self, query: nil)
            .sink { result in
                switch result {
                case .loaded(let model):
                    XCTAssertEqual(model.id, "3")
                    expectation.fulfill()
                case .loading:
                    break
                case .error:
                    XCTFail("Should not be error")
                }
            }
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1)
    }
    
    // MARK: - GET models (NETWORK)
    
    func testGetModelByIdNetwork() async {
        
        let testModels = [
            MockBaseModel(id: "1"),
            MockBaseModel(id: "2"),
            MockBaseModel(id: "3")
        ]
           
        networkManager.models = testModels
        
        let result = await modelProvider.getModel(MockBaseModel.self, id: "2")
        
        switch result {
        case .success(let model):
            XCTAssertEqual(model.id, "2")
        case .failure:
            XCTFail("Should not be error")
        }
    }
    
    func testGetSingletonNetwork() async {
        let testModels = [
            MockBaseModel(id: "1")
        ]
           
        networkManager.models = testModels
        
        let result = await modelProvider.getModel(MockBaseModel.self)
        
        switch result {
        case .success(let model):
            XCTAssertEqual(model.id, "1")
        case .failure:
            XCTFail("Should not be error")
        }
    }
    
    func testGetFirstModelNetwork() async {
        let testModels = [
            MockBaseModel(id: "1"),
            MockBaseModel(id: "2"),
            MockBaseModel(id: "3")
        ]
           
        networkManager.models = testModels
        
        let result = await modelProvider.getFirstModel(MockBaseModel.self, query: nil)
        
        switch result {
        case .success(let model):
            XCTAssertEqual(model.id, "1")
        case .failure:
            XCTFail("Should not be error")
        }
    }
    
    func testGetListNetwork() async {
        let testModels = [
            MockBaseModel(id: "1", index: 2),
            MockBaseModel(id: "2", index: 1),
            MockBaseModel(id: "3", index: 0)
        ]
           
        networkManager.models = testModels
        
        let result = await modelProvider.getList(MockBaseModel.self, query: nil)
        
        switch result {
        case .success(let models):
            XCTAssertEqual(models, testModels)
        case .failure:
            XCTFail("Should not be error")
        }
    }
    
    // MARK: - Test Cached then Network
    
    private func streamModelByIdCachedThenNetwork() {
        let testModels = [
            MockBaseModel(id: "1"),
            MockBaseModel(id: "2"),
            MockBaseModel(id: "3")
        ]
           
        testModels
            .forEach {
                try? databaseManager.save($0)
            }
        
        networkManager.models = []
        
        let loading = expectation(description: "Loading")
        let network = expectation(description: "Stream model by id network")
        let cache = expectation(description: "Stream model by id cache")
        
        modelProvider.streamModel(MockBaseModel.self, id: "2")
            .sink { result in
                switch result {
                case .loaded(let model):
                    if model.id == "2" {
                        cache.fulfill()
                    }
                case .loading:
                    loading.fulfill()
                case .error(let error):
                    if let error = error as? NetworkError, case .modelNotFound = error {
                        network.fulfill()
                    }
                }
            }
            .store(in: &cancellables)
        
        wait(for: [loading, cache, network], timeout: 1)
    }
    
    func streamListCachedThenNetwork() {
        let testModels = [
            MockBaseModel(id: "1"),
            MockBaseModel(id: "2"),
            MockBaseModel(id: "3")
        ]
           
        testModels
            .forEach {
                try? databaseManager.save($0)
            }
        
        networkManager.models = [testModels[0]]
        
        let loading = expectation(description: "Loading")
        let network = expectation(description: "Stream model by id network")
        let cache = expectation(description: "Stream model by id cache")
        
        let loaded = expectation(description: "loaded")
        loaded.expectedFulfillmentCount = 2
        
        modelProvider.streamListModel(MockBaseModel.self, query: nil)
            .sink { result in
                switch result {
                case .loaded(let models):
                    if models == testModels {
                        cache.fulfill()
                    } else if models == [testModels[0]] {
                        network.fulfill()
                    }
                    
                    loaded.fulfill()
                case .loading:
                    loading.fulfill()
                case .error:
                    break
                }
            }
            .store(in: &cancellables)
        
        wait(for: [loading, cache, network, loaded], timeout: 1)
    }
    
    // MARK: - Test Configuration
    
    func testConfigureHeaders() {
        let headers = ["Authorization": "123"]
    
        modelProvider.configure(headersProvider: { headers })
        
        XCTAssertEqual(networkManager.headersProvider?(), headers)
    }
}
