import GraphQL
import XCTest

class PersistedQueriesTests: XCTestCase {

    let schema = try! GraphQLSchema(
        query: GraphQLObjectType(
            name: "RootQueryType",
            fields: [
                "hello": GraphQLField(
                    type: GraphQLString,
                    resolve: { _, _, _, _ in "world" }
                )
            ]
        )
    )

    func testLookupWithUnknownId() throws {
        let result = try lookup("unknown_id")
        switch result {
        case .unknownId(let id):
            XCTAssertEqual(id, "unknown_id")
            return
        default:
            XCTFail("Expected unknownId result, got \(result)")
        }
    }

    func testLookupWithParseError() throws {
        let result = try lookup("parse_error")
        switch result {
        case .parseError(let error):
            XCTAssertEqual(String(error.message.characters.prefix(57)), "Syntax Error parse_error (1:4) Expected Name, found <EOF>")
            XCTAssertEqual(error.locations.first?.line, 1)
            XCTAssertEqual(error.locations.first?.column, 4)
            return
        default:
            XCTFail("Expected parseError result, got \(result)")
        }
    }

    func testLookupWithValidationErrors() throws {
        let result = try lookup("validation_errors")
        switch result {
        case .validateErrors(let schema, let errors):
            XCTAssertTrue(schema === self.schema)
            XCTAssertEqual(errors.count, 1)
            XCTAssertEqual(errors.first?.message, "Cannot query field \"boyhowdy\" on type \"RootQueryType\".")
            XCTAssertEqual(errors.first?.locations.first?.line, 1)
            XCTAssertEqual(errors.first?.locations.first?.column, 3)
            return
        default:
            XCTFail("Expected validateErrors result, got \(result)")
        }
    }

    func testLookupWithResult() throws {
        let result = try lookup("result")
        switch result {
        case .result(let schema, _):
            XCTAssertTrue(schema === self.schema)
            return
        default:
            XCTFail("Expected result result, got \(result)")
        }
    }

    func testGraphQLWithUnknownId() throws {
        do {
            _ = try graphql(queryRetrieval: self, queryId: "unknown_id")
        } catch let error as GraphQLError {
            XCTAssertEqual(error.message, "Unknown query id")
        }
    }

    func testGraphQLWithWithParseError() throws {
        do {
            _ = try graphql(queryRetrieval: self, queryId: "parse_error")
        } catch let error as GraphQLError {
            XCTAssertEqual(String(error.message.characters.prefix(57)), "Syntax Error parse_error (1:4) Expected Name, found <EOF>")
            XCTAssertEqual(error.locations.first?.line, 1)
            XCTAssertEqual(error.locations.first?.column, 4)
        }
    }

    func testGraphQLWithWithValidationErrors() throws {
        let expected: Map = [
            "errors": [
                [
                    "message": "Cannot query field \"boyhowdy\" on type \"RootQueryType\".",
                    "locations": [["line": 1, "column": 3]]
                ]
            ]
        ]
        let result = try graphql(queryRetrieval: self, queryId: "validation_errors")
        XCTAssertEqual(result, expected)
    }

    func testGraphQLWithWithResult() throws {
        let expected: Map = [
            "data": [
                "hello": "world"
            ]
        ]
        let result = try graphql(queryRetrieval: self, queryId: "result")
        XCTAssertEqual(result, expected)
    }

}

extension PersistedQueriesTests: PersistedQueryRetrieval {
    typealias Id = String

    func lookup(_ id: Id) throws -> PersistedQueryRetrievalResult<Id> {
        let source: Source
        switch id {
        case "parse_error":
            source = Source(body: "{ x", name: id)
        case "validation_errors":
            source = Source(body: "{ boyhowdy }", name: id)
        case "result":
            source = Source(body: "{ hello }", name: id)
        default:
            return .unknownId(id)
        }
        do {
            let document = try parse(source: source)
            let validateErrors = validate(schema: schema, ast: document)
            if validateErrors.isEmpty {
                return .result(schema, document)
            }
            return .validateErrors(schema, validateErrors)
        } catch let error as GraphQLError {
            return .parseError(error)
        } catch {
            throw error
        }
    }

}

extension PersistedQueriesTests {
    static var allTests: [(String, (PersistedQueriesTests) -> () throws -> Void)] {
        return [
            ("testLookupWithUnknownId", testLookupWithUnknownId),
            ("testLookupWithParseError", testLookupWithParseError),
            ("testLookupWithValidationErrors", testLookupWithValidationErrors),
            ("testLookupWithResult", testLookupWithResult),
            ("testGraphQLWithUnknownId", testGraphQLWithUnknownId),
            ("testGraphQLWithWithParseError", testGraphQLWithWithParseError),
            ("testGraphQLWithWithValidationErrors", testGraphQLWithWithValidationErrors),
            ("testGraphQLWithWithResult", testGraphQLWithWithResult),
        ]
    }
}
