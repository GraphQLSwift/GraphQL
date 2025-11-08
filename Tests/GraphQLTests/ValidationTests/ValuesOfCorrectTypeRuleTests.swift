@testable import GraphQL
import Testing

class ValuesOfCorrectTypeRuleTests: ValidationTestCase {
    override init() {
        super.init()
        rule = ValuesOfCorrectTypeRule
    }

    // MARK: Valid values

    @Test func goodIntValue() throws {
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

    @Test func goodNegativeIntValue() throws {
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

    @Test func goodBooleanValue() throws {
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

    @Test func goodStringValue() throws {
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

    @Test func goodFloatValue() throws {
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

    @Test func goodNegativeFloatValue() throws {
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

    @Test func intIntoFloat() throws {
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

    @Test func intIntoID() throws {
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

    @Test func stringIntoID() throws {
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

    @Test func goodEnumValue() throws {
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

    @Test func enumWithUndefinedValue() throws {
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

    @Test func enumWithNullValue() throws {
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

    @Test func nullIntoNullableType() throws {
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

    @Test func intIntoString() throws {
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

    @Test func floatIntoString() throws {
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

    @Test func booleanIntoString() throws {
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

    @Test func unquotedStringIntoString() throws {
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

    @Test func invalidIntValues() throws {
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
//    @Test func bigIntIntoInt() throws {
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

    @Test func unquotedStringIntoInt() throws {
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

    @Test func simpleFloatIntoInt() throws {
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

    @Test func floatIntoInt() throws {
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

    @Test func stringIntoFloat() throws {
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

    @Test func booleanIntoFloat() throws {
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

    @Test func unquotedIntoFloat() throws {
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

    @Test func intIntoBoolean() throws {
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

    @Test func floatIntoBoolean() throws {
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

    @Test func stringIntoBoolean() throws {
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

    @Test func unquotedIntoBoolean() throws {
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

    @Test func floatIntoID() throws {
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

    @Test func booleanIntoID() throws {
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

    @Test func unquotedIntoID() throws {
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

    @Test func intIntoEnum() throws {
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

    @Test func floatIntoEnum() throws {
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

    @Test func stringIntoEnum() throws {
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

    @Test func booleanIntoEnum() throws {
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

    @Test func unknownEnumValueIntoEnum() throws {
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

    @Test func differentCaseEnumValueIntoEnum() throws {
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

    @Test func goodListValue() throws {
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

    @Test func emptyListValue() throws {
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

    @Test func nullValueIntoList() throws {
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

    @Test func singleValueIntoList() throws {
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

    @Test func incorrectItemType() throws {
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

    @Test func singleValueOfIncorrectType() throws {
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

    @Test func argOnOptionalArg() throws {
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

    @Test func noArgOnOptionalArg() throws {
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

    @Test func multipleArgs() throws {
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

    @Test func multipleArgsReverseOrder() throws {
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

    @Test func noArgsOnMultipleOptional() throws {
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

    @Test func oneArgOnMultipleOptional() throws {
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

    @Test func secondArgOnMultipleOptional() throws {
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

    @Test func multipleRequiredArgsOnMixedList() throws {
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

    @Test func multipleRequiredAndOneOptionalArgOnMixedList() throws {
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

    @Test func allRequiredAndOptionalArgsOnMixedList() throws {
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

    @Test func incorrectValueType() throws {
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

    @Test func incorrectValueAndMissingArgument() throws {
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

    @Test func nullValue() throws {
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

    @Test func optionalArgDespiteRequiredFieldInType() throws {
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

    @Test func partialObjectOnlyRequired() throws {
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

    @Test func partialObjectRequiredFieldCanBeFalsy() throws {
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

    @Test func partialObjectIncludingRequired() throws {
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

    @Test func fullObject() throws {
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

    @Test func fullObjectWithFieldsInDifferentOrder() throws {
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

    @Test func exactlyOneField() throws {
        try assertValid(
            """
            {
              complicatedArgs {
                oneOfArgField(oneOfArg: { stringField: "abc" })
              }
            }
            """
        )
    }

    @Test func exactlyOneNonNullableVariable() throws {
        try assertValid(
            """
            query ($string: String!) {
              complicatedArgs {
                oneOfArgField(oneOfArg: { stringField: $string })
              }
            }
            """
        )
    }

    // MARK: Invalid input object value

    @Test func partialObjectMissingRequired() throws {
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

    @Test func partialObjectInvalidFieldType() throws {
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

    @Test func partialObjectNullToNonNullField() throws {
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

    @Test func partialObjectUnknownFieldArg() throws {
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

    @Test func reportsOriginalErrorForCustomScalarWhichThrows() throws {
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

    @Test func reportsOriginalErrorForCustomScalarThatReturnsUndefined() throws {
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

    @Test func allowsCustomScalarToAcceptComplexLiterals() throws {
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
        #expect(errors == [])
    }

    // MARK: Invalid oneOf input object value

    @Test func invalidFieldType() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            {
              complicatedArgs {
                oneOfArgField(oneOfArg: { stringField: 2 })
              }
            }
            """
        )

        try assertValidationError(
            error: errors[0],
            locations: [(line: 3, column: 44)],
            message: #"String cannot represent a non-string value: 2"#
        )
    }

    @Test func exactlyOneNullField() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            {
              complicatedArgs {
                oneOfArgField(oneOfArg: { stringField: null })
              }
            }
            """
        )

        try assertValidationError(
            error: errors[0],
            locations: [(line: 3, column: 29)],
            message: #"Field "OneOfInput.stringField" must be non-null."#
        )
    }

    @Test func exactlyOneNullableVariable() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            query ($string: String) {
              complicatedArgs {
                oneOfArgField(oneOfArg: { stringField: $string })
              }
            }
            """
        )

        try assertValidationError(
            error: errors[0],
            locations: [(line: 3, column: 29)],
            message: #"Variable "string" must be non-nullable to be used for OneOf Input Object "OneOfInput"."#
        )
    }

    @Test func moreThanOneField() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query:
            """
            {
              complicatedArgs {
                oneOfArgField(oneOfArg: { stringField: "abc", intField: 123 })
              }
            }
            """
        )

        try assertValidationError(
            error: errors[0],
            locations: [(line: 3, column: 29)],
            message: #"OneOf Input Object "OneOfInput" must specify exactly one key."#
        )
    }

    // MARK: Directive arguments

    @Test func withDirectivesOfValidTypes() throws {
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

    @Test func withDirectiveWithIncorrectTypes() throws {
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

    @Test func variablesWithValidDefaultValues() throws {
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

    @Test func variablesWithValidDefaultNullValues() throws {
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

    @Test func variablesWithInvalidDefaultNullValues() throws {
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

    @Test func variablesWithInvalidDefaultValues() throws {
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

    @Test func variablesWithComplexInvalidDefaultValues() throws {
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

    @Test func complexVariableMissingRequiredField() throws {
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

    @Test func listVariablesWithInvalidItem() throws {
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
