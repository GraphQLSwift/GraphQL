@testable import GraphQL
import NIO
import XCTest

class ScalarTests: XCTestCase {
    func testIntParseValue() {
        try XCTAssertEqual(GraphQLInt.parseValue(1), 1)
        try XCTAssertEqual(GraphQLInt.parseValue(0), 0)
        try XCTAssertEqual(GraphQLInt.parseValue(-1), -1)

        try XCTAssertThrowsError(
            GraphQLInt.parseValue(9_876_504_321),
            "Int cannot represent non 32-bit signed integer value: 9876504321"
        )
        try XCTAssertThrowsError(
            GraphQLInt.parseValue(-9_876_504_321),
            "Int cannot represent non 32-bit signed integer value: -9876504321"
        )
        // TODO: Avoid rounding these
//        try XCTAssertThrowsError(
//            GraphQLInt.parseValue(0.1),
//            "Int cannot represent non-integer value: 0.1"
//        )
        try XCTAssertThrowsError(
            GraphQLInt.parseValue(.double(Double.nan)),
            "Int cannot represent non-integer value: NaN"
        )
        try XCTAssertThrowsError(
            GraphQLInt.parseValue(.double(Double.infinity)),
            "Int cannot represent non-integer value: Infinity"
        )

        try XCTAssertThrowsError(
            GraphQLInt.parseValue(.undefined),
            "Int cannot represent non-integer value: undefined"
        )
        try XCTAssertThrowsError(
            GraphQLInt.parseValue(.null),
            "Int cannot represent non-integer value: null"
        )
        try XCTAssertThrowsError(
            GraphQLInt.parseValue(""),
            #"Int cannot represent non-integer value: """#
        )
        try XCTAssertThrowsError(
            GraphQLInt.parseValue("123"),
            #"Int cannot represent non-integer value: "123""#
        )
        try XCTAssertThrowsError(
            GraphQLInt.parseValue(false),
            "Int cannot represent non-integer value: false"
        )
        try XCTAssertThrowsError(
            GraphQLInt.parseValue(true),
            "Int cannot represent non-integer value: true"
        )
        try XCTAssertThrowsError(
            GraphQLInt.parseValue([1]),
            "Int cannot represent non-integer value: [1]"
        )
        try XCTAssertThrowsError(
            GraphQLInt.parseValue(["value": 1]),
            "Int cannot represent non-integer value: { value: 1 }"
        )
    }

    func testIntSerialize() {
        try XCTAssertEqual(GraphQLInt.serialize(1), 1)
        try XCTAssertEqual(GraphQLInt.serialize("123"), 123)
        try XCTAssertEqual(GraphQLInt.serialize(0), 0)
        try XCTAssertEqual(GraphQLInt.serialize(-1), -1)
        try XCTAssertEqual(GraphQLInt.serialize(1e5), 100_000)
        try XCTAssertEqual(GraphQLInt.serialize(false), 0)
        try XCTAssertEqual(GraphQLInt.serialize(true), 1)

        // The GraphQL specification does not allow serializing non-integer values
        // as Int to avoid accidental data loss.
        // TODO: Avoid rounding these
//        try XCTAssertThrowsError(
//            GraphQLInt.serialize(0.1),
//            "Int cannot represent non-integer value: 0.1"
//        )
//        try XCTAssertThrowsError(
//            GraphQLInt.serialize(1.1),
//            "Int cannot represent non-integer value: 1.1"
//        )
//        try XCTAssertThrowsError(
//            GraphQLInt.serialize(-1.1),
//            "Int cannot represent non-integer value: -1.1"
//        )
        try XCTAssertThrowsError(
            GraphQLInt.serialize("-1.1"),
            #"Int cannot represent non-integer value: "-1.1""#
        )

        // Maybe a safe JavaScript int, but bigger than 2^32, so not
        // representable as a GraphQL Int
        try XCTAssertThrowsError(
            GraphQLInt.serialize(9_876_504_321),
            "Int cannot represent non 32-bit signed integer value: 9876504321"
        )
        try XCTAssertThrowsError(
            GraphQLInt.serialize(-9_876_504_321),
            "Int cannot represent non 32-bit signed integer value: -9876504321"
        )

        // Too big to represent as an Int in JavaScript or GraphQL
        try XCTAssertThrowsError(
            GraphQLInt.serialize(1e100),
            "Int cannot represent non 32-bit signed integer value: 1e+100"
        )
        try XCTAssertThrowsError(
            GraphQLInt.serialize(-1e100),
            "Int cannot represent non 32-bit signed integer value: -1e+100"
        )
        try XCTAssertThrowsError(
            GraphQLInt.serialize("one"),
            #"Int cannot represent non-integer value: "one""#
        )

        // Doesn"t represent number
        try XCTAssertThrowsError(
            GraphQLInt.serialize(""),
            #"Int cannot represent non-integer value: """#
        )
        try XCTAssertThrowsError(
            GraphQLInt.serialize(Double.nan),
            "Int cannot represent non-integer value: NaN"
        )
        try XCTAssertThrowsError(
            GraphQLInt.serialize(Double.infinity),
            "Int cannot represent non-integer value: Infinity"
        )
        try XCTAssertThrowsError(
            GraphQLInt.serialize([5]),
            "Int cannot represent non-integer value: [5]"
        )
    }

