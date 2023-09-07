import Dispatch
import Foundation
import GraphQL
import NIO
import XCTest

class InstrumentationTests: XCTestCase, Instrumentation {
    class MyRoot {}
    class MyCtx {}

    var query = "query sayHello($name: String) { hello(name: $name) }"
    var expectedResult: Map = [
        "data": [
            "hello": "bob",
        ],
    ]
    var expectedThreadId = 0
    var expectedProcessId = 0
    var expectedRoot = MyRoot()
    var expectedCtx = MyCtx()
    var expectedOpVars: [String: Map] = ["name": "bob"]
    var expectedOpName = "sayHello"
    var queryParsingCalled = 0
    var queryValidationCalled = 0
    var operationExecutionCalled = 0
    var fieldResolutionCalled = 0

    let schema = try! GraphQLSchema(
        query: GraphQLObjectType(
            name: "RootQueryType",
            fields: [
                "hello": GraphQLField(
                    type: GraphQLString,
                    args: [
                        "name": GraphQLArgument(type: GraphQLNonNull(GraphQLString)),
                    ],
                    resolve: { inputValue, _, _, _ in
                        print(type(of: inputValue))
                        return nil
                    }
//                    resolve: { _, args, _, _ in return try! args["name"].asString() }
                ),
            ]
        )
    )

    override func setUp() {
        expectedThreadId = 0
        expectedProcessId = 0
        queryParsingCalled = 0
        queryValidationCalled = 0
        operationExecutionCalled = 0
        fieldResolutionCalled = 0
    }

    func queryParsing(
        processId _: Int,
        threadId _: Int,
        started _: DispatchTime,
        finished _: DispatchTime,
        source _: Source,
        result _: Result<Document, GraphQLError>
    ) {
//        queryParsingCalled += 1
//        XCTAssertEqual(processId, expectedProcessId, "unexpected process id")
//        XCTAssertEqual(threadId, expectedThreadId, "unexpected thread id")
//        XCTAssertGreaterThan(finished, started)
//        XCTAssertEqual(source.name, "GraphQL request")
//        switch result {
//        case .error(let e):
//            XCTFail("unexpected error \(e)")
//        case .result(let document):
//            XCTAssertEqual(document.loc!.source.name, source.name)
//        }
//        XCTAssertEqual(source.name, "GraphQL request")
    }

    func queryValidation(
        processId _: Int,
        threadId _: Int,
        started _: DispatchTime,
        finished _: DispatchTime,
        schema _: GraphQLSchema,
        document _: Document,
        errors _: [GraphQLError]
    ) {
        queryValidationCalled += 1
//        XCTAssertEqual(processId, expectedProcessId, "unexpected process id")
//        XCTAssertEqual(threadId, expectedThreadId, "unexpected thread id")
//        XCTAssertGreaterThan(finished, started)
//        XCTAssertTrue(schema === self.schema)
//        XCTAssertEqual(document.loc!.source.name, "GraphQL request")
//        XCTAssertEqual(errors, [])
    }

    func operationExecution(
        processId _: Int,
        threadId _: Int,
        started _: DispatchTime,
        finished _: DispatchTime,
        schema _: GraphQLSchema,
        document _: Document,
        rootValue _: Any,
        eventLoopGroup _: EventLoopGroup,
        variableValues _: [String: Map],
        operation _: OperationDefinition?,
        errors _: [GraphQLError],
        result _: Map
    ) {
//        operationExecutionCalled += 1
//        XCTAssertEqual(processId, expectedProcessId, "unexpected process id")
//        XCTAssertEqual(threadId, expectedThreadId, "unexpected thread id")
//        XCTAssertGreaterThan(finished, started)
//        XCTAssertTrue(schema === self.schema)
//        XCTAssertEqual(document.loc?.source.name ?? "", "GraphQL request")
//        XCTAssertTrue(rootValue as! MyRoot === expectedRoot)
//        XCTAssertTrue(contextValue as! MyCtx === expectedCtx)
//        XCTAssertEqual(variableValues, expectedOpVars)
//        XCTAssertEqual(operation!.name!.value, expectedOpName)
//        XCTAssertEqual(errors, [])
//        XCTAssertEqual(result, expectedResult)
    }

    func fieldResolution(
        processId _: Int,
        threadId _: Int,
        started _: DispatchTime,
        finished _: DispatchTime,
        source _: Any,
        args _: Map,
        eventLoopGroup _: EventLoopGroup,
        info _: GraphQLResolveInfo,
        result _: Result<Future<Any?>, Error>
    ) {
        fieldResolutionCalled += 1
//        XCTAssertEqual(processId, expectedProcessId, "unexpected process id")
//        XCTAssertEqual(threadId, expectedThreadId, "unexpected thread id")
//        XCTAssertGreaterThan(finished, started)
//        XCTAssertTrue(source as! MyRoot === expectedRoot)
//        XCTAssertEqual(args, try! expectedOpVars.asMap())
//        XCTAssertTrue(context as! MyCtx === expectedCtx)
//        switch result {
//        case .error(let e):
//            XCTFail("unexpected error \(e)")
//        case .result(let r):
//            XCTAssertEqual(r as! String, try! expectedResult["data"]["hello"].asString())
//        }
    }

    func testInstrumentationCalls() throws {
//        #if os(Linux)
//        expectedThreadId = Int(pthread_self())
//        #else
//        expectedThreadId = Int(pthread_mach_thread_np(pthread_self()))
//        #endif
//        expectedProcessId = Int(getpid())
//        let result = try graphql(
//            instrumentation: self,
//            schema: schema,
//            request: query,
//            rootValue: expectedRoot,
//            contextValue: expectedCtx,
//            variableValues: expectedOpVars,
//            operationName: expectedOpName
//        )
//        XCTAssertEqual(result, expectedResult)
//        XCTAssertEqual(queryParsingCalled, 1)
//        XCTAssertEqual(queryValidationCalled, 1)
//        XCTAssertEqual(operationExecutionCalled, 1)
//        XCTAssertEqual(fieldResolutionCalled, 1)
    }

    func testDispatchQueueInstrumentationWrapper() throws {
//        let dispatchGroup = DispatchGroup()
//        #if os(Linux)
//        expectedThreadId = Int(pthread_self())
//        #else
//        expectedThreadId = Int(pthread_mach_thread_np(pthread_self()))
//        #endif
//        expectedProcessId = Int(getpid())
//        let result = try graphql(
//            instrumentation: DispatchQueueInstrumentationWrapper(self, dispatchGroup: dispatchGroup),
//            schema: schema,
//            request: query,
//            rootValue: expectedRoot,
//            contextValue: expectedCtx,
//            variableValues: expectedOpVars,
//            operationName: expectedOpName
//        )
//        dispatchGroup.wait()
//        XCTAssertEqual(result, expectedResult)
//        XCTAssertEqual(queryParsingCalled, 1)
//        XCTAssertEqual(queryValidationCalled, 1)
//        XCTAssertEqual(operationExecutionCalled, 1)
//        XCTAssertEqual(fieldResolutionCalled, 1)
    }
}
