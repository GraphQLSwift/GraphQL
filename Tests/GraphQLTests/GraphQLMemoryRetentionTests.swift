import Testing

@testable import GraphQL

// Holds a weak reference to a Token so we can observe when ARC frees it.
private final class WeakTokenBox {
    weak var token: Token?
}

@Suite struct GraphQLMemoryRetentionTests {
    private func makeSchema() throws -> GraphQLSchema {
        try GraphQLSchema(
            query: GraphQLObjectType(
                name: "Query",
                fields: ["hello": GraphQLField(type: GraphQLString)]
            )
        )
    }

    // Regression test for Token.prev being a strong reference.
    //
    // Adjacent tokens in the linked list formed a mutual retain cycle:
    // SOF.next → T1 and T1.prev → SOF. When the Document went out of scope,
    // neither token could be freed. Making prev `weak` breaks the cycle.
    @Test func tokenChainIsReleasedAfterDocumentGoesOutOfScope() throws {
        let box = WeakTokenBox()

        func parseAndCapture() throws {
            let document = try parse(source: "{ hello }")
            // startToken is SOF (no prev). Capture the next token, which
            // has a .prev back to SOF — the exact edge the fix targets.
            box.token = document.loc?.startToken.next
            #expect(box.token != nil)
        }

        try parseAndCapture()
        #expect(box.token == nil)
    }

    // Regression test for ValidationContext.init capturing `self` in a closure.
    //
    // The onError closure stored on ASTValidationContext captured ValidationContext
    // strongly, creating a cycle that prevented the context (and the Document it
    // holds) from ever being freed. Overriding report(error:) instead eliminates
    // the closure and the cycle.
    //
    // SOF (startToken) has no .prev, so it has no token-chain cycle. If it is
    // retained after this scope it must be because ValidationContext leaked and
    // is still holding a copy of the Document.
    @Test func validationContextReleasesDocumentAfterValidation() throws {
        let schema = try makeSchema()
        let box = WeakTokenBox()

        func validateAndCapture() throws {
            let document = try parse(source: "{ hello }")
            box.token = document.loc?.startToken  // SOF — no prev, no token cycle
            let errors = validate(schema: schema, ast: document)
            #expect(errors.isEmpty)
            #expect(box.token != nil)
        }

        try validateAndCapture()
        #expect(box.token == nil)
    }
}
