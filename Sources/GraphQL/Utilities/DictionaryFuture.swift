//
//  DictionaryFuture.swift
//  GraphQL
//
//  Created by Jeff Seibert on 3/9/18.
//

import Foundation
import Async

extension Dictionary where Value: FutureType {
    public func flatten() -> Future<[Key: Value.Expectation]> {
        var elements: [Key: Value.Expectation] = [:]
        
        guard self.count > 0 else {
            return Future(elements)
        }
        
        let promise = Promise<[Key: Value.Expectation]>()
        elements.reserveCapacity(self.count)
        
        for (key, value) in self {
            value.addAwaiter { result in
                switch result {
                case .error(let error): promise.fail(error)
                case .expectation(let expectation):
                    elements[key] = expectation
                    
                    if elements.count == self.count {
                        promise.complete(elements)
                    }
                }
            }
        }
        
        return promise.future
    }
}
