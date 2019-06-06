//
//  DictionaryFuture.swift
//  GraphQL
//
//  Created by Jeff Seibert on 3/9/18.
//

import Foundation
import NIO
import Async

extension Dictionary where Value: FutureType {
    func flatten(on worker: EventLoopGroup) -> EventLoopFuture<[Key: Value.Expectation]> {
        var elements: [Key: Value.Expectation] = [:]

        guard self.count > 0 else {
            return worker.next().newSucceededFuture(result: elements)
        }

        let promise: EventLoopPromise<[Key: Value.Expectation]> = worker.next().newPromise()
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
