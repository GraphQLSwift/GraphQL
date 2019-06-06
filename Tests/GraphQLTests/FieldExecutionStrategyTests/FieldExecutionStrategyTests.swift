import Dispatch
import GraphQL
import XCTest
import NIO

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
                        let g = DispatchGroup()
                        g.enter()
                        DispatchQueue.global().asyncAfter(wallDeadline: .now() + 0.1) {
                            g.leave()
                        }
                        g.wait()
                        return eventLoopGroup.next().newSucceededFuture(result: "z")
                }
                ),
                "bang": GraphQLField(
                    type: GraphQLString,
                    resolve: { (_, _, _, _, info: GraphQLResolveInfo) in
                        let g = DispatchGroup()
                        g.enter()
                        DispatchQueue.global().asyncAfter(wallDeadline: .now() + 0.1) {
                            g.leave()
                        }
                        g.wait()
                        throw StrategyError.exampleError(
                            msg: "\(info.fieldName): \(info.path.last as! String)"
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
                        return eventLoopGroup.next().newFailedFuture(error: StrategyError.exampleError(
                            msg: "\(info.fieldName): \(info.path.last as! String)"
                        ))
                }
                )
            ]
        )
    )

    let singleQuery = "{ sleep }"
    let singleExpected: Map = [
        "data": [
            "sleep": "z"
        ]
    ]

    let multiQuery = "{ a: sleep b: sleep c: sleep d: sleep e: sleep f: sleep g: sleep h: sleep i: sleep j: sleep }"
    let multiExpected: Map = [
        "data": [
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
    ]

    let singleThrowsQuery = "{ bang }"
    let singleThrowsExpected: Map = [
        "data": [
            "bang": nil
        ],
        "errors": [
            [
                "locations": [
                    ["column": 3, "line": 1]
                ],
                "message": "exampleError(msg: \"bang: bang\")",
                "path":["bang"]
            ]
        ]
    ]
    
    let singleFailedFutureQuery = "{ futureBang }"
    let singleFailedFutureExpected: Map = [
        "data": [
            "futureBang": nil
        ],
        "errors": [
            [
                "locations": [
                    ["column": 3, "line": 1]
                ],
                "message": "exampleError(msg: \"futureBang: futureBang\")",
                "path":["futureBang"]
            ]
        ]
    ]

    let multiThrowsQuery = "{ a: bang b: bang c: bang d: bang e: bang f: bang g: bang h: bang i: bang j: futureBang }"
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
    let multiThrowsExpectedErrors: [Map] = [
        [
            "locations": [
                ["column": 3, "line": 1]
            ],
            "message": "exampleError(msg: \"bang: a\")",
            "path":["a"]
        ],
        [
            "locations": [
                ["column": 11, "line": 1]
            ],
            "message": "exampleError(msg: \"bang: b\")",
            "path":["b"]
        ],
        [
            "locations": [
                ["column": 19, "line": 1]
            ],
            "message": "exampleError(msg: \"bang: c\")",
            "path":["c"]
        ],
        [
            "locations": [
                ["column": 27, "line": 1]
            ],
            "message": "exampleError(msg: \"bang: d\")",
            "path":["d"]
        ],
        [
            "locations": [
                ["column": 35, "line": 1]
            ],
            "message": "exampleError(msg: \"bang: e\")",
            "path":["e"]
        ],
        [
            "locations": [
                ["column": 43, "line": 1]
            ],
            "message": "exampleError(msg: \"bang: f\")",
            "path":["f"]
        ],
        [
            "locations": [
                ["column": 51, "line": 1]
            ],
            "message": "exampleError(msg: \"bang: g\")",
            "path":["g"]
        ],
        [
            "locations": [
                ["column": 59, "line": 1]
            ],
            "message": "exampleError(msg: \"bang: h\")",
            "path":["h"]
        ],
        [
            "locations": [
                ["column": 67, "line": 1]
            ],
            "message": "exampleError(msg: \"bang: i\")",
            "path":["i"]
        ],
        [
            "locations": [
                ["column": 75, "line": 1]
            ],
            "message": "exampleError(msg: \"futureBang: j\")",
            "path":["j"]
        ],
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
        eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    }
    
    override func tearDown() {
        XCTAssertNoThrow(try eventLoopGroup.syncShutdownGracefully())
    }

    func testSerialFieldExecutionStrategyWithSingleField() throws {

        let result = try timing(try graphql(
            queryStrategy: SerialFieldExecutionStrategy(),
            schema: schema,
            request: singleQuery,
            eventLoopGroup: eventLoopGroup
            ).wait())
        XCTAssertEqual(result.value, singleExpected)
        //XCTAssertEqualWithAccuracy(0.1, result.seconds, accuracy: 0.25)
    }

    func testSerialFieldExecutionStrategyWithSingleFieldError() throws {
        
        let result = try timing(try graphql(
            queryStrategy: SerialFieldExecutionStrategy(),
            schema: schema,
            request: singleThrowsQuery,
            eventLoopGroup: eventLoopGroup
            ).wait())
        XCTAssertEqual(result.value, singleThrowsExpected)
        //XCTAssertEqualWithAccuracy(0.1, result.seconds, accuracy: 0.25)
    }
    
    func testSerialFieldExecutionStrategyWithSingleFieldFailedFuture() throws {
        
        let result = try timing(try graphql(
            queryStrategy: SerialFieldExecutionStrategy(),
            schema: schema,
            request: singleFailedFutureQuery,
            eventLoopGroup: eventLoopGroup
            ).wait())
        XCTAssertEqual(result.value, singleFailedFutureExpected)
        //XCTAssertEqualWithAccuracy(0.1, result.seconds, accuracy: 0.25)
    }

    func testSerialFieldExecutionStrategyWithMultipleFields() throws {

        let result = try timing(try graphql(
            queryStrategy: SerialFieldExecutionStrategy(),
            schema: schema,
            request: multiQuery,
            eventLoopGroup: eventLoopGroup
            ).wait())
        XCTAssertEqual(result.value, multiExpected)
        //XCTAssertEqualWithAccuracy(1.0, result.seconds, accuracy: 0.5)
    }

    func testSerialFieldExecutionStrategyWithMultipleFieldErrors() throws {

        let result = try timing(try graphql(
            queryStrategy: SerialFieldExecutionStrategy(),
            schema: schema,
            request: multiThrowsQuery,
            eventLoopGroup: eventLoopGroup
            ).wait())
        XCTAssertEqual(result.value["data"], multiThrowsExpectedData)
        let resultErrors = try result.value["errors"].asArray()
        XCTAssertEqual(resultErrors.count, multiThrowsExpectedErrors.count)
        multiThrowsExpectedErrors.forEach { (m) in
            XCTAssertTrue(resultErrors.contains(m), "Expecting result errors to contain \(m)")
        }
        //XCTAssertEqualWithAccuracy(1.0, result.seconds, accuracy: 0.5)
    }

    func testConcurrentDispatchFieldExecutionStrategyWithSingleField() throws {

        let result = try timing(try graphql(
            queryStrategy: ConcurrentDispatchFieldExecutionStrategy(),
            schema: schema,
            request: singleQuery,
            eventLoopGroup: eventLoopGroup
            ).wait())
        XCTAssertEqual(result.value, singleExpected)
        //XCTAssertEqualWithAccuracy(0.1, result.seconds, accuracy: 0.25)
    }

    func testConcurrentDispatchFieldExecutionStrategyWithSingleFieldError() throws {

        let result = try timing(try graphql(
            queryStrategy: ConcurrentDispatchFieldExecutionStrategy(),
            schema: schema,
            request: singleThrowsQuery,
            eventLoopGroup: eventLoopGroup
            ).wait())
        XCTAssertEqual(result.value, singleThrowsExpected)
        //XCTAssertEqualWithAccuracy(0.1, result.seconds, accuracy: 0.25)
    }

    func testConcurrentDispatchFieldExecutionStrategyWithMultipleFields() throws {

        let result = try timing(try graphql(
            queryStrategy: ConcurrentDispatchFieldExecutionStrategy(),
            schema: schema,
            request: multiQuery,
            eventLoopGroup: eventLoopGroup
            ).wait())
        XCTAssertEqual(result.value, multiExpected)
        //XCTAssertEqualWithAccuracy(0.1, result.seconds, accuracy: 0.25)
    }

    func testConcurrentDispatchFieldExecutionStrategyWithMultipleFieldErrors() throws {

        let result = try timing(try graphql(
            queryStrategy: ConcurrentDispatchFieldExecutionStrategy(),
            schema: schema,
            request: multiThrowsQuery,
            eventLoopGroup: eventLoopGroup
            ).wait())
        XCTAssertEqual(result.value["data"], multiThrowsExpectedData)
        let resultErrors = try result.value["errors"].asArray()
        XCTAssertEqual(resultErrors.count, multiThrowsExpectedErrors.count)
        multiThrowsExpectedErrors.forEach { (m) in
            XCTAssertTrue(resultErrors.contains(m), "Expecting result errors to contain \(m)")
        }
        //XCTAssertEqualWithAccuracy(0.1, result.seconds, accuracy: 0.25)
    }

}

