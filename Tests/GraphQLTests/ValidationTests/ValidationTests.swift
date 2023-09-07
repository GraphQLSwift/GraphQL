@testable import GraphQL
import XCTest

class ValidationTestCase: XCTestCase {
    typealias Rule = (ValidationContext) -> Visitor

    var rule: Rule!

    private func validate(body request: String) throws -> [GraphQLError] {
        return try GraphQL.validate(
            schema: ValidationExampleSchema,
            ast: parse(source: Source(body: request, name: "GraphQL request")),
            rules: [rule]
        )
    }

    func assertValid(_ query: String, file: StaticString = #file, line: UInt = #line) throws {
        let errors = try validate(body: query)
        XCTAssertEqual(
            errors.count,
            0,
            "Expecting to pass validation without any errors",
            file: file,
            line: line
        )
    }

    @discardableResult func assertInvalid(
        errorCount: Int,
        query: String,
        file: StaticString = #file,
        line: UInt = #line
    ) throws -> [GraphQLError] {
        let errors = try validate(body: query)
        XCTAssertEqual(
            errors.count,
            errorCount,
            "Expecting to fail validation with at least 1 error",
            file: file,
            line: line
        )
        return errors
    }

    func assertValidationError(
        error: GraphQLError?,
        line: Int,
        column: Int,
        path: String = "",
        message: String,
        testFile: StaticString = #file,
        testLine: UInt = #line
    ) throws {
        guard let error = error else {
            return XCTFail("Error was not provided")
        }

        XCTAssertEqual(
            error.message,
            message,
            "Unexpected error message",
            file: testFile,
            line: testLine
        )
        XCTAssertEqual(
            error.locations[0].line,
            line,
            "Unexpected line location",
            file: testFile,
            line: testLine
        )
        XCTAssertEqual(
            error.locations[0].column,
            column,
            "Unexpected column location",
            file: testFile,
            line: testLine
        )
        let errorPath = error.path.elements.map { $0.description }.joined(separator: " ")
        XCTAssertEqual(errorPath, path, "Unexpected error path", file: testFile, line: testLine)
    }
}
