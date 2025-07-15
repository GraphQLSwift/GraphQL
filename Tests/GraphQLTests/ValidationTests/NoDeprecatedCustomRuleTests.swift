@testable import GraphQL
import XCTest

class NoDeprecatedCustomRuleTests: ValidationTestCase {
    override func setUp() {
        rule = NoDeprecatedCustomRule
    }

    // MARK: no deprecated fields

    let deprecatedFieldSchema = try! GraphQLSchema(
        query: .init(name: "Query", fields: [
            "normalField": .init(type: GraphQLString),
            "deprecatedField": .init(type: GraphQLString, deprecationReason: "Some field reason."),
        ])
    )

    func testIgnoresFieldsThatAreNotDeprecated() throws {
        try assertValid(
            """
            {
              normalField
            }
            """,
            schema: deprecatedFieldSchema
        )
    }

    func testIgnoresUnknownFields() throws {
        try assertValid(
            """
            {
              unknownField
            }

            fragment UnknownFragment on UnknownType {
              deprecatedField
            }
            """,
            schema: deprecatedFieldSchema
        )
    }

    func testReportsErrorWhenADeprecatedFieldIsSelected() throws {
        let errors = try assertInvalid(
            errorCount: 2,
            query: """
            {
              deprecatedField
            }

            fragment QueryFragment on Query {
              deprecatedField
            }
            """,
            schema: deprecatedFieldSchema
        )
        try assertValidationError(
            error: errors[0],
            locations: [(line: 2, column: 3)],
            message: #"The field Query.deprecatedField is deprecated. Some field reason."#
        )
        try assertValidationError(
            error: errors[1],
            locations: [(line: 6, column: 3)],
            message: #"The field Query.deprecatedField is deprecated. Some field reason."#
        )
    }

    // MARK: no deprecated arguments on fields

    let deprecatedFieldArgumentSchema = try! GraphQLSchema(
        query: .init(name: "Query", fields: [
            "someField": .init(type: GraphQLString, args: [
                "normalArg": .init(type: GraphQLString),
                "deprecatedArg": .init(type: GraphQLString, deprecationReason: "Some arg reason."),
            ]),
        ])
    )

    func testIgnoresFieldArgumentsThatAreNotDeprecated() throws {
        try assertValid(
            """
            {
              normalField(normalArg: "")
            }
            """,
            schema: deprecatedFieldArgumentSchema
        )
    }

    func testIgnoresUnknownFieldArguments() throws {
        try assertValid(
            """
            {
              someField(unknownArg: "")
              unknownField(deprecatedArg: "")
            }
            """,
            schema: deprecatedFieldArgumentSchema
        )
    }

