import XCTest
@testable import GraphQLTests

XCTMain([
     testCase(HelloWorldTests.allTests),
     testCase(StarWarsQueryTests.allTests),
     testCase(StarWarsIntrospectionTests.allTests),
     testCase(StarWarsValidationTests.allTests),
     testCase(MapTests.allTests),
     testCase(LexerTests.allTests),
     testCase(ParserTests.allTests),
     testCase(SchemaParserTests.allTests),
])
