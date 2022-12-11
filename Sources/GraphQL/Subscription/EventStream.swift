/// Abstract event stream class - Should be overridden for actual implementations
open class EventStream<Element> {
    public init() {}
    /// Template method for mapping an event stream to a new generic type - MUST be overridden by
    /// implementing types.
    open func map<To>(_: @escaping (Element) throws -> To) -> EventStream<To> {
        fatalError("This function should be overridden by implementing classes")
    }
}

#if compiler(>=5.5) && canImport(_Concurrency)

    @available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
    /// Event stream that wraps an `AsyncThrowingStream` from Swift's standard concurrency system.
    public class ConcurrentEventStream<Element>: EventStream<Element> {
        public let stream: AsyncThrowingStream<Element, Error>

        public init(_ stream: AsyncThrowingStream<Element, Error>) {
            self.stream = stream
        }

        /// Performs the closure on each event in the current stream and returns a stream of the
        /// results.
        /// - Parameter closure: The closure to apply to each event in the stream
        /// - Returns: A stream of the results
        override open func map<To>(_ closure: @escaping (Element) throws -> To)
            -> ConcurrentEventStream<To>
        {
            let newStream = stream.mapStream(closure)
            return ConcurrentEventStream<To>.init(newStream)
        }
    }

    @available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
    extension AsyncThrowingStream {
        func mapStream<To>(_ closure: @escaping (Element) throws -> To)
            -> AsyncThrowingStream<To, Error>
        {
            return AsyncThrowingStream<To, Error> { continuation in
                let task = Task {
                    do {
                        for try await event in self {
                            let newEvent = try closure(event)
                            continuation.yield(newEvent)
                        }
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }

                continuation.onTermination = { @Sendable reason in
                    task.cancel()
                }
            }
        }

        func filterStream(_ isIncluded: @escaping (Element) throws -> Bool)
            -> AsyncThrowingStream<Element, Error>
        {
            return AsyncThrowingStream<Element, Error> { continuation in
                let task = Task {
                    do {
                        for try await event in self {
                            if try isIncluded(event) {
                                continuation.yield(event)
                            }
                        }
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }

                continuation.onTermination = { @Sendable _ in
                    task.cancel()
                }
            }
        }
    }

#endif