    func testReportsErrorWhenADeprecatedFieldArgumentIsUsed() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: """
            {
              someField(deprecatedArg: "")
            }
            """,
            schema: deprecatedFieldArgumentSchema
        )
        try assertValidationError(
            error: errors[0],
            locations: [(line: 2, column: 13)],
            message: #"Field "Query.someField" argument "deprecatedArg" is deprecated. Some arg reason."#
        )
    }

    // MARK: no deprecated arguments on directives

    let deprecatedDirectiveArgumentSchema = try! GraphQLSchema(
        query: .init(name: "Query", fields: [
            "someField": .init(type: GraphQLString),
        ]),
        directives: [
            .init(
                name: "someDirective",
                locations: [
                    .field,
                ],
                args: [
                    "normalArg": .init(type: GraphQLString),
                    "deprecatedArg": .init(
                        type: GraphQLString,
                        deprecationReason: "Some arg reason."
                    ),
                ]
            ),
        ]
    )

    func testIgnoresDirectiveArgumentsThatAreNotDeprecated() throws {
        try assertValid(
            """
            {
              someField @someDirective(normalArg: "")
            }
            """,
            schema: deprecatedDirectiveArgumentSchema
        )
    }

    func testIgnoresUnknownDirectiveArguments() throws {
        try assertValid(
            """
            {
              someField @someDirective(unknownArg: "")
              someField @unknownDirective(deprecatedArg: "")
            }
            """,
            schema: deprecatedDirectiveArgumentSchema
        )
    }

    func testReportsErrorWhenADeprecatedDirectiveArgumentIsUsed() throws {
        let errors = try assertInvalid(
            errorCount: 1,
            query: """
            {
              someField @someDirective(deprecatedArg: "")
            }
            """,
            schema: deprecatedDirectiveArgumentSchema
        )
        try assertValidationError(
            error: errors[0],
            locations: [(line: 2, column: 28)],
            message: #"Directive "@someDirective" argument "deprecatedArg" is deprecated. Some arg reason."#
        )
    }

    // MARK: no deprecated input fields

    let deprecatedInputFieldSchema: GraphQLSchema = {
        let inputType = try! GraphQLInputObjectType(name: "InputType", fields: [
            "normalField": .init(type: GraphQLString),
            "deprecatedField": .init(
                type: GraphQLString,
                deprecationReason: "Some input field reason."
            ),
        ])
        return try! GraphQLSchema(
            query: .init(name: "Query", fields: [
                "someField": .init(type: GraphQLString, args: [
                    "someArg": .init(type: inputType),
                ]),
            ]),
            types: [
                inputType,
            ],
            directives: [
                .init(
                    name: "someDirective",
                    locations: [
                        .field,
                    ],
                    args: [
                        "someArg": .init(type: inputType),
                    ]
                ),
            ]
        )
    }()

    func testIgnoresInputFieldsThatAreNotDeprecated() throws {
        try assertValid(
            """
            {
              someField(
                someArg: { normalField: "" }
              ) @someDirective(someArg: { normalField: "" })
            }
            """,
            schema: deprecatedInputFieldSchema
        )
    }

    func testIgnoresUnknownInputFields() throws {
        try assertValid(
            """
            {
              someField(
                someArg: { unknownField: "" }
              )

              someField(
                unknownArg: { unknownField: "" }
              )

              unknownField(
                unknownArg: { unknownField: "" }
              )
            }
            """,
            schema: deprecatedInputFieldSchema
        )
    }

    func testReportsErrorWhenADeprecatedInputFieldIsUsed() throws {
        let errors = try assertInvalid(
            errorCount: 2,
            query: """
            {
              someField(
                someArg: { deprecatedField: "" }
              ) @someDirective(someArg: { deprecatedField: "" })
            }
            """,
            schema: deprecatedInputFieldSchema
        )
        try assertValidationError(
            error: errors[0],
            locations: [(line: 3, column: 16)],
            message: #"The input field InputType.deprecatedField is deprecated. Some input field reason."#
        )
        try assertValidationError(
            error: errors[1],
            locations: [(line: 4, column: 31)],
            message: #"The input field InputType.deprecatedField is deprecated. Some input field reason."#
        )
    }

    // MARK: no deprecated enum values

    let deprecatedEnumValueSchema: GraphQLSchema = {
        let enumType = try! GraphQLEnumType(name: "EnumType", values: [
            "NORMAL_VALUE": .init(value: .string("NORMAL_VALUE")),
            "DEPRECATED_VALUE": .init(
                value: .string("DEPRECATED_VALUE"),
                deprecationReason: "Some enum reason."
            ),
        ])
        return try! GraphQLSchema(
            query: .init(name: "Query", fields: [
                "someField": .init(type: GraphQLString, args: [
                    "enumArg": .init(type: enumType),
                ]),
            ]),
            types: [
                enumType,
            ]
        )
    }()

    func testIgnoresEnumValuesThatAreNotDeprecated() throws {
        try assertValid(
            """
            {
              normalField(enumArg: NORMAL_VALUE)
            }
            """,
            schema: deprecatedEnumValueSchema
        )
    }

    func testIgnoresUnknownEnumValues() throws {
        try assertValid(
            """
            query (
              $unknownValue: EnumType = UNKNOWN_VALUE
              $unknownType: UnknownType = UNKNOWN_VALUE
            ) {
              someField(enumArg: UNKNOWN_VALUE)
              someField(unknownArg: UNKNOWN_VALUE)
              unknownField(unknownArg: UNKNOWN_VALUE)
            }

            fragment SomeFragment on Query {
              someField(enumArg: UNKNOWN_VALUE)
            }
            """,
            schema: deprecatedEnumValueSchema
        )
    }

    func testReportsErrorWhenADeprecatedEnumValueIsUsed() throws {
        let errors = try assertInvalid(
            errorCount: 2,
            query: """
            query (
              $variable: EnumType = DEPRECATED_VALUE
            ) {
              someField(enumArg: DEPRECATED_VALUE)
            }
            """,
            schema: deprecatedEnumValueSchema
        )
        try assertValidationError(
            error: errors[0],
            locations: [(line: 2, column: 25)],
            message: #"The enum value "EnumType.DEPRECATED_VALUE" is deprecated. Some enum reason."#
        )
        try assertValidationError(
            error: errors[1],
            locations: [(line: 4, column: 22)],
            message: #"The enum value "EnumType.DEPRECATED_VALUE" is deprecated. Some enum reason."#
        )
    }
}