    func testFloatParseValue() throws {
        try XCTAssertEqual(GraphQLFloat.parseValue(1), 1)
        try XCTAssertEqual(GraphQLFloat.parseValue(0), 0)
        try XCTAssertEqual(GraphQLFloat.parseValue(-1), -1)
        try XCTAssertEqual(GraphQLFloat.parseValue(0.1), 0.1)
        try XCTAssertEqual(GraphQLFloat.parseValue(.double(Double.pi)), .double(Double.pi))

        try XCTAssertThrowsError(
            GraphQLFloat.parseValue(.double(Double.nan)),
            "Float cannot represent non numeric value: NaN"
        )
        try XCTAssertThrowsError(
            GraphQLFloat.parseValue(.double(Double.infinity)),
            "Float cannot represent non numeric value: Infinity"
        )

        try XCTAssertThrowsError(
            GraphQLFloat.parseValue(.undefined),
            "Float cannot represent non numeric value: undefined"
        )
        try XCTAssertThrowsError(
            GraphQLFloat.parseValue(.null),
            "Float cannot represent non numeric value: null"
        )
        try XCTAssertThrowsError(
            GraphQLFloat.parseValue(""),
            #"Float cannot represent non numeric value: """#
        )
        try XCTAssertThrowsError(
            GraphQLFloat.parseValue("123"),
            #"Float cannot represent non numeric value: "123""#
        )
        try XCTAssertThrowsError(
            GraphQLFloat.parseValue("123.5"),
            #"Float cannot represent non numeric value: "123.5""#
        )
        try XCTAssertThrowsError(
            GraphQLFloat.parseValue(false),
            "Float cannot represent non numeric value: false"
        )
        try XCTAssertThrowsError(
            GraphQLFloat.parseValue(true),
            "Float cannot represent non numeric value: true"
        )
        try XCTAssertThrowsError(
            GraphQLFloat.parseValue([0.1]),
            "Float cannot represent non numeric value: [0.1]"
        )
        try XCTAssertThrowsError(
            GraphQLFloat.parseValue(["value": 0.1]),
            "Float cannot represent non numeric value: { value: 0.1 }"
        )
    }

    func testFloatSerialize() throws {
        try XCTAssertEqual(GraphQLFloat.serialize(1), 1.0)
        try XCTAssertEqual(GraphQLFloat.serialize(0), 0.0)
        try XCTAssertEqual(GraphQLFloat.serialize("123.5"), 123.5)
        try XCTAssertEqual(GraphQLFloat.serialize(-1), -1.0)
        try XCTAssertEqual(GraphQLFloat.serialize(0.1), 0.1)
        try XCTAssertEqual(GraphQLFloat.serialize(1.1), 1.1)
        try XCTAssertEqual(GraphQLFloat.serialize(-1.1), -1.1)
        try XCTAssertEqual(GraphQLFloat.serialize("-1.1"), -1.1)
        try XCTAssertEqual(GraphQLFloat.serialize(false), 0.0)
        try XCTAssertEqual(GraphQLFloat.serialize(true), 1.0)

        try XCTAssertThrowsError(
            GraphQLFloat.serialize(Double.nan),
            "Float cannot represent non numeric value: NaN"
        )
        try XCTAssertThrowsError(
            GraphQLFloat.serialize(Double.infinity),
            "Float cannot represent non numeric value: Infinity"
        )
        try XCTAssertThrowsError(
            GraphQLFloat.serialize("one"),
            #"Float cannot represent non numeric value: "one""#
        )
        try XCTAssertThrowsError(
            GraphQLFloat.serialize(""),
            #"Float cannot represent non numeric value: """#
        )
        try XCTAssertThrowsError(
            GraphQLFloat.serialize([5]),
            "Float cannot represent non numeric value: [5]"
        )
    }

