import Dispatch
@testable import GraphQL
import NIO
import XCTest

class FieldExecutionStrategyTests: XCTestCase {
    enum StrategyError: Error {
        case exampleError(msg: String)
    }

    let schema = try! GraphQLSchema(
        query: GraphQLObjectType(
            name: "RootQueryType",
            fields: [
                "sleep": GraphQLField(
                    type: GraphQLString,
                    resolve: { _, _, _, eventLoopGroup, _ in
                        eventLoopGroup.next().makeSucceededVoidFuture().map {
                            Thread.sleep(forTimeInterval: 0.1)
                            return "z"
                        }
                    }
                ),
                "bang": GraphQLField(
                    type: GraphQLString,
                    resolve: { (_, _, _, _, info: GraphQLResolveInfo) in
                        let group = DispatchGroup()
                        group.enter()

                        DispatchQueue.global().asyncAfter(wallDeadline: .now() + 0.1) {
                            group.leave()
                        }

                        group.wait()

                        throw StrategyError.exampleError(
                            msg: "\(info.fieldName): \(info.path.elements.last!)"
                        )
                    }
                ),
                "futureBang": GraphQLField(
                    type: GraphQLString,
                    resolve: { (_, _, _, eventLoopGroup, info: GraphQLResolveInfo) in
                        let g = DispatchGroup()
                        g.enter()

                        DispatchQueue.global().asyncAfter(wallDeadline: .now() + 0.1) {
                            g.leave()
                        }

                        g.wait()

                        return eventLoopGroup.next().makeFailedFuture(StrategyError.exampleError(
                            msg: "\(info.fieldName): \(info.path.elements.last!)"
                        ))
                    }
                ),
            ]
        )
    )

    let singleQuery = "{ sleep }"

    let singleExpected = GraphQLResult(
        data: [
            "sleep": "z",
        ]
    )

    let multiQuery =
        "{ a: sleep b: sleep c: sleep d: sleep e: sleep f: sleep g: sleep h: sleep i: sleep j: sleep }"

    let multiExpected = GraphQLResult(
        data: [
            "a": "z",
            "b": "z",
            "c": "z",
            "d": "z",
            "e": "z",
            "f": "z",
            "g": "z",
            "h": "z",
            "i": "z",
            "j": "z",
        ]
    )

    let singleThrowsQuery = "{ bang }"

    let singleThrowsExpected = GraphQLResult(
        data: [
            "bang": nil,
        ],
        errors: [
            GraphQLError(
                message: "exampleError(msg: \"bang: bang\")",
                locations: [SourceLocation(line: 1, column: 3)],
                path: ["bang"]
            ),
        ]
    )

    let singleFailedFutureQuery = "{ futureBang }"

    let singleFailedFutureExpected = GraphQLResult(
        data: [
            "futureBang": nil,
        ],
        errors: [
            GraphQLError(
                message: "exampleError(msg: \"futureBang: futureBang\")",
                locations: [SourceLocation(line: 1, column: 3)],
                path: ["futureBang"]
            ),
        ]
    )

    let multiThrowsQuery =
        "{ a: bang b: bang c: bang d: bang e: bang f: bang g: bang h: bang i: bang j: futureBang }"

    let multiThrowsExpectedData: Map = [
        "a": nil,
        "b": nil,
        "c": nil,
        "d": nil,
        "e": nil,
        "f": nil,
        "g": nil,
        "h": nil,
        "i": nil,
        "j": nil,
    ]

    let multiThrowsExpectedErrors: [GraphQLError] = [
        GraphQLError(
            message: "exampleError(msg: \"bang: a\")",
            locations: [SourceLocation(line: 1, column: 3)],
            path: ["a"]
        ),
        GraphQLError(
            message: "exampleError(msg: \"bang: b\")",
            locations: [SourceLocation(line: 1, column: 11)],
            path: ["b"]
        ),
        GraphQLError(
            message: "exampleError(msg: \"bang: c\")",
            locations: [SourceLocation(line: 1, column: 19)],
            path: ["c"]
        ),
        GraphQLError(
            message: "exampleError(msg: \"bang: d\")",
            locations: [SourceLocation(line: 1, column: 27)],
            path: ["d"]
        ),
        GraphQLError(
            message: "exampleError(msg: \"bang: e\")",
            locations: [SourceLocation(line: 1, column: 35)],
            path: ["e"]
        ),
        GraphQLError(
            message: "exampleError(msg: \"bang: f\")",
            locations: [SourceLocation(line: 1, column: 43)],
            path: ["f"]
        ),
        GraphQLError(
            message: "exampleError(msg: \"bang: g\")",
            locations: [SourceLocation(line: 1, column: 51)],
            path: ["g"]
        ),
        GraphQLError(
            message: "exampleError(msg: \"bang: h\")",
            locations: [SourceLocation(line: 1, column: 59)],
            path: ["h"]
        ),
        GraphQLError(
            message: "exampleError(msg: \"bang: i\")",
            locations: [SourceLocation(line: 1, column: 67)],
            path: ["i"]
        ),
        GraphQLError(
            message: "exampleError(msg: \"futureBang: j\")",
            locations: [SourceLocation(line: 1, column: 75)],
            path: ["j"]
        ),
    ]

