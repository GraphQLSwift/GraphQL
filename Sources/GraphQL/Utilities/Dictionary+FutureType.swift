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
        self.do { result in
            callback(.success(result))
            }.catch { error in
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

/// !! From Vapor Async end

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
