/// Abstract event stream class - Should be overridden for actual implementations
open class EventStream<Element> {
    public init() { }
    /// Template method for mapping an event stream to a new generic type - MUST be overridden by implementing types.
    open func map<To>(_ closure: @escaping (Element) throws -> To) -> EventStream<To> {
        fatalError("This function should be overridden by implementing classes")
    }
}
