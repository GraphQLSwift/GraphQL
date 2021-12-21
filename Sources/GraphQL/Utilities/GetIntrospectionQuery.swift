func getIntrospectionQuery(
    descriptions: Bool = true,
    specifiedByUrl: Bool = false,
    directiveIsRepeatable: Bool = false,
    schemaDescription: Bool = false,
    inputValueDeprecation: Bool = false
) -> String {
    
    let descriptions = descriptions ? "description" : ""
    let specifiedByUrl = specifiedByUrl ? "specifiedByURL" : ""
    let directiveIsRepeatable = directiveIsRepeatable ? "isRepeatable" : ""
    let schemaDescription = schemaDescription ? descriptions : ""
    
    func inputDeprecation(_ str: String) -> String {
        return inputValueDeprecation ? str : ""
    }
    
    return """
    query IntrospectionQuery {
      __schema {
        \(schemaDescription)
        queryType { name }
        mutationType { name }
        subscriptionType { name }
        types {
          ...FullType
        }
        directives {
          name
          \(descriptions)
          \(directiveIsRepeatable)
          locations
          args\(inputDeprecation("(includeDeprecated: true)")) {
            ...InputValue
          }
        }
      }
    }
    fragment FullType on __Type {
      kind
      name
      \(descriptions)
      \(specifiedByUrl)
      fields(includeDeprecated: true) {
        name
        \(descriptions)
        args\(inputDeprecation("(includeDeprecated: true)")) {
          ...InputValue
        }
        type {
          ...TypeRef
        }
        isDeprecated
        deprecationReason
      }
      inputFields\(inputDeprecation("(includeDeprecated: true)")) {
        ...InputValue
      }
      interfaces {
        ...TypeRef
      }
      enumValues(includeDeprecated: true) {
        name
        \(descriptions)
        isDeprecated
        deprecationReason
      }
      possibleTypes {
        ...TypeRef
      }
    }
    fragment InputValue on __InputValue {
      name
      \(descriptions)
      type { ...TypeRef }
      defaultValue
      \(inputDeprecation("isDeprecated"))
      \(inputDeprecation("deprecationReason"))
    }
    fragment TypeRef on __Type {
      kind
      name
      ofType {
        kind
        name
        ofType {
          kind
          name
          ofType {
            kind
            name
            ofType {
              kind
              name
              ofType {
                kind
                name
                ofType {
                  kind
                  name
                  ofType {
                    kind
                    name
                  }
                }
              }
            }
          }
        }
      }
    }
  """
}

public struct IntrospectionQuery: Codable {
    let __schema: IntrospectionSchema
}

struct IntrospectionSchema: Codable {
    let description: String?
    let queryType: IntrospectionKindlessNamedTypeRef
    let mutationType: IntrospectionKindlessNamedTypeRef?
    let subscriptionType: IntrospectionKindlessNamedTypeRef?
    let types: [AnyIntrospectionType]
//    let directives: [IntrospectionDirective]
    
    func encode(to encoder: Encoder) throws {
        try types.encode(to: encoder)
    }
}

protocol IntrospectionType: Codable {
    static var kind: TypeKind2 { get }
    var name: String { get }
}

enum IntrospectionTypeCodingKeys: String, CodingKey {
    case kind
}
//enum IntrospectionType: Codable {
//    case scalar(name: String, description: String?, specifiedByURL: String?)
//
//    enum IntrospectionScalarTypeCodingKeys: CodingKey {
//        case kind, name, description, specifiedByURL
//    }
//    func encode(to encoder: Encoder) throws {
//        switch self {
//        case .scalar(let name, let description, let specifiedByURL):
//            var container = encoder.container(keyedBy: IntrospectionScalarTypeCodingKeys.self)
//            try container.encode(TypeKind2.scalar, forKey: .kind)
//            try container.encode(name, forKey: .name)
//            try container.encode(description, forKey: .description)
//            try container.encode(specifiedByURL, forKey: .specifiedByURL)
//        }
//    }
//    init(from decoder: Decoder) throws {
//        let container = try decoder.container(keyedBy: IntrospectionTypeCodingKeys.self)
//        switch try container.decode(TypeKind2.self, forKey: .kind) {
//        case .scalar:
//            let container = try decoder.container(keyedBy: IntrospectionScalarTypeCodingKeys.self)
//            self = .scalar(
//                name: try container.decode(String.self, forKey: .name),
//                description: try container.decode(String.self, forKey: .description),
//                specifiedByURL: try container.decode(String.self, forKey: .description)
//            )
//        }
//    }
//}

