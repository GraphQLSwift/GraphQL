@testable import GraphQL
import XCTest

class PrinterTests: XCTestCase {
    func testPrintMinimalAST() {
        let ast = Name(value: "foo")
        XCTAssertEqual(print(ast: ast), "foo")
    }

    func testCorrectlyPrintNonQueryOperationsWithoutNameForQuery() throws {
        let document = try parse(source: "query { id, name }")
        let expected =
            """
            {
              id
              name
            }
            """
        XCTAssertEqual(print(ast: document), expected)
    }

    func testCorrectlyPrintNonQueryOperationsWithoutNameForMutation() throws {
        let document = try parse(source: "mutation { id, name }")
        let expected =
            """
            mutation {
              id
              name
            }
            """
        XCTAssertEqual(print(ast: document), expected)
    }

    func testCorrectlyPrintNonQueryOperationsWithoutNameForQueryWithArtifacts() throws {
        let document = try parse(source: "query ($foo: TestType) @testDirective { id, name }")
        let expected =
            """
            query ($foo: TestType) @testDirective {
              id
              name
            }
            """
        XCTAssertEqual(print(ast: document), expected)
    }

    func testCorrectlyPrintNonQueryOperationsWithoutNameForMutationWithArtifacts() throws {
        let document = try parse(source: "mutation ($foo: TestType) @testDirective { id, name }")
        let expected =
            """
            mutation ($foo: TestType) @testDirective {
              id
              name
            }
            """
        XCTAssertEqual(print(ast: document), expected)
    }

    // Variable Directives are currently not support by this library
    // TODO: Add support for variable directives
//    func testPrintsQueryWithVariableDirectives() throws {
//        let document = try parse(source: "query ($foo: TestType = { a: 123 } @testDirective(if:
//        true) @test) { id }")
//        let expected =
//        """
//        query ($foo: TestType = { a: 123 } @testDirective(if: true) @test) {
//          id
//        }
//        """
//        XCTAssertEqual(print(ast: document), expected)
//    }

    func testKeepsArgumentsOnOneLineIfLineIsShort() throws {
        let document = try parse(source: "{trip(wheelchair:false arriveBy:false){dateTime}}")
        let expected =
            """
            {
              trip(wheelchair: false, arriveBy: false) {
                dateTime
              }
            }
            """
        XCTAssertEqual(print(ast: document), expected)
    }

    func testPutsArgumentsOnMultipleLinesIfLineIsLong() throws {
        let document =
            try parse(
                source: "{trip(wheelchair:false arriveBy:false includePlannedCancellations:true transitDistanceReluctance:2000){dateTime}}"
            )
        let expected =
            """
            {
              trip(
                wheelchair: false
                arriveBy: false
                includePlannedCancellations: true
                transitDistanceReluctance: 2000
              ) {
                dateTime
              }
            }
            """
        XCTAssertEqual(print(ast: document), expected)
    }

    func testPutsLargeObjectValuesOnMultipleLinesIfLineIsLong() throws {
        let document =
            try parse(
                source: "{trip(obj:{wheelchair:false,smallObj:{a: 1},largeObj:{wheelchair:false,smallObj:{a: 1},arriveBy:false,includePlannedCancellations:true,transitDistanceReluctance:2000,anotherLongFieldName:\"Lots and lots and lots and lots of text\"},arriveBy:false,includePlannedCancellations:true,transitDistanceReluctance:2000,anotherLongFieldName:\"Lots and lots and lots and lots of text\"}){dateTime}}"
            )
        let expected =
            """
            {
              trip(
                obj: {
                  wheelchair: false
                  smallObj: { a: 1 }
                  largeObj: {
                    wheelchair: false
                    smallObj: { a: 1 }
                    arriveBy: false
                    includePlannedCancellations: true
                    transitDistanceReluctance: 2000
                    anotherLongFieldName: "Lots and lots and lots and lots of text"
                  }
                  arriveBy: false
                  includePlannedCancellations: true
                  transitDistanceReluctance: 2000
                  anotherLongFieldName: "Lots and lots and lots and lots of text"
                }
              ) {
                dateTime
              }
            }
            """
        XCTAssertEqual(print(ast: document), expected)
    }

    func testPutsLargeListValuesOnMultipleLinesIfLineIsLong() throws {
        let document =
            try parse(
                source: "{trip(list:[[\"small array\", \"small\", \"small\"], [\"Lots and lots and lots and lots of text\", \"Lots and lots and lots and lots of text\", \"Lots and lots and lots and lots of text\"]]){dateTime}}"
            )
        let expected =
            """
            {
              trip(
                list: [
                  ["small array", "small", "small"]
                  [
                    "Lots and lots and lots and lots of text"
                    "Lots and lots and lots and lots of text"
                    "Lots and lots and lots and lots of text"
                  ]
                ]
              ) {
                dateTime
              }
            }
            """
        XCTAssertEqual(print(ast: document), expected)
    }

    func testPrintsKitchenSinkWithoutAlteringAST() throws {
        guard
            let url = Bundle.module.url(forResource: "kitchen-sink", withExtension: "graphql"),
            let kitchenSink = try? String(contentsOf: url, encoding: .utf8)
        else {
            XCTFail("Could not load kitchen sink")
            return
        }

        let document = try parse(source: kitchenSink)
        let printed = print(ast: document)
        let parsedPrinted = try parse(source: printed)

        XCTAssertEqual(document, parsedPrinted)

        let expected =
            """
            query queryName($foo: ComplexType, $site: Site = MOBILE) {
              whoever123is: node(id: [123, 456]) {
                id
                ... on User @defer {
                  field2 {
                    id
                    alias: field1(first: 10, after: $foo) @include(if: $foo) {
                      id
                      ...frag
                    }
                  }
                }
                ... @skip(unless: $foo) {
                  id
                }
                ... {
                  id
                }
              }
            }

            mutation likeStory {
              like(story: 123) @defer {
                story {
                  id
                }
              }
            }

            subscription StoryLikeSubscription($input: StoryLikeSubscribeInput) {
              storyLikeSubscribe(input: $input) {
                story {
                  likers {
                    count
                  }
                  likeSentence {
                    text
                  }
                }
              }
            }

            fragment frag on Friend {
              foo(size: $size, bar: $b, obj: { key: \"value\" })
            }

            {
              unnamed(truthy: true, falsey: false)
              query
            }
            """

        XCTAssertEqual(printed, expected)
    }
}
