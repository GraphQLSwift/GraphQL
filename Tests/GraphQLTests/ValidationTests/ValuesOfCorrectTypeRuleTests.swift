@testable import GraphQL
import XCTest

class ValuesOfCorrectTypeRuleTests: ValidationTestCase {
    override func setUp() {
        rule = ValuesOfCorrectTypeRule
    }

    // MARK: Valid values

    func testGoodIntValue() throws {
        try assertValid(
            """
            {
              complicatedArgs {
                intArgField(intArg: 2)
              }
            }
            """
        )
    }

    func testGoodNegativeIntValue() throws {
        try assertValid(
            """
            {
              complicatedArgs {
                intArgField(intArg: -2)
              }
            }
            """
        )
    }

    func testGoodBooleanValue() throws {
        try assertValid(
            """
            {
              complicatedArgs {
                booleanArgField(booleanArg: true)
              }
            }
            """
        )
    }

    func testGoodStringValue() throws {
        try assertValid(
            """
            {
              complicatedArgs {
                stringArgField(stringArg: "foo")
              }
            }
            """
        )
    }

    func testGoodFloatValue() throws {
        try assertValid(
            """
            {
              complicatedArgs {
                floatArgField(floatArg: 1.1)
              }
            }
            """
        )
    }

    func testGoodNegativeFloatValue() throws {
        try assertValid(
            """
            {
              complicatedArgs {
                floatArgField(floatArg: -1.1)
              }
            }
            """
        )
    }

    func testIntIntoFloat() throws {
        try assertValid(
            """
            {
              complicatedArgs {
                floatArgField(floatArg: 1)
              }
            }
            """
        )
    }

    func testIntIntoID() throws {
        try assertValid(
            """
            {
              complicatedArgs {
                idArgField(idArg: 1)
              }
            }
            """
        )
    }

    func testStringIntoID() throws {
        try assertValid(
            """
            {
              complicatedArgs {
                idArgField(idArg: "someIdString")
              }
            }
            """
        )
    }

    func testGoodEnumValue() throws {
        try assertValid(
            """
            {
              dog {
                doesKnowCommand(dogCommand: SIT)
              }
            }
            """
        )
    }

    func testEnumWithUndefinedValue() throws {
        try assertValid(
            """
            {
              complicatedArgs {
                enumArgField(enumArg: UNKNOWN)
              }
            }
            """
        )
    }

    func testEnumWithNullValue() throws {
        try assertValid(
            """
            {
              complicatedArgs {
                enumArgField(enumArg: NO_FUR)
              }
            }
            """
        )
    }

    func testNullIntoNullableType() throws {
        try assertValid(
            """
            {
              complicatedArgs {
                intArgField(intArg: null)
              }
            }
            """
        )

        try assertValid(
            """
            {
              dog(a: null, b: null, c:{ requiredField: true, intField: null }) {
                name
              }
            }
            """
        )
    }

    // MARK: Invalid String Values

    func testIntIntoString() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            {
              complicatedArgs {
                stringArgField(stringArg: 1)
              }
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [(line: 3, column: 31)],
            message: "String cannot represent a non-string value: 1"
        )
    }

    func testFloatIntoString() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            {
              complicatedArgs {
                stringArgField(stringArg: 1.0)
              }
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [(line: 3, column: 31)],
            message: "String cannot represent a non-string value: 1.0"
        )
    }

    func testBooleanIntoString() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            {
              complicatedArgs {
                stringArgField(stringArg: true)
              }
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [(line: 3, column: 31)],
            message: "String cannot represent a non-string value: true"
        )
    }

    func testUnquotedStringIntoString() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            {
              complicatedArgs {
                stringArgField(stringArg: BAR)
              }
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [(line: 3, column: 31)],
            message: "String cannot represent a non-string value: BAR"
        )
    }

    func testInvalidIntValues() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            {
              complicatedArgs {
                intArgField(intArg: "3")
              }
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [(line: 3, column: 25)],
            message: #"Int cannot represent non-integer value: "3""#
        )
    }

    // Swift doesn't parse BigInt anyway