enum TypeKind2 : String, Codable {
    case scalar = "SCALAR"
    case object = "OBJECT"
    case interface = "INTERFACE"
    case union = "UNION"
    case `enum` = "ENUM"
    case inputObject = "INPUT_OBJECT"
//    case list = "LIST"
//    case nonNull = "NON_NULL"
}

struct AnyIntrospectionType: Codable {
    let x: IntrospectionType
    func encode(to encoder: Encoder) throws {
        try x.encode(to: encoder)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: IntrospectionTypeCodingKeys.self)
        switch try container.decode(TypeKind2.self, forKey: .kind) {
        case .scalar:
            x = try IntrospectionScalarType(from: decoder)
        case .object:
            x = try IntrospectionObjectType(from: decoder)
        case .interface:
            x = try IntrospectionInterfaceType(from: decoder)
        case .union:
            x = try IntrospectionUnionType(from: decoder)
        case .enum:
            x = try IntrospectionEnumType(from: decoder)
        case .inputObject:
            x = try IntrospectionInputObjectType(from: decoder)
        }
    }
}

//protocol IntrospectionOutputType: Codable {}
//extension IntrospectionScalarType: IntrospectionOutputType {}
//
//protocol IntrospectionInputType: Codable {}
//extension IntrospectionScalarType: IntrospectionInputType {}
//extension IntrospectionEnumType: IntrospectionInputType {}
//extension IntrospectionInputObjectType: IntrospectionInputType {}
//
struct IntrospectionScalarType: IntrospectionType {
    static let kind = TypeKind2.scalar
    let name: String
    let description: String?
    let specifiedByURL: String?
}

struct IntrospectionObjectType: IntrospectionType {
    static let kind = TypeKind2.object
    let name: String
    let description: String?
    let fields: [IntrospectionField]?
    let interfaces: [IntrospectionTypeRef]?
}

struct IntrospectionInterfaceType: IntrospectionType {
    static let kind = TypeKind2.interface
    let name: String
    let description: String?
    let fields: [IntrospectionField]?
    let interfaces: [IntrospectionTypeRef]?
    let possibleTypes: [IntrospectionTypeRef]
}

struct IntrospectionUnionType: IntrospectionType {
    static let kind = TypeKind2.union
    let name: String
    let description: String?
    let possibleTypes: [IntrospectionTypeRef]
}

struct IntrospectionEnumType: IntrospectionType {
    static let kind = TypeKind2.enum
    let name: String
    let description: String?
    let enumValues: [IntrospectionEnumValue]
}

struct IntrospectionInputObjectType: IntrospectionType {
    static let kind = TypeKind2.inputObject
    let name: String
    let description: String?
    let inputFields: [IntrospectionInputValue]
}
//
//protocol IntrospectionTypeRef: Codable {}
//extension IntrospectionNamedTypeRef: IntrospectionTypeRef {}
//
//protocol IntrospectionOutputTypeRef: Codable {}
//extension IntrospectionNamedTypeRef: IntrospectionOutputTypeRef where T: IntrospectionOutputType {}
//extension IntrospectionListTypeRef: IntrospectionOutputTypeRef where T: IntrospectionOutputType {}

