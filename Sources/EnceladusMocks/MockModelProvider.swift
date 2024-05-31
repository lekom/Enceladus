//
//  File.swift
//  
//
//  Created by Leko Murphy on 5/30/24.
//

import Combine
import Enceladus
import Foundation
import SwiftData

public struct MockModelProvider: ModelProviding {

    public func streamModel<T: BaseModel>(_ modelType: T.Type, id: String) -> AnyPublisher<ModelQueryResult<T>, Never> {
        Just(.loading).eraseToAnyPublisher()
    }
    
    public func streamListModel<T: ListModel>(_ modelType: T.Type, query: ModelQuery<T>) -> AnyPublisher<ListModelQueryResult<T>, Never> {
        Just(.loading).eraseToAnyPublisher()
    }
    
    public func getModel<T: BaseModel>(_ modelType: T.Type, query: ModelQuery<T>) async -> Result<T, Error> {
        .failure(MockError.notImplemented)
    }
    
    public func getList<T: ListModel>(_ modelType: T.Type, query: Enceladus.ModelQuery<T>) async -> Result<[T], Error> {
        .failure(MockError.notImplemented)
    }
    
    public init() {}
    
    enum MockError: Error {
        case notImplemented
    }
}
