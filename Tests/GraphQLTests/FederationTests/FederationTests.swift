@testable import GraphQL
import XCTest

final class FederationTests: XCTestCase {
    func testFederationSampleSchema() throws {
        // Confirm that the Apollo test schema can be parsed as expected https://github.com/apollographql/apollo-federation-subgraph-compatibility/blob/main/COMPATIBILITY.md
        let source =
            """
            extend schema
              @link(
                url: "https://specs.apollo.dev/federation/v2.0",
                import: [
                  "@extends",
                  "@external",
                  "@key",
                  "@inaccessible",
                  "@override",
                  "@provides",
                  "@requires",
                  "@shareable",
                  "@tag"
                ]
              )

            type Product
              @key(fields: "id")
              @key(fields: "sku package")
              @key(fields: "sku variation { id }") {
                id: ID!
                sku: String
                package: String
                variation: ProductVariation
                dimensions: ProductDimension
                createdBy: User @provides(fields: "totalProductsCreated")
                notes: String @tag(name: "internal")
                research: [ProductResearch!]!
            }

            type DeprecatedProduct @key(fields: "sku package") {
              sku: String!
              package: String!
              reason: String
              createdBy: User
            }

            type ProductVariation {
              id: ID!
            }

            type ProductResearch @key(fields: "study { caseNumber }") {
              study: CaseStudy!
              outcome: String
            }

            type CaseStudy {
              caseNumber: ID!
              description: String
            }

            type ProductDimension @shareable {
              size: String
              weight: Float
              unit: String @inaccessible
            }

            extend type Query {
              product(id: ID!): Product
              deprecatedProduct(sku: String!, package: String!): DeprecatedProduct @deprecated(reason: "Use product query instead")
            }

            extend type User @key(fields: "email") {
              averageProductsCreatedPerYear: Int @requires(fields: "totalProductsCreated yearsOfEmployment")
              email: ID! @external
              name: String @override(from: "users")
              totalProductsCreated: Int @external
              yearsOfEmployment: Int! @external
            }
            """

        let schemaExtensionDefinition =
            SchemaExtensionDefinition(definition: SchemaDefinition(directives: [
                Directive(name: nameNode("link"), arguments: [
                    Argument(
                        name: nameNode("url"),
                        value: StringValue(
                            value: "https://specs.apollo.dev/federation/v2.0",
                            block: false
                        )
                    ),
                    Argument(
                        name: nameNode("import"),
                        value: ListValue(values: [
                            StringValue(value: "@extends", block: false),
                            StringValue(value: "@external", block: false),
                            StringValue(value: "@key", block: false),
                            StringValue(value: "@inaccessible", block: false),
                            StringValue(value: "@override", block: false),
                            StringValue(value: "@provides", block: false),
                            StringValue(value: "@requires", block: false),
                            StringValue(value: "@shareable", block: false),
                            StringValue(value: "@tag", block: false),
                        ])
                    ),
                ]),
            ], operationTypes: []))

        let productObjectTypeDefinition = ObjectTypeDefinition(
            name: nameNode("Product"),
            directives: [
                Directive(name: nameNode("key"), arguments: [
                    Argument(
                        name: nameNode("fields"),
                        value: StringValue(value: "id", block: false)
                    ),
                ]),
                Directive(name: nameNode("key"), arguments: [
                    Argument(
                        name: nameNode("fields"),
                        value: StringValue(value: "sku package", block: false)
                    ),
                ]),
                Directive(name: nameNode("key"), arguments: [
                    Argument(
                        name: nameNode("fields"),
                        value: StringValue(value: "sku variation { id }", block: false)
                    ),
                ]),
            ],
            fields: [
                FieldDefinition(name: nameNode("id"), type: NonNullType(type: typeNode("ID"))),
                FieldDefinition(name: nameNode("sku"), type: typeNode("String")),
                FieldDefinition(name: nameNode("package"), type: typeNode("String")),
                FieldDefinition(name: nameNode("variation"), type: typeNode("ProductVariation")),
                FieldDefinition(name: nameNode("dimensions"), type: typeNode("ProductDimension")),
                FieldDefinition(name: nameNode("createdBy"), type: typeNode("User"), directives: [
                    Directive(name: nameNode("provides"), arguments: [
                        Argument(
                            name: nameNode("fields"),
                            value: StringValue(value: "totalProductsCreated", block: false)
                        ),
                    ]),
                ]),
                FieldDefinition(name: nameNode("notes"), type: typeNode("String"), directives: [
                    Directive(name: nameNode("tag"), arguments: [
                        Argument(
                            name: nameNode("name"),
                            value: StringValue(value: "internal", block: false)
                        ),
                    ]),
                ]),
                FieldDefinition(
                    name: nameNode("research"),
                    type: NonNullType(
                        type: ListType(
                            type: NonNullType(type: NamedType(name: nameNode("ProductResearch")))
                        )
                    )
                ),
            ]
        )

        let deprecatedProductObjectTypeDefinition = ObjectTypeDefinition(
            name: nameNode("DeprecatedProduct"),
            directives: [
                Directive(name: nameNode("key"), arguments: [
                    Argument(
                        name: nameNode("fields"),
                        value: StringValue(value: "sku package", block: false)
                    ),
                ]),
            ],
            fields: [
                FieldDefinition(name: nameNode("sku"), type: NonNullType(type: typeNode("String"))),
                FieldDefinition(
                    name: nameNode("package"),
                    type: NonNullType(type: typeNode("String"))
                ),
                FieldDefinition(name: nameNode("reason"), type: typeNode("String")),
                FieldDefinition(name: nameNode("createdBy"), type: typeNode("User")),
            ]
        )

        let productVariationObjectTypeDefinition = ObjectTypeDefinition(
            name: nameNode("ProductVariation"),
            fields: [
                FieldDefinition(name: nameNode("id"), type: NonNullType(type: typeNode("ID"))),
            ]
        )

        let productResearchObjectTypeDefinition = ObjectTypeDefinition(
            name: nameNode("ProductResearch"),
            directives: [
                Directive(name: nameNode("key"), arguments: [
                    Argument(
                        name: nameNode("fields"),
                        value: StringValue(value: "study { caseNumber }", block: false)
                    ),
                ]),
            ],
            fields: [
                FieldDefinition(
                    name: nameNode("study"),
                    type: NonNullType(type: typeNode("CaseStudy"))
                ),
                FieldDefinition(name: nameNode("outcome"), type: typeNode("String")),
            ]
        )

        let caseStudyObjectTypeDefinition = ObjectTypeDefinition(
            name: nameNode("CaseStudy"),
            fields: [
                FieldDefinition(
                    name: nameNode("caseNumber"),
                    type: NonNullType(type: typeNode("ID"))
                ),
                FieldDefinition(name: nameNode("description"), type: typeNode("String")),
            ]
        )

        let productDimensionObjectTypeDefinition = ObjectTypeDefinition(
            name: nameNode("ProductDimension"),
            directives: [
                Directive(name: nameNode("shareable")),
            ],
            fields: [
                FieldDefinition(name: nameNode("size"), type: typeNode("String")),
                FieldDefinition(name: nameNode("weight"), type: typeNode("Float")),
                FieldDefinition(name: nameNode("unit"), type: typeNode("String"), directives: [
                    Directive(name: nameNode("inaccessible")),
                ]),
            ]
        )

        let queryExtensionObjectTypeDefinition =
            TypeExtensionDefinition(definition: ObjectTypeDefinition(
                name: nameNode("Query"),
                fields: [
                    FieldDefinition(name: nameNode("product"), arguments: [
                        InputValueDefinition(
                            name: nameNode("id"),
                            type: NonNullType(type: NamedType(name: nameNode("ID")))
                        ),
                    ], type: typeNode("Product")),
                    FieldDefinition(name: nameNode("deprecatedProduct"), arguments: [
                        InputValueDefinition(
                            name: nameNode("sku"),
                            type: NonNullType(type: NamedType(name: nameNode("String")))
                        ),
                        InputValueDefinition(
                            name: nameNode("package"),
                            type: NonNullType(type: NamedType(name: nameNode("String")))
                        ),
                    ], type: typeNode("DeprecatedProduct"), directives: [
                        Directive(name: nameNode("deprecated"), arguments: [
                            Argument(
                                name: nameNode("reason"),
                                value: StringValue(value: "Use product query instead", block: false)
                            ),
                        ]),
                    ]),
                ]
            ))

        let userExtensionObjectTypeDefinition =
            TypeExtensionDefinition(definition: ObjectTypeDefinition(
                name: nameNode("User"),
                directives: [
                    Directive(name: nameNode("key"), arguments: [
                        Argument(
                            name: nameNode("fields"),
                            value: StringValue(value: "email", block: false)
                        ),
                    ]),
                ],
                fields: [
                    FieldDefinition(
                        name: nameNode("averageProductsCreatedPerYear"),
                        type: typeNode("Int"),
                        directives: [
                            Directive(name: nameNode("requires"), arguments: [
                                Argument(
                                    name: nameNode("fields"),
                                    value: StringValue(
                                        value: "totalProductsCreated yearsOfEmployment",
                                        block: false
                                    )
                                ),
                            ]),
                        ]
                    ),
                    FieldDefinition(
                        name: nameNode("email"),
                        type: NonNullType(type: NamedType(name: nameNode("ID"))),
                        directives: [
                            Directive(name: nameNode("external")),
                        ]
                    ),
                    FieldDefinition(name: nameNode("name"), type: typeNode("String"), directives: [
                        Directive(name: nameNode("override"), arguments: [
                            Argument(
                                name: nameNode("from"),
                                value: StringValue(value: "users", block: false)
                            ),
                        ]),
                    ]),
                    FieldDefinition(
                        name: nameNode("totalProductsCreated"),
                        type: typeNode("Int"),
                        directives: [
                            Directive(name: nameNode("external")),
                        ]
                    ),
                    FieldDefinition(
                        name: nameNode("yearsOfEmployment"),
                        type: NonNullType(type: typeNode("Int")),
                        directives: [
                            Directive(name: nameNode("external")),
                        ]
                    ),
                ]
            ))

        let expected = Document(definitions: [
            schemaExtensionDefinition,
            productObjectTypeDefinition,
            deprecatedProductObjectTypeDefinition,
            productVariationObjectTypeDefinition,
            productResearchObjectTypeDefinition,
            caseStudyObjectTypeDefinition,
            productDimensionObjectTypeDefinition,
            queryExtensionObjectTypeDefinition,
            userExtensionObjectTypeDefinition,
        ])

        let result = try parse(source: source)
        XCTAssert(result == expected)
    }
}
