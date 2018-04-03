//
//  DictionaryFuture.swift
//  GraphQL
//
//  Created by Jeff Seibert on 3/9/18.
//

import Foundation
import Async

extension Dictionary where Value: FutureType {
    public func flatten(on worker: Worker) -> Future<[Key: Value.Expectation]> {
        var elements: [Key: Value.Expectation] = [:]
        
        guard self.count > 0 else {
            return Future.map(on: worker) { elements }
        }
        
        let promise = worker.eventLoop.newPromise([Key: Value.Expectation].self)
        elements.reserveCapacity(self.count)
        
        for (key, value) in self {
            value.addAwaiter { result in
                switch result {
                case .error(let error): promise.fail(error: error)
                case .success(let expectation):
                    elements[key] = expectation
                    
                    if elements.count == self.count {
                        promise.succeed(result: elements)
                    }
                }
            }
        }
        
        return promise.futureResult
    }
}
