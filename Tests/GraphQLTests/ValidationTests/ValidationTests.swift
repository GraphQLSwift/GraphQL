@testable import GraphQL
import Testing

class ValidationTestCase {
    typealias Rule = @Sendable (ValidationContext) -> Visitor

    var rule: Rule!

    private func validate(
        body request: String,
        schema: GraphQLSchema = ValidationExampleSchema
    ) throws -> [GraphQLError] {
        return try GraphQL.validate(
            schema: schema,
            ast: parse(source: Source(body: request, name: "GraphQL request")),
            rules: [rule]
        )
    }

    func assertValid(
        _ query: String,
        schema: GraphQLSchema = ValidationExampleSchema
    ) throws {
        let errors = try validate(body: query, schema: schema)
        #expect(errors.count == 0)
    }

    @discardableResult func assertInvalid(
        errorCount: Int,
        query: String,
        schema: GraphQLSchema = ValidationExampleSchema
    ) throws -> [GraphQLError] {
        let errors = try validate(body: query, schema: schema)
        #expect(errors.count == errorCount)
        return errors
    }

    func assertValidationError(
        error: GraphQLError?,
        line: Int,
        column: Int,
        path: String = "",
        message: String
    ) throws {
        guard let error = error else {
            Issue.record("Error was not provided")
            return
        }

        #expect(error.message == message)
        #expect(error.locations[0].line == line)
        #expect(error.locations[0].column == column)
        let errorPath = error.path.elements.map { $0.description }.joined(separator: " ")
        #expect(errorPath == path)
    }

    func assertValidationError(
        error: GraphQLError?,
        locations: [(line: Int, column: Int)],
        path: String = "",
        message: String
    ) throws {
        guard let error = error else {
            Issue.record("Error was not provided")
            return
        }

        #expect(error.message == message)
        for (index, actualLocation) in error.locations.enumerated() {
            let expectedLocation = locations[index]
            #expect(actualLocation.line == expectedLocation.line)
            #expect(actualLocation.column == expectedLocation.column)
        }
        let errorPath = error.path.elements.map { $0.description }.joined(separator: " ")
        #expect(errorPath == path)
    }
}

class SDLValidationTestCase {
    typealias Rule = @Sendable (SDLValidationContext) -> Visitor

    var rule: Rule!

    func assertValidationErrors(
        _ sdlStr: String,
        schema: GraphQLSchema? = nil,
        _ errors: [GraphQLError]
    ) throws {
        let doc = try parse(source: sdlStr)
        let validationErrors = validateSDL(documentAST: doc, schemaToExtend: schema, rules: [rule])

        #expect(
            validationErrors.map(\.message) ==
                errors.map(\.message)
        )

        #expect(
            validationErrors.map(\.locations) ==
                errors.map(\.locations)
        )
    }
}
