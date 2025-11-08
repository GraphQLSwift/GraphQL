import GraphQL
import Testing

@Suite struct PersistedQueriesTests {
//    let schema = try! GraphQLSchema(
//        query: GraphQLObjectType(
//            name: "RootQueryType",
//            fields: [
//                "hello": GraphQLField(
//                    type: GraphQLString,
//                    resolve: { _, _, _, _ in "world" }
//                )
//            ]
//        )
//    )
//
//    @Test func lookupWithUnknownId() throws {
//        let result = try lookup("unknown_id")
//        switch result {
//        case .unknownId(let id):
//            #expect(id == "unknown_id")
//            return
//        default:
//            Issue.record("Expected unknownId result, got \(result)")
//        }
//    }
//
//    @Test func lookupWithParseError() throws {
//        let result = try lookup("parse_error")
//        switch result {
//        case .parseError(let error):
//            #expect(String(error.message.prefix(57)) == "Syntax Error parse_error (1:4)
//            Expected Name, found <EOF>")
//            #expect(error.locations.first?.line == 1)
//            #expect(error.locations.first?.column == 4)
//            return
//        default:
//            Issue.record("Expected parseError result, got \(result)")
//        }
//    }
//
//    @Test func lookupWithValidationErrors() throws {
//        let result = try lookup("validation_errors")
//        switch result {
//        case .validateErrors(let schema, let errors):
//            #expect(schema === self.schema)
//            #expect(errors.count == 1)
//            #expect(errors.first?.message == "Cannot query field \"boyhowdy\" on type
//            \"RootQueryType\".")
//            #expect(errors.first?.locations.first?.line == 1)
//            #expect(errors.first?.locations.first?.column == 3)
//            return
//        default:
//            Issue.record("Expected validateErrors result, got \(result)")
//        }
//    }
//
//    @Test func lookupWithResult() throws {
//        let result = try lookup("result")
//        switch result {
//        case .result(let schema, _):
//            #expect(schema === self.schema)
//            return
//        default:
//            Issue.record("Expected result result, got \(result)")
//        }
//    }
//
//    @Test func graphQLWithUnknownId() throws {
//        do {
//            _ = try graphql(queryRetrieval: self, queryId: "unknown_id")
//        } catch let error as GraphQLError {
//            #expect(error.message == "Unknown query id")
//        }
//    }
//
//    @Test func graphQLWithWithParseError() throws {
//        do {
//            _ = try graphql(queryRetrieval: self, queryId: "parse_error")
//        } catch let error as GraphQLError {
//            #expect(String(error.message.prefix(57)) == "Syntax Error parse_error (1:4)
//            Expected Name, found <EOF>")
//            #expect(error.locations.first?.line == 1)
//            #expect(error.locations.first?.column == 4)
//        }
//    }
//
//    @Test func graphQLWithWithValidationErrors() throws {
//        let expected: Map = [
//            "errors": [
//                [
//                    "message": "Cannot query field \"boyhowdy\" on type \"RootQueryType\".",
//                    "locations": [["line": 1, "column": 3]]
//                ]
//            ]
//        ]
//        let result = try graphql(queryRetrieval: self, queryId: "validation_errors")
//        #expect(result == expected)
//    }
//
//    @Test func graphQLWithWithResult() throws {
//        let expected: Map = [
//            "data": [
//                "hello": "world"
//            ]
//        ]
//        let result = try graphql(queryRetrieval: self, queryId: "result")
//        #expect(result == expected)
//    }
//
    // }
//
    // extension PersistedQueriesTests: PersistedQueryRetrieval {
//    typealias Id = String
//
//    func lookup(_ id: Id) throws -> PersistedQueryRetrievalResult<Id> {
//        let source: Source
//        switch id {
//        case "parse_error":
//            source = Source(body: "{ x", name: id)
//        case "validation_errors":
//            source = Source(body: "{ boyhowdy }", name: id)
//        case "result":
//            source = Source(body: "{ hello }", name: id)
//        default:
//            return .unknownId(id)
//        }
//        do {
//            let document = try parse(source: source)
//            let validateErrors = validate(schema: schema, ast: document)
//            if validateErrors.isEmpty {
//                return .result(schema, document)
//            }
//            return .validateErrors(schema, validateErrors)
//        } catch let error as GraphQLError {
//            return .parseError(error)
//        } catch {
//            throw error
//        }
//    }
}
