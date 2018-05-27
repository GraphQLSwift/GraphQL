//
//  Dictionary+FutureType.swift
//  GraphQL
//
//  Created by Kim de Vos on 26/05/2018.
//

import Foundation
import NIO

/// !! From Vapor Async start

/// Callback for accepting a result.
public typealias FutureResultCallback<T> = (FutureResult<T>) -> ()

/// A future result type.
/// Concretely implemented by `Future<T>`
public protocol FutureType {
    /// This future's expectation.
    associatedtype Expectation

    /// This future's result type.
    typealias Result = FutureResult<Expectation>

    /// Adds a new awaiter to this `Future` that will be called when the result is ready.
    func addAwaiter(callback: @escaping FutureResultCallback<Expectation>)
}

extension EventLoopFuture: FutureType {
    /// See `FutureType`.
    public typealias Expectation = T

    /// See `FutureType`.
    public func addAwaiter(callback: @escaping (FutureResult<T>) -> ()) {
        _ = self.map { result in
            callback(.success(result))
            }.mapIfError { error in
                callback(.error(error))
        }
    }
}

// Indirect so futures can be nested.
public indirect enum FutureResult<T> {
    case error(Error)
    case success(T)

    /// Returns the result error or `nil` if the result contains expectation.
    public var error: Error? {
        switch self {
        case .error(let error):
            return error
        default:
            return nil
        }
    }

    /// Returns the result expectation or `nil` if the result contains an error.
    public var result: T? {
        switch self {
        case .success(let expectation):
            return expectation
        default:
            return nil
        }
    }

    /// Throws an error if this contains an error, returns the Expectation otherwise
    public func unwrap() throws -> T {
        switch self {
        case .success(let data):
            return data
        case .error(let error):
            throw error
        }
    }
}

extension Collection where Element : FutureType {
    /// Flattens an array of futures into a future with an array of results.
    /// note: the order of the results will match the order of the
    /// futures in the input array.
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/async/advanced-futures/#combining-multiple-futures)
    public func flatten(on worker: EventLoopGroup) -> EventLoopFuture<[Element.Expectation]> {
        guard count > 0 else {
            return worker.next().newSucceededFuture(result: [])
        }
        var elements: [Element.Expectation] = []

        let promise: EventLoopPromise<[Element.Expectation]> = worker.next().newPromise()
        elements.reserveCapacity(self.count)

        for element in self {
            element.addAwaiter { result in
                switch result {
                case .error(let error): promise.fail(error: error)
                case .success(let expectation):
                    elements.append(expectation)

                    if elements.count == self.count {
                        promise.succeed(result: elements)
                    }
                }
            }
        }

        return promise.futureResult
    }
}

/// !! From Vapor Async end

extension Dictionary where Value: FutureType {
    func flatten(on worker: EventLoopGroup) -> EventLoopFuture<[Key: Value.Expectation]> {
        guard self.count > 0 else {
            return worker.next().newSucceededFuture(result: [:])
        }

        var elements: [Key: Value.Expectation] = [:]

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