    func testStringParseValue() throws {
        try XCTAssertEqual(GraphQLString.parseValue("foo"), "foo")

        try XCTAssertThrowsError(
            GraphQLString.parseValue(.undefined),
            "String cannot represent a non string value: undefined"
        )
        try XCTAssertThrowsError(
            GraphQLString.parseValue(.null),
            "String cannot represent a non string value: null"
        )
        try XCTAssertThrowsError(
            GraphQLString.parseValue(1),
            "String cannot represent a non string value: 1"
        )
        try XCTAssertThrowsError(
            GraphQLString.parseValue(.double(Double.nan)),
            "String cannot represent a non string value: NaN"
        )
        try XCTAssertThrowsError(
            GraphQLString.parseValue(false),
            "String cannot represent a non string value: false"
        )
        try XCTAssertThrowsError(
            GraphQLString.parseValue(["foo"]),
            #"String cannot represent a non string value: ["foo"]"#
        )
        try XCTAssertThrowsError(
            GraphQLString.parseValue(["value": "foo"]),
            #"String cannot represent a non string value: { value: "foo" }"#
        )
    }

    func testStringSerialize() throws {
        try XCTAssertEqual(GraphQLString.serialize("string"), "string")
        try XCTAssertEqual(GraphQLString.serialize(1), "1")
        try XCTAssertEqual(GraphQLString.serialize(-1.1), "-1.1")
        try XCTAssertEqual(GraphQLString.serialize(true), "true")
        try XCTAssertEqual(GraphQLString.serialize(false), "false")

        try XCTAssertThrowsError(
            GraphQLString.serialize(Double.nan),
            "String cannot represent value: NaN"
        )

        try XCTAssertThrowsError(
            GraphQLString.serialize([1]),
            "String cannot represent value: [1]"
        )

        let badObjValue: Map = [:]
        try XCTAssertThrowsError(
            GraphQLString.serialize(badObjValue),
            "String cannot represent value: {}"
        )

        let badValueOfObjValue: Map = ["valueOf": "valueOf string"]
        try XCTAssertThrowsError(
            GraphQLString.serialize(badValueOfObjValue),
            #"String cannot represent value: { valueOf: "valueOf string" }"#
        )
    }

    func testBoolParseValue() throws {
        try XCTAssertEqual(GraphQLBoolean.parseValue(true), true)
        try XCTAssertEqual(GraphQLBoolean.parseValue(false), false)

        try XCTAssertThrowsError(
            GraphQLBoolean.parseValue(.undefined),
            "Boolean cannot represent a non boolean value: undefined"
        )
        try XCTAssertThrowsError(
            GraphQLBoolean.parseValue(.null),
            "Boolean cannot represent a non boolean value: null"
        )
        // NOTE: We deviate from graphql-js and allow numeric conversions here because
        // the MapCoder's round-trip conversion to NSObject for Bool converts to 0/1 numbers.
        try XCTAssertNoThrow(GraphQLBoolean.parseValue(0))
        try XCTAssertNoThrow(GraphQLBoolean.parseValue(1))
        try XCTAssertNoThrow(GraphQLBoolean.parseValue(.double(Double.nan)))

        try XCTAssertThrowsError(
            GraphQLBoolean.parseValue(""),
            #"Boolean cannot represent a non boolean value: """#
        )
        try XCTAssertThrowsError(
            GraphQLBoolean.parseValue("false"),
            #"Boolean cannot represent a non boolean value: "false""#
        )
        try XCTAssertThrowsError(
            GraphQLBoolean.parseValue([false]),
            "Boolean cannot represent a non boolean value: [false]"
        )
        try XCTAssertThrowsError(
            GraphQLBoolean.parseValue(["value": false]),
            "Boolean cannot represent a non boolean value: { value: false }"
        )
    }

