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
    public func flatten<T>(on worker: EventLoopGroup) -> Future<[T]> where Element == Future<T> {
        return Future.whenAll(Array(self), eventLoop: worker.next())
    }
}

extension Collection {
    public func flatMap<S, T>(
        to type: T.Type,
        on worker: EventLoopGroup,
        _ callback: @escaping ([S]) throws -> Future<T>
    ) -> Future<T> where Element == Future<S> {
        return flatten(on: worker).flatMap(to: T.self, callback)
    }
}

extension Dictionary where Value : FutureType {
    func flatten(on worker: EventLoopGroup) -> Future<[Key: Value.Expectation]> {
        var elements: [Key: Value.Expectation] = [:]

        guard self.count > 0 else {
            return worker.next().newSucceededFuture(result: elements)
        }

        let promise: EventLoopPromise<[Key: Value.Expectation]> = worker.next().newPromise()
        elements.reserveCapacity(self.count)

        for (key, value) in self {
            value.whenSuccess { expectation in
                elements[key] = expectation
                
                if elements.count == self.count {
                    promise.succeed(result: elements)
                }
            }
            
            value.whenFailure { error in
                promise.fail(error: error)
            }
        }

        return promise.futureResult
    }
}
extension Future {
    public func flatMap<T>(
        to type: T.Type = T.self,
        _ callback: @escaping (Expectation) throws -> Future<T>
    ) -> Future<T> {
        let promise = eventLoop.newPromise(of: T.self)
        
        self.whenSuccess { expectation in
            do {
                let mapped = try callback(expectation)
                mapped.cascade(promise: promise)
            } catch {
                promise.fail(error: error)
            }
        }
            
        self.whenFailure { error in
            promise.fail(error: error)
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
    public typealias Expectation = T
    
}
