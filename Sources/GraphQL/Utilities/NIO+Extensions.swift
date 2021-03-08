//
//  DictionaryFuture.swift
//  GraphQL
//
//  Created by Jeff Seibert on 3/9/18.
//

import Foundation
import NIO

public typealias Future = EventLoopFuture

extension Collection {
    public func flatten<T>(on eventLoopGroup: EventLoopGroup) -> Future<[T]> where Element == Future<T> {
        return Future.whenAllSucceed(Array(self), on: eventLoopGroup.next())
    }
}

extension Collection {
    internal func flatMap<S, T>(
        to type: T.Type,
        on eventLoopGroup: EventLoopGroup,
        _ callback: @escaping ([S]) throws -> Future<T>
    ) -> Future<T> where Element == Future<S> {
        return flatten(on: eventLoopGroup).flatMap(to: T.self, callback)
    }
}

extension Dictionary where Value : FutureType {
    func flatten(on eventLoopGroup: EventLoopGroup) -> Future<[Key: Value.Expectation]> {
        let queue = DispatchQueue(label: "org.graphQL.elementQueue")
        var elements: [Key: Value.Expectation] = [:]

        guard self.count > 0 else {
            return eventLoopGroup.next().makeSucceededFuture(elements)
        }

        let promise: EventLoopPromise<[Key: Value.Expectation]> = eventLoopGroup.next().makePromise()
        elements.reserveCapacity(self.count)

        for (key, value) in self {
            value.whenSuccess { expectation in
                // Control access to elements to avoid thread conflicts
                queue.async {
                    elements[key] = expectation
                    
                    if elements.count == self.count {
                        promise.succeed(elements)
                    }
                }
            }
            
            value.whenFailure { error in
                promise.fail(error)
            }
        }

        return promise.futureResult
    }
}
extension Future {
    internal func flatMap<T>(
        to type: T.Type = T.self,
        _ callback: @escaping (Expectation) throws -> Future<T>
    ) -> Future<T> {
        let promise = eventLoop.makePromise(of: T.self)
        
        self.whenSuccess { expectation in
            do {
                let mapped = try callback(expectation)
                mapped.cascade(to: promise)
            } catch {
                promise.fail(error)
            }
        }
            
        self.whenFailure { error in
            promise.fail(error)
        }
        
        return promise.futureResult
    }
}

public protocol FutureType {
    associatedtype Expectation
    func whenSuccess(_ callback: @escaping (Expectation) -> Void)
    func whenFailure(_ callback: @escaping (Error) -> Void)
}

extension Future : FutureType {
    public typealias Expectation = Value
}
