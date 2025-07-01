@testable import GraphQL
import Testing

@Suite struct ScalarTests {
    @Test func testIntParseValue() throws {
        try #expect(GraphQLInt.parseValue(1) == 1)
        try #expect(GraphQLInt.parseValue(0) == 0)
        try #expect(GraphQLInt.parseValue(-1) == -1)

        #expect(
            throws: (any Error).self,
            "Int cannot represent non 32-bit signed integer value: 9876504321"
        ) {
            try GraphQLInt.parseValue(9_876_504_321)
        }
        #expect(
            throws: (any Error).self,
            "Int cannot represent non 32-bit signed integer value: -9876504321"
        ) {
            try GraphQLInt.parseValue(-9_876_504_321)
        }
        // TODO: Avoid rounding these
//        #expect(
//            throws: (any Error).self,
//            "Int cannot represent non-integer value: 0.1"
//        ) {
//            try GraphQLInt.parseValue(0.1)
//        }
        #expect(
            throws: (any Error).self,
            "Int cannot represent non-integer value: NaN"
        ) {
            try GraphQLInt.parseValue(.double(Double.nan))
        }
        #expect(
            throws: (any Error).self,
            "Int cannot represent non-integer value: Infinity"
        ) {
            try GraphQLInt.parseValue(.double(Double.infinity))
        }

        #expect(
            throws: (any Error).self,
            "Int cannot represent non-integer value: undefined"
        ) {
            try GraphQLInt.parseValue(.undefined)
        }
        #expect(
            throws: (any Error).self,
            "Int cannot represent non-integer value: null"
        ) {
            try GraphQLInt.parseValue(.null)
        }
        #expect(
            throws: (any Error).self,
            #"Int cannot represent non-integer value: """#
        ) {
            try GraphQLInt.parseValue("")
        }
        #expect(
            throws: (any Error).self,
            #"Int cannot represent non-integer value: "123""#
        ) {
            try GraphQLInt.parseValue("123")
        }
        #expect(
            throws: (any Error).self,
            "Int cannot represent non-integer value: false"
        ) {
            try GraphQLInt.parseValue(false)
        }
        #expect(
            throws: (any Error).self,
            "Int cannot represent non-integer value: true"
        ) {
            try GraphQLInt.parseValue(true)
        }
        #expect(
            throws: (any Error).self,
            "Int cannot represent non-integer value: [1]"
        ) {
            try GraphQLInt.parseValue([1])
        }
        #expect(
            throws: (any Error).self,
            "Int cannot represent non-integer value: { value: 1 }"
        ) {
            try GraphQLInt.parseValue(["value": 1])
        }
    }

    @Test func testIntSerialize() throws {
        try #expect(GraphQLInt.serialize(1) == 1)
        try #expect(GraphQLInt.serialize("123") == 123)
        try #expect(GraphQLInt.serialize(0) == 0)
        try #expect(GraphQLInt.serialize(-1) == -1)
        try #expect(GraphQLInt.serialize(1e5) == 100_000)
        try #expect(GraphQLInt.serialize(false) == 0)
        try #expect(GraphQLInt.serialize(true) == 1)

        // The GraphQL specification does not allow serializing non-integer values
        // as Int to avoid accidental data loss.
        // TODO: Avoid rounding these
//        #expect(
//            throws: (any Error).self,
//            "Int cannot represent non-integer value: 0.1"
//        ) {
//            try GraphQLInt.serialize(0.1)
//        }
//        #expect(
//            throws: (any Error).self,
//            "Int cannot represent non-integer value: 1.1"
//        ) {
//            try GraphQLInt.serialize(1.1)
//        }
//        #expect(
//            throws: (any Error).self,
//            "Int cannot represent non-integer value: -1.1"
//        ) {
//            try GraphQLInt.serialize(-1.1)
//        }
        #expect(
            throws: (any Error).self,
            #"Int cannot represent non-integer value: "-1.1""#
        ) {
            try GraphQLInt.serialize("-1.1")
        }

        // Maybe a safe JavaScript int, but bigger than 2^32, so not
        // representable as a GraphQL Int
        #expect(
            throws: (any Error).self,
            "Int cannot represent non 32-bit signed integer value: 9876504321"
        ) {
            try GraphQLInt.serialize(9_876_504_321)
        }
        #expect(
            throws: (any Error).self,
            "Int cannot represent non 32-bit signed integer value: -9876504321"
        ) {
            try GraphQLInt.serialize(-9_876_504_321)
        }

        // Too big to represent as an Int in JavaScript or GraphQL
        #expect(
            throws: (any Error).self,
            "Int cannot represent non 32-bit signed integer value: 1e+100"
        ) {
            try GraphQLInt.serialize(1e100)
        }
        #expect(
            throws: (any Error).self,
            "Int cannot represent non 32-bit signed integer value: -1e+100"
        ) {
            try GraphQLInt.serialize(-1e100)
        }
        #expect(
            throws: (any Error).self,
            #"Int cannot represent non-integer value: "one""#
        ) {
            try GraphQLInt.serialize("one")
        }

        // Doesn"t represent number
        #expect(
            throws: (any Error).self,
            #"Int cannot represent non-integer value: """#
        ) {
            try GraphQLInt.serialize("")
        }
        #expect(
            throws: (any Error).self,
            "Int cannot represent non-integer value: NaN"
        ) {
            try GraphQLInt.serialize(Double.nan)
        }
        #expect(
            throws: (any Error).self,
            "Int cannot represent non-integer value: Infinity"
        ) {
            try GraphQLInt.serialize(Double.infinity)
        }
        #expect(
            throws: (any Error).self,
            "Int cannot represent non-integer value: [5]"
        ) {
            try GraphQLInt.serialize([5])
        }
    }

    @Test func testFloatParseValue() throws {
        try #expect(GraphQLFloat.parseValue(1) == 1)
        try #expect(GraphQLFloat.parseValue(0) == 0)
        try #expect(GraphQLFloat.parseValue(-1) == -1)
        try #expect(GraphQLFloat.parseValue(0.1) == 0.1)
        try #expect(GraphQLFloat.parseValue(.double(Double.pi)) == .double(Double.pi))

        #expect(
            throws: (any Error).self,
            "Float cannot represent non numeric value: NaN"
        ) {
            try GraphQLFloat.parseValue(.double(Double.nan))
        }
        #expect(
            throws: (any Error).self,
            "Float cannot represent non numeric value: Infinity"
        ) {
            try GraphQLFloat.parseValue(.double(Double.infinity))
        }

        #expect(
            throws: (any Error).self,
            "Float cannot represent non numeric value: undefined"
        ) {
            try GraphQLFloat.parseValue(.undefined)
        }
        #expect(
            throws: (any Error).self,
            "Float cannot represent non numeric value: null"
        ) {
            try GraphQLFloat.parseValue(.null)
        }
        #expect(
            throws: (any Error).self,
            #"Float cannot represent non numeric value: """#
        ) {
            try GraphQLFloat.parseValue("")
        }
        #expect(
            throws: (any Error).self,
            #"Float cannot represent non numeric value: "123""#
        ) {
            try GraphQLFloat.parseValue("123")
        }
        #expect(
            throws: (any Error).self,
            #"Float cannot represent non numeric value: "123.5""#
        ) {
            try GraphQLFloat.parseValue("123.5")
        }
        #expect(
            throws: (any Error).self,
            "Float cannot represent non numeric value: false"
        ) {
            try GraphQLFloat.parseValue(false)
        }
        #expect(
            throws: (any Error).self,
            "Float cannot represent non numeric value: true"
        ) {
            try GraphQLFloat.parseValue(true)
        }
        #expect(
            throws: (any Error).self,
            "Float cannot represent non numeric value: [0.1]"
        ) {
            try GraphQLFloat.parseValue([0.1])
        }
        #expect(
            throws: (any Error).self,
            "Float cannot represent non numeric value: { value: 0.1 }"
        ) {
            try GraphQLFloat.parseValue(["value": 0.1])
        }
    }

    @Test func testFloatSerialize() throws {
        try #expect(GraphQLFloat.serialize(1) == 1.0)
        try #expect(GraphQLFloat.serialize(0) == 0.0)
        try #expect(GraphQLFloat.serialize("123.5") == 123.5)
        try #expect(GraphQLFloat.serialize(-1) == -1.0)
        try #expect(GraphQLFloat.serialize(0.1) == 0.1)
        try #expect(GraphQLFloat.serialize(1.1) == 1.1)
        try #expect(GraphQLFloat.serialize(-1.1) == -1.1)
        try #expect(GraphQLFloat.serialize("-1.1") == -1.1)
        try #expect(GraphQLFloat.serialize(false) == 0.0)
        try #expect(GraphQLFloat.serialize(true) == 1.0)

        #expect(
            throws: (any Error).self,
            "Float cannot represent non numeric value: NaN"
        ) {
            try GraphQLFloat.serialize(Double.nan)
        }
        #expect(
            throws: (any Error).self,
            "Float cannot represent non numeric value: Inf"
        ) {
            try GraphQLFloat.serialize(Double.infinity)
        }
        #expect(
            throws: (any Error).self,
            #"Float cannot represent non numeric value: "one""#
        ) {
            try GraphQLFloat.serialize("one")
        }
        #expect(
            throws: (any Error).self,
            #"Float cannot represent non numeric value: """#
        ) {
            try GraphQLFloat.serialize("")
        }
        #expect(
            throws: (any Error).self,
            "Float cannot represent non numeric value: [5]"
        ) {
            try GraphQLFloat.serialize([5])
        }
    }

    @Test func testStringParseValue() throws {
        try #expect(GraphQLString.parseValue("foo") == "foo")

        #expect(
            throws: (any Error).self,
            "String cannot represent a non string value: undefined"
        ) {
            try GraphQLString.parseValue(.undefined)
        }
        #expect(
            throws: (any Error).self,
            "String cannot represent a non string value: null"
        ) {
            try GraphQLString.parseValue(.null)
        }
        #expect(
            throws: (any Error).self,
            "String cannot represent a non string value: 1"
        ) {
            try GraphQLString.parseValue(1)
        }
        #expect(
            throws: (any Error).self,
            "String cannot represent a non string value: NaN"
        ) {
            try GraphQLString.parseValue(.double(Double.nan))
        }
        #expect(
            throws: (any Error).self,
            "String cannot represent a non string value: false"
        ) {
            try GraphQLString.parseValue(false)
        }
        #expect(
            throws: (any Error).self,
            #"String cannot represent a non string value: ["foo"]"#
        ) {
            try GraphQLString.parseValue(["foo"])
        }
        #expect(
            throws: (any Error).self,
            #"String cannot represent a non string value: { value: "foo" }"#
        ) {
            try GraphQLString.parseValue(["value": "foo"])
        }
    }

    @Test func testStringSerialize() throws {
        try #expect(GraphQLString.serialize("string") == "string")
        try #expect(GraphQLString.serialize(1) == "1")
        try #expect(GraphQLString.serialize(-1.1) == "-1.1")
        try #expect(GraphQLString.serialize(true) == "true")
        try #expect(GraphQLString.serialize(false) == "false")

        #expect(
            throws: (any Error).self,
            "String cannot represent value: NaN"
        ) {
            try GraphQLString.serialize(Double.nan)
        }

        #expect(
            throws: (any Error).self,
            "String cannot represent value: [1]"
        ) {
            try GraphQLString.serialize([1])
        }

        let badObjValue: Map = [:]
        #expect(
            throws: (any Error).self,
            "String cannot represent value: {}"
        ) {
            try GraphQLString.serialize(badObjValue)
        }

        let badValueOfObjValue: Map = ["valueOf": "valueOf string"]
        #expect(
            throws: (any Error).self,
            #"String cannot represent value: { valueOf: "valueOf string" }"#
        ) {
            try GraphQLString.serialize(badValueOfObjValue)
        }
    }

    @Test func testBoolParseValue() throws {
        try #expect(GraphQLBoolean.parseValue(true) == true)
        try #expect(GraphQLBoolean.parseValue(false) == false)

        #expect(
            throws: (any Error).self,
            "Boolean cannot represent a non boolean value: undefined"
        ) {
            try GraphQLBoolean.parseValue(.undefined)
        }
        #expect(
            throws: (any Error).self,
            "Boolean cannot represent a non boolean value: null"
        ) {
            try GraphQLBoolean.parseValue(.null)
        }
        // NOTE: We deviate from graphql-js and allow numeric conversions here because
        // the MapCoder's round-trip conversion to NSObject for Bool converts to 0/1 numbers.
        #expect(throws: Never.self) { try GraphQLBoolean.parseValue(0) }
        #expect(throws: Never.self) { try GraphQLBoolean.parseValue(1) }
        #expect(throws: Never.self) { try GraphQLBoolean.parseValue(.double(Double.nan)) }

        #expect(
            throws: (any Error).self,
            #"Boolean cannot represent a non boolean value: """#
        ) {
            try GraphQLBoolean.parseValue("")
        }
        #expect(
            throws: (any Error).self,
            #"Boolean cannot represent a non boolean value: "false""#
        ) {
            try GraphQLBoolean.parseValue("false")
        }
        #expect(
            throws: (any Error).self,
            "Boolean cannot represent a non boolean value: [false]"
        ) {
            try GraphQLBoolean.parseValue([false])
        }
        #expect(
            throws: (any Error).self,
            "Boolean cannot represent a non boolean value: { value: false }"
        ) {
            try GraphQLBoolean.parseValue(["value": false])
        }
    }

    @Test func testBoolSerialize() throws {
        try #expect(GraphQLBoolean.serialize(1) == true)
        try #expect(GraphQLBoolean.serialize(0) == false)
        try #expect(GraphQLBoolean.serialize(true) == true)
        try #expect(GraphQLBoolean.serialize(false) == false)

        #expect(
            throws: (any Error).self,
            "Boolean cannot represent a non boolean value: NaN"
        ) {
            try GraphQLBoolean.serialize(Double.nan)
        }
        #expect(
            throws: (any Error).self,
            #"Boolean cannot represent a non boolean value: """#
        ) {
            try GraphQLBoolean.serialize("")
        }
        #expect(
            throws: (any Error).self,
            #"Boolean cannot represent a non boolean value: "true""#
        ) {
            try GraphQLBoolean.serialize("true")
        }
        #expect(
            throws: (any Error).self,
            "Boolean cannot represent a non boolean value: [false]"
        ) {
            try GraphQLBoolean.serialize([false])
        }
        #expect(
            throws: (any Error).self,
            "Boolean cannot represent a non boolean value: {}"
        ) {
            try GraphQLBoolean.serialize {}
        }
    }

    @Test func testIDParseValue() throws {
        try #expect(GraphQLID.parseValue("") == "")
        try #expect(GraphQLID.parseValue("1") == "1")
        try #expect(GraphQLID.parseValue("foo") == "foo")
        try #expect(GraphQLID.parseValue(1) == "1")
        try #expect(GraphQLID.parseValue(0) == "0")
        try #expect(GraphQLID.parseValue(-1) == "-1")

        // Maximum and minimum safe numbers in JS
        try #expect(GraphQLID.parseValue(9_007_199_254_740_991) == "9007199254740991")
        try #expect(GraphQLID.parseValue(-9_007_199_254_740_991) == "-9007199254740991")

        #expect(
            throws: (any Error).self,
            "ID cannot represent value: undefined"
        ) {
            try GraphQLID.parseValue(.undefined)
        }

        #expect(
            throws: (any Error).self,
            "ID cannot represent value: null"
        ) {
            try GraphQLID.parseValue(.null)
        }

        #expect(
            throws: (any Error).self,
            "ID cannot represent value: 0.1"
        ) { try GraphQLID.parseValue(0.1) }

        #expect(
            throws: (any Error).self,
            "ID cannot represent value: NaN"
        ) {
            try GraphQLID.parseValue(.double(Double.nan))
        }

        #expect(
            throws: (any Error).self,
            "ID cannot represent value: Inf"
        ) {
            try GraphQLID.parseValue(.double(Double.infinity))
        }

        #expect(
            throws: (any Error).self,
            "ID cannot represent value: false"
        ) {
            try GraphQLID.parseValue(false)
        }

        #expect(
            throws: (any Error).self,
            #"ID cannot represent value: ["1"]"#
        ) {
            try GraphQLID.parseValue(["1"])
        }

        #expect(
            throws: (any Error).self,
            #"ID cannot represent value: { "value": "1" }"#
        ) {
            try GraphQLID.parseValue(["value": "1"])
        }
    }

    @Test func testIDSerialize() throws {
        try #expect(GraphQLID.serialize("string") == "string")
        try #expect(GraphQLID.serialize("false") == "false")
        try #expect(GraphQLID.serialize("") == "")
        try #expect(GraphQLID.serialize(123) == "123")
        try #expect(GraphQLID.serialize(0) == "0")
        try #expect(GraphQLID.serialize(-1) == "-1")

        let badObjValue: Map = [
            "_id": false,
        ]
        #expect(
            throws: (any Error).self,
            "ID cannot represent value: { _id: false, valueOf: [function valueOf] }"
        ) {
            try GraphQLID.serialize(badObjValue)
        }

        #expect(
            throws: (any Error).self,
            "ID cannot represent value: true"
        ) { try GraphQLID.serialize(true) }

        #expect(
            throws: (any Error).self,
            "ID cannot represent value: 3.14"
        ) { try GraphQLID.serialize(3.14) }

        #expect(
            throws: (any Error).self,
            "ID cannot represent value: {}"
        ) { try GraphQLID.serialize {} }

        #expect(
            throws: (any Error).self,
            #"ID cannot represent value: ["abc"]"#
        ) { try GraphQLID.serialize(["abc"]) }
    }
}
