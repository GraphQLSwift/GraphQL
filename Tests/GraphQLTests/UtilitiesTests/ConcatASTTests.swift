@testable import GraphQL
import Testing

@Suite struct ConcatASTTests {
    @Test func concatenatesTwoASTsTogether() throws {
        let sourceA = Source(body: """
        { a, b, ...Frag }
        """)

        let sourceB = Source(body: """
        fragment Frag on T {
          c
        }
        """)

        let astA = try parse(source: sourceA)
        let astB = try parse(source: sourceB)
        let astC = concatAST(documents: [astA, astB])

        #expect(
            print(ast: astC) == """
            {
              a
              b
              ...Frag
            }

            fragment Frag on T {
              c
            }
            """
        )
    }
}
