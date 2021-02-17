import NIO

class SimplePubSub<T> {
    let subscribers:[SimplePubSubSubscriber<T>] = []

    public func emit(event:T) -> Bool {
        for subscriber in subscribers {
            subscriber.process(event: event)
        }
        return subscribers.count > 0
    }

    public func getSubscriber() -> SimplePubSubSubscriber<T> {
        return SimplePubSubSubscriber()
    }
}

class SimplePubSubSubscriber<T> {
    var pullQueue:[EventLoopFuture<String>] = []
    var pushQueue:[EventLoopFuture<String>] = []
    var listening = true
    
    func process(event:T) {
        
    }
    
    
    func emptyQueue() {
        listening = false
//        subscribers.delete(pushValue) // TODO How do we remove this subscriber from the list??
//        for future in pullQueue { // TODO How can we short-circuit the futures in pullQueue
//            future.["value":"undefined", "done":"true"])
//        }
        pullQueue.removeAll()
        pushQueue.removeAll()
    }
}

class SimplePubSubAsyncIterable : AsyncIterable {
    let eventLoopGroup:EventLoopGroup
    
    var pullQueue:[EventLoopFuture<String>] = []
    var pushQueue:[EventLoopFuture<String>] = []
    var listening = true
    
    init() {
        self.eventLoopGroup = MultiThreadedEventLoopGroup.init(numberOfThreads: 1)
    }
    
    func next() -> EventLoopFuture<[String:String]> {
        if !listening {
            return eventLoopGroup.next().submit {
                return ["value":"undefined", "done":"true"]
            }
        } else if pushQueue.count > 0 {
            return eventLoopGroup.next().submit {
                return ["value": try! self.pushQueue.removeFirst().wait(), "done":"false"]
            }
        }
//        else { // TODO Figure out why pushQueue is used as a value, but pullQueue is used as a map...
//            return pullQueue.last!
//        }
        return eventLoopGroup.next().submit { // TODO PLACEHOLDER
            return ["value":"PLACEHOLDER", "done":"false"]
        }
    }
}
