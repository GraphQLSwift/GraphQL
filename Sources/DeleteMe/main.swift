import Foundation
import GraphQL

let schema = try buildSchema(source: """
type Query {
  str: String
  int: Int
  float: Float
  id: ID
  bool: Boolean
}
""")
print("schema")
let extendAST = try parse(source: """
extend type Query {
  foo: String
}
""")
print("extendAST")
let extendedSchema = try extendSchema(schema: schema, documentAST: extendAST)
print("extendSchema")
