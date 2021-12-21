@testable import GraphQL
import XCTest

class DecodableTests: XCTestCase {

    func testDecodeObjectType() {
        let decoder = JSONDecoder()
        
//        let encoder = JSONEncoder()
//        let data = try! encoder.encode(IntrospectionType.scalar(name: "asdf", description: "foo", specifiedByURL: "bar"))
//        print(String(data: data, encoding: .utf8))
//        let x = try! decoder.decode(IntrospectionType.self, from: data)
//        print(x)

        
        let x = try! decoder.decode(AnyIntrospectionType.self, from: """
            {
                "kind": "OBJECT",
                "name": "Foo"
            }
        """.data(using: .utf8)!)
        print(x)
        
        
        let schemaData = try! Data(contentsOf: URL(fileURLWithPath: "/Users/luke/Desktop/minm-schema.json"))
        let z = try! decoder.decode(IntrospectionQuery.self, from: schemaData)
        print(z)
        let schema = try! buildClientSchema(introspection: z)
        print(schema)
    }

}
