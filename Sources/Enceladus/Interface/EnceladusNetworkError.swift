//
//  EnceladusNetworkError.swift
//
//
//  Created by Leko Murphy on 11/13/24.
//

import Foundation

public enum EnceladusNetworkError: Error {
    case detailUrlMissing
    case modelNotFound
    case malformedListResponse
    case malformedDetailResponse
    case unauthorized
    case genericError(details: String)
    
    public var isUnauthorizedError: Bool {
        switch self {
        case .unauthorized:
            return true
        default:
            return false
        }
    }
}
