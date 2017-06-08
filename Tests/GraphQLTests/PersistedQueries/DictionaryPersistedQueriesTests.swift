import XCTest
@testable import GraphQL

class DictionaryPersistedQueriesTests : XCTestCase {
    let schema = try! GraphQLSchema(
        query: GraphQLObjectType(
            name: "RootQueryType",
            fields: [
                "hello": GraphQLField(
                    type: GraphQLString,
                    resolve: { _ in "world" }
                )
            ]
        )
    )

    let sources: [Int: Source] = [
        42: Source(body: "{ hello }", name: "Hello GraphQL")
    ]

    func testKnownId() throws {
        let queries = try DictionaryPersistedQueries<Int>(schema: schema, sources: sources)
        let expected: Map = [
            "data": [
                "hello": "world"
            ]
        ]
        let result = try queries.execute(id: 42)
        XCTAssertEqual(result, expected)
    }

    func testUnknownId() throws {
        let queries = try DictionaryPersistedQueries<Int>(schema: schema, sources: sources)
        XCTAssertThrowsError(try queries.execute(id: 29)) { error in
            guard let error = error as? GraphQLError else {
                return XCTFail()
            }
            XCTAssert(error.message.contains(
                "Unknown query \"29\"."
            ))
        }
    }

    func testWithInvalidSource() throws {
        let brokenSource: [Int: Source] = [
            91: Source(body: "{ hello ", name: "broken Hello GraphQL")
        ]
        XCTAssertThrowsError(
            try DictionaryPersistedQueries<Int>(schema: schema, sources: brokenSource)
        ) { error in
            guard let error = error as? GraphQLError else {
                return XCTFail()
            }
            XCTAssert(error.message.contains(
                "Syntax Error broken Hello GraphQL (1:9) Expected Name, found <EOF>"
            ))
        }
    }
}

extension DictionaryPersistedQueriesTests {
    static var allTests: [(String, (DictionaryPersistedQueriesTests) -> () throws -> Void)] {
        return [
            ("testKnownId", testKnownId),
            ("testUnknownId", testUnknownId),
            ("testWithInvalidSource", testWithInvalidSource),
        ]
    }
}
