import Dispatch
import Foundation

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
        result: Result<Document, GraphQLError>
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
        info: GraphQLResolveInfo,
        result: Result<Any?, Error>
    )
}

public extension Instrumentation {
    var now: DispatchTime {
        return DispatchTime.now()
    }
}

func threadId() -> Int {
    #if os(Linux) || os(Android)
        return Int(pthread_self())
    #else
        return Int(pthread_mach_thread_np(pthread_self()))
    #endif
}

func processId() -> Int {
    return Int(getpid())
}

/// Does nothing
public let NoOpInstrumentation: Instrumentation = noOpInstrumentation()

struct noOpInstrumentation: Instrumentation {
    public let now = DispatchTime(uptimeNanoseconds: 0)
    public func queryParsing(
        processId _: Int,
        threadId _: Int,
        started _: DispatchTime,
        finished _: DispatchTime,
        source _: Source,
        result _: Result<Document, GraphQLError>
    ) {}

    public func queryValidation(
        processId _: Int,
        threadId _: Int,
        started _: DispatchTime,
        finished _: DispatchTime,
        schema _: GraphQLSchema,
        document _: Document,
        errors _: [GraphQLError]
    ) {}

    public func operationExecution(
        processId _: Int,
        threadId _: Int,
        started _: DispatchTime,
        finished _: DispatchTime,
        schema _: GraphQLSchema,
        document _: Document,
        rootValue _: Any,
        variableValues _: [String: Map],
        operation _: OperationDefinition?,
        errors _: [GraphQLError],
        result _: Map
    ) {}

    public func fieldResolution(
        processId _: Int,
        threadId _: Int,
        started _: DispatchTime,
        finished _: DispatchTime,
        source _: Any,
        args _: Map,
        info _: GraphQLResolveInfo,
        result _: Result<Any?, Error>
    ) {}
}
