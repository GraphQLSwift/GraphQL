import Foundation
import Dispatch
import NIO

/// Provides the capability to instrument the execution steps of a GraphQL query.
///
/// A working implementation of `now` is also provided by default.
public protocol Instrumentation {

    var now: DispatchTime { get }

    func queryParsing(
        processId: Int,
        threadId: Int,
        started: DispatchTime,
        finished: DispatchTime,
        source: Source,
        result: ResultOrError<Document, GraphQLError>
    )

    func queryValidation(
        processId: Int,
        threadId: Int,
        started: DispatchTime,
        finished: DispatchTime,
        schema: GraphQLSchema,
        document: Document,
        errors: [GraphQLError]
    )

    func operationExecution(
        processId: Int,
        threadId: Int,
        started: DispatchTime,
        finished: DispatchTime,
        schema: GraphQLSchema,
        document: Document,
        rootValue: Any,
        eventLoopGroup: EventLoopGroup,
        variableValues: [String: Map],
        operation: OperationDefinition?,
        errors: [GraphQLError],
        result: Map
    )

    func fieldResolution(
        processId: Int,
        threadId: Int,
        started: DispatchTime,
        finished: DispatchTime,
        source: Any,
        args: Map,
        eventLoopGroup: EventLoopGroup,
        info: GraphQLResolveInfo,
        result: ResultOrError<EventLoopFuture<Any?>, Error>
    )

}

extension Instrumentation {
    public var now: DispatchTime {
        return DispatchTime.now()
    }
}

func threadId() -> Int {
    #if os(Linux)
        return Int(pthread_self())
    #else
        return Int(pthread_mach_thread_np(pthread_self()))
    #endif
}

func processId() -> Int {
    return Int(getpid())
}

/// Does nothing
public let NoOpInstrumentation:Instrumentation = noOpInstrumentation()

struct noOpInstrumentation: Instrumentation {
    public let now = DispatchTime(uptimeNanoseconds: 0)
    public func queryParsing(processId: Int, threadId: Int, started: DispatchTime, finished: DispatchTime, source: Source, result: ResultOrError<Document, GraphQLError>) {
    }
    public func queryValidation(processId: Int, threadId: Int, started: DispatchTime, finished: DispatchTime, schema: GraphQLSchema, document: Document, errors: [GraphQLError]) {
    }
    public func operationExecution(processId: Int, threadId: Int, started: DispatchTime, finished: DispatchTime, schema: GraphQLSchema, document: Document, rootValue: Any, eventLoopGroup: EventLoopGroup, variableValues: [String : Map], operation: OperationDefinition?, errors: [GraphQLError], result: Map) {
    }
    public func fieldResolution(processId: Int, threadId: Int, started: DispatchTime, finished: DispatchTime, source: Any, args: Map, eventLoopGroup: EventLoopGroup, info: GraphQLResolveInfo, result: ResultOrError<EventLoopFuture<Any?>, Error>) {
    }
}
