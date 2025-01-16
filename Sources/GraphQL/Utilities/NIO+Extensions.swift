//
//  NIO+Extensions.swift
//  GraphQL
//
//  Created by Jeff Seibert on 3/9/18.
//

import Foundation
import NIO
import OrderedCollections

public typealias Future = EventLoopFuture

public extension Collection {
    func flatten<T>(on eventLoopGroup: EventLoopGroup) -> Future<[T]> where Element == Future<T> {
        return Future.whenAllSucceed(Array(self), on: eventLoopGroup.next())
    }
}

extension Collection {
    func flatMap<S, T>(
        to _: T.Type,
        on eventLoopGroup: EventLoopGroup,
        _ callback: @escaping ([S]) throws -> Future<T>
    ) -> Future<T> where Element == Future<S> {
        return flatten(on: eventLoopGroup).flatMap(to: T.self, callback)
    }
}

extension Dictionary where Value: FutureType {
    func flatten(on eventLoopGroup: EventLoopGroup) -> Future<[Key: Value.Expectation]> {
        // create array of futures with (key,value) tuple
        let futures: [Future<(Key, Value.Expectation)>] = map { element in
            element.value.map(file: #file, line: #line) { (key: element.key, value: $0) }
        }
        // when all futures have succeeded convert tuple array back to dictionary
        return EventLoopFuture.whenAllSucceed(futures, on: eventLoopGroup.next()).map {
            .init(uniqueKeysWithValues: $0)
        }
    }
}

extension OrderedDictionary where Value: FutureType {
    func flatten(on eventLoopGroup: EventLoopGroup)
        -> Future<OrderedDictionary<Key, Value.Expectation>>
    {
        let keys = self.keys
        // create array of futures with (key,value) tuple
        let futures: [Future<(Key, Value.Expectation)>] = map { element in
            element.value.map(file: #file, line: #line) { (key: element.key, value: $0) }
        }
        // when all futures have succeeded convert tuple array back to dictionary
        return EventLoopFuture.whenAllSucceed(futures, on: eventLoopGroup.next())
            .map { unorderedResult in
                var result: OrderedDictionary<Key, Value.Expectation> = [:]
                for key in keys {
                    // Unwrap is guaranteed because keys are from original dictionary and maps
                    // preserve all elements
                    result[key] = unorderedResult.first(where: { $0.0 == key })!.1
                }
                return result
            }
    }
}

extension Future {
    func flatMap<T>(
        to _: T.Type = T.self,
        _ callback: @escaping (Expectation) throws -> Future<T>
    ) -> Future<T> {
        let promise = eventLoop.makePromise(of: T.self)

        whenSuccess { expectation in
            do {
                let mapped = try callback(expectation)
                mapped.cascade(to: promise)
            } catch {
                promise.fail(error)
            }
        }

        whenFailure { error in
            promise.fail(error)
        }

        return promise.futureResult
    }
}

public protocol FutureType {
    associatedtype Expectation
    func whenSuccess(_ callback: @escaping @Sendable (Expectation) -> Void)
    func whenFailure(_ callback: @escaping @Sendable (Error) -> Void)
    func map<NewValue>(
        file: StaticString,
        line: UInt,
        _ callback: @escaping (Expectation) -> (NewValue)
    ) -> EventLoopFuture<NewValue>
}

extension Future: FutureType {
    public typealias Expectation = Value
}

// Copied from https://github.com/vapor/async-kit/blob/e2f741640364c1d271405da637029ea6a33f754e/Sources/AsyncKit/EventLoopFuture/Future%2BTry.swift
// in order to avoid full package dependency.
public extension EventLoopFuture {
    func tryFlatMap<NewValue>(
        file _: StaticString = #file, line _: UInt = #line,
        _ callback: @escaping (Value) throws -> EventLoopFuture<NewValue>
    ) -> EventLoopFuture<NewValue> {
        /// When the current `EventLoopFuture<Value>` is fulfilled, run the provided callback,
        /// which will provide a new `EventLoopFuture`.
        ///
        /// This allows you to dynamically dispatch new asynchronous tasks as phases in a
        /// longer series of processing steps. Note that you can use the results of the
        /// current `EventLoopFuture<Value>` when determining how to dispatch the next operation.
        ///
        /// The key difference between this method and the regular `flatMap` is  error handling.
        ///
        /// With `tryFlatMap`, the provided callback _may_ throw Errors, causing the returned
        /// `EventLoopFuture<Value>`
        /// to report failure immediately after the completion of the original `EventLoopFuture`.
        flatMap { [eventLoop] value in
            do {
                return try callback(value)
            } catch {
                return eventLoop.makeFailedFuture(error)
            }
        }
    }
}