    func testBoolSerialize() throws {
        try XCTAssertEqual(GraphQLBoolean.serialize(1), true)
        try XCTAssertEqual(GraphQLBoolean.serialize(0), false)
        try XCTAssertEqual(GraphQLBoolean.serialize(true), true)
        try XCTAssertEqual(GraphQLBoolean.serialize(false), false)

        try XCTAssertThrowsError(
            GraphQLBoolean.serialize(Double.nan),
            "Boolean cannot represent a non boolean value: NaN"
        )
        try XCTAssertThrowsError(
            GraphQLBoolean.serialize(""),
            #"Boolean cannot represent a non boolean value: """#
        )
        try XCTAssertThrowsError(
            GraphQLBoolean.serialize("true"),
            #"Boolean cannot represent a non boolean value: "true""#
        )
        try XCTAssertThrowsError(
            GraphQLBoolean.serialize([false]),
            "Boolean cannot represent a non boolean value: [false]"
        )
        try XCTAssertThrowsError(
            GraphQLBoolean.serialize {},
            "Boolean cannot represent a non boolean value: {}"
        )
    }

    func testIDParseValue() throws {
        try XCTAssertEqual(GraphQLID.parseValue(""), "")
        try XCTAssertEqual(GraphQLID.parseValue("1"), "1")
        try XCTAssertEqual(GraphQLID.parseValue("foo"), "foo")
        try XCTAssertEqual(GraphQLID.parseValue(1), "1")
        try XCTAssertEqual(GraphQLID.parseValue(0), "0")
        try XCTAssertEqual(GraphQLID.parseValue(-1), "-1")

        // Maximum and minimum safe numbers in JS
        try XCTAssertEqual(GraphQLID.parseValue(9_007_199_254_740_991), "9007199254740991")
        try XCTAssertEqual(GraphQLID.parseValue(-9_007_199_254_740_991), "-9007199254740991")

        try XCTAssertThrowsError(
            GraphQLID.parseValue(.undefined),
            "ID cannot represent value: undefined"
        )
        try XCTAssertThrowsError(
            GraphQLID.parseValue(.null),
            "ID cannot represent value: null"
        )
        try XCTAssertThrowsError(GraphQLID.parseValue(0.1), "ID cannot represent value: 0.1")
        try XCTAssertThrowsError(
            GraphQLID.parseValue(.double(Double.nan)),
            "ID cannot represent value: NaN"
        )
        try XCTAssertThrowsError(
            GraphQLID.parseValue(.double(Double.infinity)),
            "ID cannot represent value: Inf"
        )
        try XCTAssertThrowsError(
            GraphQLID.parseValue(false),
            "ID cannot represent value: false"
        )
        try XCTAssertThrowsError(
            GraphQLID.parseValue(["1"]),
            #"ID cannot represent value: ["1"]"#
        )
        try XCTAssertThrowsError(
            GraphQLID.parseValue(["value": "1"]),
            #"ID cannot represent value: { value: "1" }"#
        )
    }

    func testIDSerialize() throws {
        try XCTAssertEqual(GraphQLID.serialize("string"), "string")
        try XCTAssertEqual(GraphQLID.serialize("false"), "false")
        try XCTAssertEqual(GraphQLID.serialize(""), "")
        try XCTAssertEqual(GraphQLID.serialize(123), "123")
        try XCTAssertEqual(GraphQLID.serialize(0), "0")
        try XCTAssertEqual(GraphQLID.serialize(-1), "-1")

        let badObjValue: Map = [
            "_id": false,
        ]
        try XCTAssertThrowsError(
            GraphQLID.serialize(badObjValue),
            "ID cannot represent value: { _id: false, valueOf: [function valueOf] }"
        )

        try XCTAssertThrowsError(GraphQLID.serialize(true), "ID cannot represent value: true")

        try XCTAssertThrowsError(GraphQLID.serialize(3.14), "ID cannot represent value: 3.14")

        try XCTAssertThrowsError(GraphQLID.serialize {}, "ID cannot represent value: {}")

        try XCTAssertThrowsError(
            GraphQLID.serialize(["abc"]),
            #"ID cannot represent value: ["abc"]"#
        )
    }
}