    func timing<T>(_ block: @autoclosure () throws -> T) throws -> (value: T, seconds: Double) {
        let start = DispatchTime.now()
        let value = try block()
        let nanoseconds = DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds
        let seconds = Double(nanoseconds) / 1_000_000_000
        return (
            value: value,
            seconds: seconds
        )
    }

    private var eventLoopGroup: EventLoopGroup!

    override func setUp() {
        eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    }

    override func tearDown() {
        XCTAssertNoThrow(try eventLoopGroup.syncShutdownGracefully())
    }

    func testSerialFieldExecutionStrategyWithSingleField() throws {
        let result = try timing(graphql(
            queryStrategy: SerialFieldExecutionStrategy(),
            schema: schema,
            request: singleQuery,
            eventLoopGroup: eventLoopGroup
        ).wait())
        XCTAssertEqual(result.value, singleExpected)
        // XCTAssertEqualWithAccuracy(0.1, result.seconds, accuracy: 0.25)
    }

    func testSerialFieldExecutionStrategyWithSingleFieldError() throws {
        let result = try timing(graphql(
            queryStrategy: SerialFieldExecutionStrategy(),
            schema: schema,
            request: singleThrowsQuery,
            eventLoopGroup: eventLoopGroup
        ).wait())
        XCTAssertEqual(result.value, singleThrowsExpected)
        // XCTAssertEqualWithAccuracy(0.1, result.seconds, accuracy: 0.25)
    }

    func testSerialFieldExecutionStrategyWithSingleFieldFailedFuture() throws {
        let result = try timing(graphql(
            queryStrategy: SerialFieldExecutionStrategy(),
            schema: schema,
            request: singleFailedFutureQuery,
            eventLoopGroup: eventLoopGroup
        ).wait())
        XCTAssertEqual(result.value, singleFailedFutureExpected)
        // XCTAssertEqualWithAccuracy(0.1, result.seconds, accuracy: 0.25)
    }

    func testSerialFieldExecutionStrategyWithMultipleFields() throws {
        let result = try timing(graphql(
            queryStrategy: SerialFieldExecutionStrategy(),
            schema: schema,
            request: multiQuery,
            eventLoopGroup: eventLoopGroup
        ).wait())
        XCTAssertEqual(result.value, multiExpected)
//        XCTAssertEqualWithAccuracy(1.0, result.seconds, accuracy: 0.5)
    }

    func testSerialFieldExecutionStrategyWithMultipleFieldErrors() throws {
        let result = try timing(graphql(
            queryStrategy: SerialFieldExecutionStrategy(),
            schema: schema,
            request: multiThrowsQuery,
            eventLoopGroup: eventLoopGroup
        ).wait())
        XCTAssertEqual(result.value.data, multiThrowsExpectedData)
        let resultErrors = result.value.errors
        XCTAssertEqual(resultErrors.count, multiThrowsExpectedErrors.count)
        multiThrowsExpectedErrors.forEach { m in
            XCTAssertTrue(resultErrors.contains(m), "Expecting result errors to contain \(m)")
        }
        // XCTAssertEqualWithAccuracy(1.0, result.seconds, accuracy: 0.5)
    }

    func testConcurrentDispatchFieldExecutionStrategyWithSingleField() throws {
        let result = try timing(graphql(
            queryStrategy: ConcurrentDispatchFieldExecutionStrategy(),
            schema: schema,
            request: singleQuery,
            eventLoopGroup: eventLoopGroup
        ).wait())
        XCTAssertEqual(result.value, singleExpected)
        // XCTAssertEqualWithAccuracy(0.1, result.seconds, accuracy: 0.25)
    }

    func testConcurrentDispatchFieldExecutionStrategyWithSingleFieldError() throws {
        let result = try timing(graphql(
            queryStrategy: ConcurrentDispatchFieldExecutionStrategy(),
            schema: schema,
            request: singleThrowsQuery,
            eventLoopGroup: eventLoopGroup
        ).wait())
        XCTAssertEqual(result.value, singleThrowsExpected)
        // XCTAssertEqualWithAccuracy(0.1, result.seconds, accuracy: 0.25)
    }

    func testConcurrentDispatchFieldExecutionStrategyWithMultipleFields() throws {
        let result = try timing(graphql(
            queryStrategy: ConcurrentDispatchFieldExecutionStrategy(),
            schema: schema,
            request: multiQuery,
            eventLoopGroup: eventLoopGroup
        ).wait())
        XCTAssertEqual(result.value, multiExpected)
//        XCTAssertEqualWithAccuracy(0.1, result.seconds, accuracy: 0.25)
    }

    func testConcurrentDispatchFieldExecutionStrategyWithMultipleFieldErrors() throws {
        let result = try timing(graphql(
            queryStrategy: ConcurrentDispatchFieldExecutionStrategy(),
            schema: schema,
            request: multiThrowsQuery,
            eventLoopGroup: eventLoopGroup
        ).wait())
        XCTAssertEqual(result.value.data, multiThrowsExpectedData)
        let resultErrors = result.value.errors
        XCTAssertEqual(resultErrors.count, multiThrowsExpectedErrors.count)
        multiThrowsExpectedErrors.forEach { m in
            XCTAssertTrue(resultErrors.contains(m), "Expecting result errors to contain \(m)")
        }
        // XCTAssertEqualWithAccuracy(0.1, result.seconds, accuracy: 0.25)
    }
}