//    func testBigIntIntoInt() throws {
//        let errors = try assertInvalid(
//            errorCount: 1,
//            query:
//            """
//            {
//              complicatedArgs {
//                intArgField(intArg: 829384293849283498239482938)
//              }
//            }
//            """
//        )
//        try assertValidationError(
//            error: errors[0],
//            locations: [(line: 3, column: 25)],
//            message: "Int cannot represent non-32-bit signed integer value: 829384293849283498239482938"
//        )
//    }

    func testUnquotedStringIntoInt() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            {
              complicatedArgs {
                intArgField(intArg: FOO)
              }
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [(line: 3, column: 25)],
            message: "Int cannot represent non-integer value: FOO"
        )
    }

    func testSimpleFloatIntoInt() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            {
              complicatedArgs {
                intArgField(intArg: 3.0)
              }
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [(line: 3, column: 25)],
            message: "Int cannot represent non-integer value: 3.0"
        )
    }

    func testFloatIntoInt() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            {
              complicatedArgs {
                intArgField(intArg: 3.333)
              }
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [(line: 3, column: 25)],
            message: "Int cannot represent non-integer value: 3.333"
        )
    }

    // MARK: Invalid Float Values

    func testStringIntoFloat() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            {
              complicatedArgs {
                floatArgField(floatArg: "3.333")
              }
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [(line: 3, column: 29)],
            message: #"Float cannot represent non-numeric value: "3.333""#
        )
    }

    func testBooleanIntoFloat() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            {
              complicatedArgs {
                floatArgField(floatArg: true)
              }
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [(line: 3, column: 29)],
            message: "Float cannot represent non-numeric value: true"
        )
    }

    func testUnquotedIntoFloat() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            {
              complicatedArgs {
                floatArgField(floatArg: FOO)
              }
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [(line: 3, column: 29)],
            message: "Float cannot represent non-numeric value: FOO"
        )
    }

    // MARK: Invalid Boolean Value

    func testIntIntoBoolean() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            {
              complicatedArgs {
                booleanArgField(booleanArg: 2)
              }
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [(line: 3, column: 33)],
            message: "Boolean cannot represent a non-boolean value: 2"
        )
    }

    func testFloatIntoBoolean() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            {
              complicatedArgs {
                booleanArgField(booleanArg: 1.0)
              }
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [(line: 3, column: 33)],
            message: "Boolean cannot represent a non-boolean value: 1.0"
        )
    }

    func testStringIntoBoolean() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            {
              complicatedArgs {
                booleanArgField(booleanArg: "true")
              }
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [(line: 3, column: 33)],
            message: #"Boolean cannot represent a non-boolean value: "true""#
        )
    }

    func testUnquotedIntoBoolean() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            {
              complicatedArgs {
                booleanArgField(booleanArg: TRUE)
              }
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [(line: 3, column: 33)],
            message: "Boolean cannot represent a non-boolean value: TRUE"
        )
    }

    // MARK: Invalid ID Value

    func testFloatIntoID() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            {
              complicatedArgs {
                idArgField(idArg: 1.0)
              }
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [(line: 3, column: 23)],
            message: "ID cannot represent a non-string and non-integer value: 1.0"
        )
    }

    func testBooleanIntoID() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            {
              complicatedArgs {
                idArgField(idArg: true)
              }
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [(line: 3, column: 23)],
            message: "ID cannot represent a non-string and non-integer value: true"
        )
    }

    func testUnquotedIntoID() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            {
              complicatedArgs {
                idArgField(idArg: SOMETHING)
              }
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [(line: 3, column: 23)],
            message: "ID cannot represent a non-string and non-integer value: SOMETHING"
        )
    }

    // MARK: Invalid Enum Value

    func testIntIntoEnum() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            {
              dog {
                doesKnowCommand(dogCommand: 2)
              }
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [(line: 3, column: 33)],
            message: #"Enum "DogCommand" cannot represent non-enum value: 2."#
        )
    }

    func testFloatIntoEnum() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            {
              dog {
                doesKnowCommand(dogCommand: 1.0)
              }
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [(line: 3, column: 33)],
            message: #"Enum "DogCommand" cannot represent non-enum value: 1.0."#
        )
    }

    func testStringIntoEnum() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            {
              dog {
                doesKnowCommand(dogCommand: "SIT")
              }
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [(line: 3, column: 33)],
            message: #"Enum "DogCommand" cannot represent non-enum value: "SIT". Did you mean the enum value "SIT"?"#
        )
    }

    func testBooleanIntoEnum() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            {
              dog {
                doesKnowCommand(dogCommand: true)
              }
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [(line: 3, column: 33)],
            message: #"Enum "DogCommand" cannot represent non-enum value: true."#
        )
    }

    func testUnknownEnumValueIntoEnum() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            {
              dog {
                doesKnowCommand(dogCommand: JUGGLE)
              }
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [(line: 3, column: 33)],
            message: #"Value "JUGGLE" does not exist in "DogCommand" enum."#
        )
    }

    func testDifferentCaseEnumValueIntoEnum() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            {
              dog {
                doesKnowCommand(dogCommand: sit)
              }
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [(line: 3, column: 33)],
            message: #"Value "sit" does not exist in "DogCommand" enum."#
        )
    }

    // MARK: Valid List Value

    func testGoodListValue() throws {
        try assertValid(
            """
            {
              complicatedArgs {
                stringListArgField(stringListArg: ["one", null, "two"])
              }
            }
            """
        )
    }

    func testEmptyListValue() throws {
        try assertValid(
            """
            {
              complicatedArgs {
                stringListArgField(stringListArg: [])
              }
            }
            """
        )
    }

    func testNullValueIntoList() throws {
        try assertValid(
            """
            {
              complicatedArgs {
                stringListArgField(stringListArg: null)
              }
            }
            """
        )
    }

    func testSingleValueIntoList() throws {
        try assertValid(
            """
            {
              complicatedArgs {
                stringListArgField(stringListArg: "one")
              }
            }
            """
        )
    }

    // MARK: Invalid List Value

    func testIncorrectItemType() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            {
              complicatedArgs {
                stringListArgField(stringListArg: ["one", 2])
              }
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [(line: 3, column: 47)],
            message: "String cannot represent a non-string value: 2"
        )
    }

    func testSingleValueOfIncorrectType() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            {
              complicatedArgs {
                stringListArgField(stringListArg: 1)
              }
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [(line: 3, column: 39)],
            message: "String cannot represent a non-string value: 1"
        )
    }

    // MARK: Valid Non-Nullable Value

    func testArgOnOptionalArg() throws {
        try assertValid(
            """
            {
              dog {
                isHouseTrained(atOtherHomes: true)
              }
            }
            """
        )
    }

    func testNoArgOnOptionalArg() throws {
        try assertValid(
            """
            {
              dog {
                isHouseTrained
              }
            }
            """
        )
    }

    func testMultipleArgs() throws {
        try assertValid(
            """
            {
              complicatedArgs {
                multipleReqs(req1: 1, req2: 2)
              }
            }
            """
        )
    }

    func testMultipleArgsReverseOrder() throws {
        try assertValid(
            """
            {
              complicatedArgs {
                multipleReqs(req2: 2, req1: 1)
              }
            }
            """
        )
    }

    func testNoArgsOnMultipleOptional() throws {
        try assertValid(
            """
            {
              complicatedArgs {
                multipleOpts
              }
            }
            """
        )
    }

    func testOneArgOnMultipleOptional() throws {
        try assertValid(
            """
            {
              complicatedArgs {
                multipleOpts(opt1: 1)
              }
            }
            """
        )
    }

    func testSecondArgOnMultipleOptional() throws {
        try assertValid(
            """
            {
              complicatedArgs {
                multipleOpts(opt2: 1)
              }
            }
            """
        )
    }

    func testMultipleRequiredArgsOnMixedList() throws {
        try assertValid(
            """
            {
              complicatedArgs {
                multipleOptAndReq(req1: 3, req2: 4)
              }
            }
            """
        )
    }

    func testMultipleRequiredAndOneOptionalArgOnMixedList() throws {
        try assertValid(
            """
            {
              complicatedArgs {
                multipleOptAndReq(req1: 3, req2: 4, opt1: 5)
              }
            }
            """
        )
    }

    func testAllRequiredAndOptionalArgsOnMixedList() throws {
        try assertValid(
            """
            {
              complicatedArgs {
                multipleOptAndReq(req1: 3, req2: 4, opt1: 5, opt2: 6)
              }
            }
            """
        )
    }

    // MARK: Invalid Non-Nullable Value

    func testIncorrectValueType() throws {
        let errors = try assertInvalid(
            errorCount: 2,
            query:
            """
            {
              complicatedArgs {
                multipleReqs(req2: "two", req1: "one")
              }
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [(line: 3, column: 24)],
            message: #"Int cannot represent non-integer value: "two""#
        )
        try assertValidationError(
            error: errors[1],
            locations: [(line: 3, column: 37)],
            message: #"Int cannot represent non-integer value: "one""#
        )
    }

    func testIncorrectValueAndMissingArgument() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            {
              complicatedArgs {
                multipleReqs(req1: "one")
              }
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [(line: 3, column: 24)],
            message: #"Int cannot represent non-integer value: "one""#
        )
    }

    func testNullValue() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            {
              complicatedArgs {
                multipleReqs(req1: null)
              }
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [(line: 3, column: 24)],
            message: #"Expected value of type "Int!", found null."#
        )
    }

    // MARK: Valid Input Object Value

    func testOptionalArgDespiteRequiredFieldInType() throws {
        try assertValid(
            """
            {
              complicatedArgs {
                complexArgField
              }
            }
            """
        )
    }

    func testPartialObjectOnlyRequired() throws {
        try assertValid(
            """
            {
              complicatedArgs {
                complexArgField(complexArg: { requiredField: true })
              }
            }
            """
        )
    }

    func testPartialObjectRequiredFieldCanBeFalsy() throws {
        try assertValid(
            """
            {
              complicatedArgs {
                complexArgField(complexArg: { requiredField: false })
              }
            }
            """
        )
    }

    func testPartialObjectIncludingRequired() throws {
        try assertValid(
            """
            {
              complicatedArgs {
                complexArgField(complexArg: { requiredField: true, intField: 4 })
              }
            }
            """
        )
    }

    func testFullObject() throws {
        try assertValid(
            """
            {
              complicatedArgs {
                complexArgField(complexArg: {
                  requiredField: true,
                  intField: 4,
                  stringField: "foo",
                  booleanField: false,
                  stringListField: ["one", "two"]
                })
              }
            }
            """
        )
    }

    func testFullObjectWithFieldsInDifferentOrder() throws {
        try assertValid(
            """
            {
              complicatedArgs {
                complexArgField(complexArg: {
                  stringListField: ["one", "two"],
                  booleanField: false,
                  requiredField: true,
                  stringField: "foo",
                  intField: 4,
                })
              }
            }
            """
        )
    }

    // MARK: Valid oneOf Object Value

//    func testExactlyOneField() throws {
//        try assertValid(
//            """
//            {
//              complicatedArgs {
//                oneOfArgField(oneOfArg: { stringField: "abc" })
//              }
//            }
//            """
//        )
//    }

    // MARK: Invalid input object value

    func testPartialObjectMissingRequired() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            {
              complicatedArgs {
                complexArgField(complexArg: { intField: 4 })
              }
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [(line: 3, column: 33)],
            message: #"Field "ComplexInput.requiredField" of required type "Boolean!" was not provided."#
        )
    }

    func testPartialObjectInvalidFieldType() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            {
              complicatedArgs {
                complexArgField(complexArg: {
                  stringListField: ["one", 2],
                  requiredField: true,
                })
              }
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [(line: 4, column: 32)],
            message: #"String cannot represent a non-string value: 2"#
        )
    }

    func testPartialObjectNullToNonNullField() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            {
              complicatedArgs {
                complexArgField(complexArg: {
                  requiredField: true,
                  nonNullField: null,
                })
              }
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [(line: 5, column: 21)],
            message: #"Expected value of type "Boolean!", found null."#
        )
    }

    func testPartialObjectUnknownFieldArg() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            {
              complicatedArgs {
                complexArgField(complexArg: {
                  requiredField: true,
                  invalidField: "value"
                })
              }
            }
            """
        )
        try assertValidationError(
            error: errors[0],
            locations: [(line: 5, column: 7)],
            message: #"Field "invalidField" is not defined by type "ComplexInput". Did you mean "intField" or "nonNullField"?"#
        )
    }

    func testReportsOriginalErrorForCustomScalarWhichThrows() throws {
        let customScalar = try GraphQLScalarType(
            name: "Invalid",
            serialize: { _ in
                true
            },
            parseValue: { value in
                throw GraphQLError(
                    message: "Invalid scalar is always invalid: \(value)"
                )
            },
            parseLiteral: { value in
                throw GraphQLError(
                    message: "Invalid scalar is always invalid: \(print(ast: value))"
                )
            }
        )

        let schema = try! GraphQLSchema(
            query: GraphQLObjectType(
                name: "Query",
                fields: [
                    "invalidArg": GraphQLField(
                        type: GraphQLString,
                        args: [
                            "arg": GraphQLArgument(type: customScalar),
                        ]
                    ),
                ]
            )
        )

        let doc = try parse(source: "{ invalidArg(arg: 123) }")
        let errors = validate(schema: schema, ast: doc, rules: [ValuesOfCorrectTypeRule])

        try assertValidationError(
            error: errors[0],
            locations: [(line: 1, column: 19)],
            message: #"Invalid scalar is always invalid: 123"#
        )
    }

    func testReportsOriginalErrorForCustomScalarThatReturnsUndefined() throws {
        let customScalar = try GraphQLScalarType(
            name: "CustomScalar",
            serialize: { _ in
                .undefined
            },
            parseValue: { _ in
                .undefined
            },
            parseLiteral: { _ in
                .undefined
            }
        )

        let schema = try! GraphQLSchema(
            query: GraphQLObjectType(
                name: "Query",
                fields: [
                    "invalidArg": GraphQLField(
                        type: GraphQLString,
                        args: [
                            "arg": GraphQLArgument(type: customScalar),
                        ]
                    ),
                ]
            )
        )

        let doc = try parse(source: "{ invalidArg(arg: 123) }")
        let errors = validate(schema: schema, ast: doc, rules: [ValuesOfCorrectTypeRule])

        try assertValidationError(
            error: errors[0],
            locations: [(line: 1, column: 19)],
            message: #"Expected value of type "CustomScalar", found 123."#
        )
    }

    func testAllowsCustomScalarToAcceptComplexLiterals() throws {
        let customScalar = try GraphQLScalarType(
            name: "Any",
            serialize: { value in
                try Map(any: value)
            }
        )

        let schema = try! GraphQLSchema(
            query: GraphQLObjectType(
                name: "Query",
                fields: [
                    "anyArg": GraphQLField(
                        type: GraphQLString,
                        args: [
                            "arg": GraphQLArgument(type: customScalar),
                        ]
                    ),
                ]
            ),
            types: [
                customScalar,
            ]
        )

        let doc = try parse(source: """
        {
          test1: anyArg(arg: 123)
          test2: anyArg(arg: "abc")
          test3: anyArg(arg: [123, "abc"])
          test4: anyArg(arg: {deep: [123, "abc"]})
        }
        """)
        let errors = validate(schema: schema, ast: doc, rules: [ValuesOfCorrectTypeRule])
        XCTAssertEqual(errors, [])
    }

    // MARK: Invalid oneOf input object value TODO

    // MARK: Directive arguments

    func testWithDirectivesOfValidTypes() throws {
        try assertValid(
            """
            {
              dog @include(if: true) {
                name
              }
              human @skip(if: false) {
                name
              }
            }
            """
        )
    }

    func testWithDirectiveWithIncorrectTypes() throws {
        let errors = try assertInvalid(
            errorCount: 2,
            query:
            """
            {
              dog @include(if: "yes") {
                name @skip(if: ENUM)
              }
            }
            """
        )

        try assertValidationError(
            error: errors[0],
            locations: [(line: 2, column: 20)],
            message: #"Boolean cannot represent a non-boolean value: "yes""#
        )

        try assertValidationError(
            error: errors[1],
            locations: [(line: 3, column: 20)],
            message: #"Boolean cannot represent a non-boolean value: ENUM"#
        )
    }

    // MARK: Variable default values

    func testVariablesWithValidDefaultValues() throws {
        try assertValid(
            """
            query WithDefaultValues(
              $a: Int = 1,
              $b: String = "ok",
              $c: ComplexInput = { requiredField: true, intField: 3 }
              $d: Int! = 123
            ) {
              dog { name }
            }
            """
        )
    }

    func testVariablesWithValidDefaultNullValues() throws {
        try assertValid(
            """
            query WithDefaultValues(
              $a: Int = null,
              $b: String = null,
              $c: ComplexInput = { requiredField: true, intField: null }
            ) {
              dog { name }
            }
            """
        )
    }

    func testVariablesWithInvalidDefaultNullValues() throws {
        let errors = try assertInvalid(
            errorCount: 3,
            query:
            """
            query WithDefaultValues(
              $a: Int! = null,
              $b: String! = null,
              $c: ComplexInput = { requiredField: null, intField: null }
            ) {
              dog { name }
            }
            """
        )

        try assertValidationError(
            error: errors[0],
            locations: [(line: 2, column: 14)],
            message: #"Expected value of type "Int!", found null."#
        )

        try assertValidationError(
            error: errors[1],
            locations: [(line: 3, column: 17)],
            message: #"Expected value of type "String!", found null."#
        )

        try assertValidationError(
            error: errors[2],
            locations: [(line: 4, column: 39)],
            message: #"Expected value of type "Boolean!", found null."#
        )
    }

    func testVariablesWithInvalidDefaultValues() throws {
        let errors = try assertInvalid(
            errorCount: 3,
            query:
            """
            query InvalidDefaultValues(
              $a: Int = "one",
              $b: String = 4,
              $c: ComplexInput = "NotVeryComplex"
            ) {
              dog { name }
            }
            """
        )

        try assertValidationError(
            error: errors[0],
            locations: [(line: 2, column: 13)],
            message: #"Int cannot represent non-integer value: "one""#
        )

        try assertValidationError(
            error: errors[1],
            locations: [(line: 3, column: 16)],
            message: #"String cannot represent a non-string value: 4"#
        )

        try assertValidationError(
            error: errors[2],
            locations: [(line: 4, column: 22)],
            message: #"Expected value of type "ComplexInput", found "NotVeryComplex"."#
        )
    }

    func testVariablesWithComplexInvalidDefaultValues() throws {
        let errors = try assertInvalid(
            errorCount: 2,
            query:
            """
            query WithDefaultValues(
              $a: ComplexInput = { requiredField: 123, intField: "abc" }
            ) {
              dog { name }
            }
            """
        )

        try assertValidationError(
            error: errors[0],
            locations: [(line: 2, column: 39)],
            message: #"Boolean cannot represent a non-boolean value: 123"#
        )

        try assertValidationError(
            error: errors[1],
            locations: [(line: 2, column: 54)],
            message: #"Int cannot represent non-integer value: "abc""#
        )
    }

    func testComplexVariableMissingRequiredField() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            query MissingRequiredField($a: ComplexInput = {intField: 3}) {
              dog { name }
            }
            """
        )

        try assertValidationError(
            error: errors[0],
            locations: [(line: 1, column: 47)],
            message: #"Field "ComplexInput.requiredField" of required type "Boolean!" was not provided."#
        )
    }

    func testListVariablesWithInvalidItem() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            query InvalidItem($a: [String] = ["one", 2]) {
              dog { name }
            }
            """
        )

        try assertValidationError(
            error: errors[0],
            locations: [(line: 1, column: 42)],
            message: #"String cannot represent a non-string value: 2"#
        )
    }
}
