//
//  File.swift
//  
//
//  Created by Leko Murphy on 5/31/24.
//

import Combine
import Foundation

#if DEBUG
var mockedModelProvider: ModelProviding?

/// Sets the model provider to be used in unit tests
public func mockModelProvider(_ provider: ModelProviding) {
    mockedModelProvider = provider
}
#endif

/// Dependency injection accessor for ModelProvider
public let getModelProvider: () -> ModelProviding = {
    
#if DEBUG
    if isUnitTesting {
        guard let mockedModelProvider else {
            fatalError("Mocked model provider not set")
        }
        
        return mockedModelProvider
    }
#endif
    
    return ModelProvider.shared
}
