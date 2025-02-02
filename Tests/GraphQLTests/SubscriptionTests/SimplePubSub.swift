import GraphQL

/// A very simple publish/subscriber used for testing
@available(macOS 10.15, iOS 15, watchOS 8, tvOS 15, *)
class SimplePubSub<T> {
    private var subscribers: [Subscriber<T>]

    init() {
        subscribers = []
    }

    func emit(event: T) {
        for subscriber in subscribers {
            subscriber.callback(event)
        }
    }

    func cancel() {
        for subscriber in subscribers {
            subscriber.cancel()
        }
    }

    func subscribe() -> ConcurrentEventStream<T> {
        let asyncStream = AsyncThrowingStream<T, Error> { continuation in
            let subscriber = Subscriber<T>(
                callback: { newValue in
                    continuation.yield(newValue)
                },
                cancel: {
                    continuation.finish()
                }
            )
            subscribers.append(subscriber)
        }
        return ConcurrentEventStream<T>(asyncStream)
    }
}

struct Subscriber<T> {
    let callback: (T) -> Void
    let cancel: () -> Void
}