extension FieldExecutionStrategyTests {
    static var allTests: [(String, (FieldExecutionStrategyTests) -> () throws -> Void)] {
        return [
            ("testSerialFieldExecutionStrategyWithSingleField", testSerialFieldExecutionStrategyWithSingleField),
            ("testSerialFieldExecutionStrategyWithSingleFieldError", testSerialFieldExecutionStrategyWithSingleFieldError),
            ("testSerialFieldExecutionStrategyWithSingleFieldFailedFuture", testSerialFieldExecutionStrategyWithSingleFieldFailedFuture),
            ("testSerialFieldExecutionStrategyWithMultipleFields", testSerialFieldExecutionStrategyWithMultipleFields),
            ("testSerialFieldExecutionStrategyWithMultipleFieldErrors", testSerialFieldExecutionStrategyWithMultipleFieldErrors),
            ("testConcurrentDispatchFieldExecutionStrategyWithSingleField", testConcurrentDispatchFieldExecutionStrategyWithSingleField),
            ("testConcurrentDispatchFieldExecutionStrategyWithSingleFieldError", testConcurrentDispatchFieldExecutionStrategyWithSingleFieldError),
            ("testConcurrentDispatchFieldExecutionStrategyWithMultipleFields", testConcurrentDispatchFieldExecutionStrategyWithMultipleFields),
            ("testConcurrentDispatchFieldExecutionStrategyWithMultipleFieldErrors", testConcurrentDispatchFieldExecutionStrategyWithMultipleFieldErrors),
        ]
    }
}