//struct AnyIntrospectionOutputTypeRef: Codable {
//    let typeRef: IntrospectionOutputTypeRef
//    func encode(to encoder: Encoder) throws {
//        try typeRef.encode(to: encoder)
//    }
//    init(from decoder: Decoder) throws {
//        let container = try decoder.container(keyedBy: IntrospectionTypeCodingKeys.self)
//        switch try container.decode(TypeKind2.self, forKey: .kind) {
//        case .list:
//            typeRef = try IntrospectionListTypeRef<<#T: IntrospectionTypeRef#>>(from: decoder)
//        default:
//            fatalError()
//        }
//    }
//}

//protocol IntrospectionInputTypeRef: Codable {}
//extension IntrospectionNamedTypeRef: IntrospectionInputTypeRef where T: IntrospectionInputType {}
//
//struct IntrospectionListTypeRef<T: IntrospectionTypeRef>: IntrospectionType {
//    static var kind: TypeKind2 { TypeKind2.list }
//    let ofType: T
//}

//struct IntrospectionNamedTypeRef<T: IntrospectionType>: Codable {
//    var kind: TypeKind2 = T.kind
//    let name: String
//}

indirect enum IntrospectionTypeRef: Codable {
    case named(kind: TypeKind2, name: String)
    case list(ofType: IntrospectionTypeRef)
    case nonNull(ofType: IntrospectionTypeRef)
    
    enum NamedTypeRefCodingKeys: CodingKey {
        case kind, name
    }
    enum ListTypeRefCodingKeys: CodingKey {
        case kind, ofType
    }
    
    enum TypeRefKind: Codable {
        case list, nonNull, named(TypeKind2)
    }
    
    func encode(to encoder: Encoder) throws {
        switch self {
        case .named(let kind, let name):
            var container = encoder.container(keyedBy: NamedTypeRefCodingKeys.self)
            try container.encode(kind, forKey: .kind)
            try container.encode(name, forKey: .name)
        case .list(let ofType):
            var container = encoder.container(keyedBy: ListTypeRefCodingKeys.self)
            try container.encode("LIST", forKey: .kind)
            try container.encode(ofType, forKey: .ofType)
        case .nonNull(let ofType):
            var container = encoder.container(keyedBy: ListTypeRefCodingKeys.self)
            try container.encode("NON_NULL", forKey: .kind)
            try container.encode(ofType, forKey: .ofType)
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: NamedTypeRefCodingKeys.self)
        if let kind = try? container.decode(TypeKind2.self, forKey: .kind) {
            self = .named(kind: kind, name: try container.decode(String.self, forKey: .name))
        } else {
            let container = try decoder.container(keyedBy: ListTypeRefCodingKeys.self)
            let kind = try container.decode(String.self, forKey: .kind)
            switch kind {
            case "LIST":
                self = .list(ofType: try container.decode(IntrospectionTypeRef.self, forKey: .ofType))
            case "NON_NULL":
                self = .nonNull(ofType: try container.decode(IntrospectionTypeRef.self, forKey: .ofType))
            default:
                fatalError()
            }
        }
    }
}

struct IntrospectionKindlessNamedTypeRef: Codable {
    let name: String
}

struct IntrospectionField: Codable {
    let name: String
    let description: String?
    let args: [IntrospectionInputValue]
    let type: IntrospectionTypeRef
    let isDeprecated: Bool
    let deprecationReason: String?
}

struct IntrospectionInputValue: Codable {
    let name: String
    let description: String?
    let type: IntrospectionTypeRef
    let defaultValue: String?
    let isDeprecated: Bool?
    let deprecationReason: String?
}

struct IntrospectionEnumValue: Codable {
    let name: String
    let description: String?
    let isDeprecated: Bool
    let deprecationReason: String?
}

struct IntrospectionDirective: Codable {
    let name: String
    let description: String?
    let isRepeatable: Bool?
    let locations: [DirectiveLocation]
    let args: [IntrospectionInputValue]
}
