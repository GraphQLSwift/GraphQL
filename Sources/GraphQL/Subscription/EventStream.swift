// Copyright (c) 2021 PassiveLogic, Inc.

import RxSwift

/// Abstract event stream class - Should be overridden for actual implementations
open class EventStream<Element> {
    public init() { }
    /// Template method for mapping an event stream to a new generic type - MUST be overridden by implementing types.
    open func map<To>(_ closure: @escaping (Element) throws -> To) -> EventStream<To> {
        fatalError("This function should be overridden by implementing classes")
    }
}


// TODO: Put in separate GraphQLRxSwift package

// EventStream wrapper for Observable
public class ObservableEventStream<Element> : EventStream<Element> {
    public var observable: Observable<Element>
    init(_ observable: Observable<Element>) {
        self.observable = observable
    }
    override open func map<To>(_ closure: @escaping (Element) throws -> To) -> EventStream<To> {
        return ObservableEventStream<To>(observable.map(closure))
    }
}
// Convenience types
public typealias ObservableSourceEventStream = ObservableEventStream<Future<Any>>
public typealias ObservableSubscriptionEventStream = ObservableEventStream<Future<GraphQLResult>>

extension Observable {
    // Convenience method for wrapping Observables in EventStreams
    public func toEventStream() -> ObservableEventStream<Element> {
        return ObservableEventStream(self)
    }
}


// TODO: Delete notes below

// Protocol attempts

//protocol EventStreamP {
//    associatedtype Element
//    func transform<To>(_ closure: @escaping (Element) throws -> To) -> EventStreamP // How to specify that returned associated type is 'To'
//}
//extension Observable: EventStreamP {
//    func transform<To>(_ closure: @escaping (Element) throws -> To) -> EventStreamP {
//        return self.map(closure)
//    }
//}

// Try defining element in closure return
//protocol EventStreamP {
//    associatedtype Element
//    func transform<ResultStream: EventStreamP>(_ closure: @escaping (Element) throws -> ResultStream.Element) -> ResultStream
//}
//extension Observable: EventStreamP {
//    func transform<ResultStream: EventStreamP>(_ closure: @escaping (Element) throws -> ResultStream.Element) -> ResultStream {
//        return self.map(closure) // Observable<ResultStream.Element> isn't recognized as a ResultStream
//    }
//}

// Try absorbing generic type into function
//protocol EventStreamP {
//    func transform<From, To>(_ closure: @escaping (From) throws -> To) -> EventStreamP
//}
//extension Observable: EventStreamP {
//    func transform<From, To>(_ closure: @escaping (From) throws -> To) -> EventStreamP {
//        return self.map(closure) // Doesn't recognize that Observable.Element is the same as From
//    }
//}

// Try opaque types
//protocol EventStreamP {
//    associatedtype Element
//    func transform<To>(_ closure: @escaping (Element) throws -> To) -> some EventStreamP
//}
//extension Observable: EventStreamP {
//    func transform<To>(_ closure: @escaping (Element) throws -> To) -> some EventStreamP {
//        return self.map(closure)
//    }
//}
