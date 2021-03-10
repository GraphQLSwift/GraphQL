// Copyright (c) 2021 PassiveLogic, Inc.

import RxSwift

public class EventStream<Element> {
    /// This class should be overridden
    func transform<To>(_ closure: @escaping (Element) throws -> To) -> EventStream<To> {
        fatalError("This function should be overridden by implementing classes")
    }
}

//extension Observable: EventStream<Element> {
//    func transform<To>(_ closure: @escaping (Element) throws -> To) -> EventStream<To> {
//        return self.map(closure)
//    }
//}

public class ObservableEventStream<Element> : EventStream<Element> {
    var observable: Observable<Element>
    init(observable: Observable<Element>) {
        self.observable = observable
    }
    override func transform<To>(_ closure: @escaping (Element) throws -> To) -> EventStream<To> {
        return ObservableEventStream<To>(observable: observable.map(closure))
    }
}
