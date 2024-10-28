@testable import GraphQL
import XCTest

class ConcatASTTests: XCTestCase {
    func testConcatenatesTwoASTsTogether() throws {
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

        XCTAssertEqual(
            print(ast: astC),
            """
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
