//
//  DictionaryFuture.swift
//  GraphQL
//
//  Created by Jeff Seibert on 3/9/18.
//

import Foundation
import NIO
import OrderedCollections

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
        // create array of futures with (key,value) tuple
        let futures: [Future<(Key, Value.Expectation)>] = self.map { element in
            element.value.map(file: #file, line: #line) { (key: element.key, value: $0) }
        }
        // when all futures have succeeded convert tuple array back to dictionary
        return EventLoopFuture.whenAllSucceed(futures, on: eventLoopGroup.next()).map {
            .init(uniqueKeysWithValues: $0)
        }
    }
}

extension OrderedDictionary where Value : FutureType {
    func flatten(on eventLoopGroup: EventLoopGroup) -> Future<OrderedDictionary<Key, Value.Expectation>> {
        let keys = self.keys
        // create array of futures with (key,value) tuple
        let futures: [Future<(Key, Value.Expectation)>] = self.map { element in
            element.value.map(file: #file, line: #line) { (key: element.key, value: $0) }
        }
        // when all futures have succeeded convert tuple array back to dictionary
        return EventLoopFuture.whenAllSucceed(futures, on: eventLoopGroup.next()).map { unorderedResult in
            var result: OrderedDictionary<Key, Value.Expectation> = [:]
            for key in keys {
                result[key] = unorderedResult.first(where: { $0.0 == key })!.1
            }
            return result
        }
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
    func map<NewValue>(file: StaticString, line: UInt, _ callback: @escaping (Expectation) -> (NewValue)) -> EventLoopFuture<NewValue>
}

extension Future : FutureType {
    public typealias Expectation = Value
}
