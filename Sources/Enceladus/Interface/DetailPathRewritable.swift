//
//  File.swift
//  
//
//  Created by Leko Murphy on 10/21/24.
//

import Foundation

public protocol DetailPathRewritable {
    
    /// if the `key` exists as part of the path, it will be rewritten with the corresponding `value` in the Enceladus query matching this key
    /// for example if query is ["id": "foobar"] and the path is `/myCoolModels/{id}/`and path rewrites returns `[id]`,
    /// then the path will be updated to `/myCoolModels/foobar/` for the request
    static var pathRewrites: [String] { get }
}
