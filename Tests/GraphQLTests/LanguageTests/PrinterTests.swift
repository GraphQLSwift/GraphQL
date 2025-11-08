import Foundation
@testable import GraphQL
import Testing

@Suite struct PrinterTests {
    @Test func printMinimalAST() {
        let ast = Name(value: "foo")
        #expect(print(ast: ast) == "foo")
    }

    @Test func correctlyPrintNonQueryOperationsWithoutNameForQuery() throws {
        let document = try parse(source: "query { id, name }")
        let expected =
            """
            {
              id
              name
            }
            """
        #expect(print(ast: document) == expected)
    }

    @Test func correctlyPrintNonQueryOperationsWithoutNameForMutation() throws {
        let document = try parse(source: "mutation { id, name }")
        let expected =
            """
            mutation {
              id
              name
            }
            """
        #expect(print(ast: document) == expected)
    }

    @Test func correctlyPrintNonQueryOperationsWithoutNameForQueryWithArtifacts() throws {
        let document = try parse(source: "query ($foo: TestType) @testDirective { id, name }")
        let expected =
            """
            query ($foo: TestType) @testDirective {
              id
              name
            }
            """
        #expect(print(ast: document) == expected)
    }

    @Test func correctlyPrintNonQueryOperationsWithoutNameForMutationWithArtifacts() throws {
        let document = try parse(source: "mutation ($foo: TestType) @testDirective { id, name }")
        let expected =
            """
            mutation ($foo: TestType) @testDirective {
              id
              name
            }
            """
        #expect(print(ast: document) == expected)
    }

    // Variable Directives are currently not support by this library
    // TODO: Add support for variable directives
//    @Test func printsQueryWithVariableDirectives() throws {
//        let document = try parse(source: "query ($foo: TestType = { a: 123 } @testDirective(if:
//        true) @test) { id }")
//        let expected =
//        """
//        query ($foo: TestType = { a: 123 } @testDirective(if: true) @test) {
//          id
//        }
//        """
//        #expect(print(ast: document) == expected)
//    }

    @Test func keepsArgumentsOnOneLineIfLineIsShort() throws {
        let document = try parse(source: "{trip(wheelchair:false arriveBy:false){dateTime}}")
        let expected =
            """
            {
              trip(wheelchair: false, arriveBy: false) {
                dateTime
              }
            }
            """
        #expect(print(ast: document) == expected)
    }

    @Test func putsArgumentsOnMultipleLinesIfLineIsLong() throws {
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
        #expect(print(ast: document) == expected)
    }

    @Test func putsLargeObjectValuesOnMultipleLinesIfLineIsLong() throws {
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
        #expect(print(ast: document) == expected)
    }

    @Test func putsLargeListValuesOnMultipleLinesIfLineIsLong() throws {
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
        #expect(print(ast: document) == expected)
    }

    @Test func printsKitchenSinkWithoutAlteringAST() throws {
        guard
            let url = Bundle.module.url(forResource: "kitchen-sink", withExtension: "graphql"),
            let kitchenSink = try? String(contentsOf: url, encoding: .utf8)
        else {
            Issue.record("Could not load kitchen sink")
            return
        }

        let document = try parse(source: kitchenSink)
        let printed = print(ast: document)
        let parsedPrinted = try parse(source: printed)

        #expect(document == parsedPrinted)

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

        #expect(printed == expected)
    }
}
