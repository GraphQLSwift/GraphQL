import Dispatch
import NIO

/// Proxies calls through to another `Instrumentation` instance via a DispatchQueue
///
/// Has two primary use cases:
/// 1. Allows a non thread safe Instrumentation implementation to be used along side a multithreaded execution strategy
/// 2. Allows slow or heavy instrumentation processing to happen outside of the current query execution
public class DispatchQueueInstrumentationWrapper: Instrumentation {

    let instrumentation:Instrumentation
    let dispatchQueue: DispatchQueue
    let dispatchGroup: DispatchGroup?

    public init(_ instrumentation: Instrumentation, label: String = "GraphQL instrumentation wrapper", qos: DispatchQoS = .utility, attributes: DispatchQueue.Attributes = [], dispatchGroup: DispatchGroup? = nil ) {
        self.instrumentation = instrumentation
        self.dispatchQueue = DispatchQueue(label: label, qos: qos, attributes: attributes)
        self.dispatchGroup = dispatchGroup
    }

    public init(_ instrumentation: Instrumentation, dispatchQueue: DispatchQueue, dispatchGroup: DispatchGroup? = nil ) {
        self.instrumentation = instrumentation
        self.dispatchQueue = dispatchQueue
        self.dispatchGroup = dispatchGroup
    }

    public var now: DispatchTime {
        return instrumentation.now
    }

    public func queryParsing(processId: Int, threadId: Int, started: DispatchTime, finished: DispatchTime, source: Source, result: ResultOrError<Document, GraphQLError>) {
        dispatchQueue.async(group: dispatchGroup) {
            self.instrumentation.queryParsing(processId: processId, threadId: threadId, started: started, finished: finished, source: source, result: result)
        }
    }

    public func queryValidation(processId: Int, threadId: Int, started: DispatchTime, finished: DispatchTime, schema: GraphQLSchema, document: Document, errors: [GraphQLError]) {
        dispatchQueue.async(group: dispatchGroup) {
            self.instrumentation.queryValidation(processId: processId, threadId: threadId, started: started, finished: finished, schema: schema, document: document, errors: errors)
        }
    }

    public func operationExecution(processId: Int, threadId: Int, started: DispatchTime, finished: DispatchTime, schema: GraphQLSchema, document: Document, rootValue: Any, eventLoopGroup: EventLoopGroup, variableValues: [String : Map], operation: OperationDefinition?, errors: [GraphQLError], result: Map) {
        dispatchQueue.async(group: dispatchGroup) {
            self.instrumentation.operationExecution(processId: processId, threadId: threadId, started: started, finished: finished, schema: schema, document: document, rootValue: rootValue, eventLoopGroup: eventLoopGroup, variableValues: variableValues, operation: operation, errors: errors, result: result)
        }
    }

    public func fieldResolution(processId: Int, threadId: Int, started: DispatchTime, finished: DispatchTime, source: Any, args: Map, eventLoopGroup: EventLoopGroup, info: GraphQLResolveInfo, result: ResultOrError<EventLoopFuture<Any?>, Error>) {
        dispatchQueue.async(group: dispatchGroup) {
            self.instrumentation.fieldResolution(processId: processId, threadId: threadId, started: started, finished: finished, source: source, args: args, eventLoopGroup: eventLoopGroup, info: info, result: result)
        }
    }

}

