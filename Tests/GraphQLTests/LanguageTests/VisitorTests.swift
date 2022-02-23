import XCTest
@testable import GraphQL

class VisitorTests : XCTestCase {
    func testVisitsField() throws {
        class FieldVisitor: Visitor {
            var visited = false
            func enter(field: Field, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<Field> {
                visited = true
                return .continue
            }
        }
        let document = try! parse(source: """
            query foo {
                bar
            }
        """)
        let visitor = FieldVisitor()
        visit(root: document, visitor: visitor)
        XCTAssert(visitor.visited)
    }
    
    func testVisitorCanEdit() throws {
        struct FieldVisitor: Visitor {
            func enter(field: Field, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<Field> {
                guard case let .node(queryParent) = parent, queryParent is Selection else {
                    XCTFail("Unexpected parent")
                    return .continue
                }
                var newField = field
                newField.name = Name(loc: nil, value: "baz")
                return .node(newField)
            }
        }
        let document = try! parse(source: """
            query foo {
                bar
            }
        """)
        let visitor = FieldVisitor()
        let newDocument = visit(root: document, visitor: visitor)
        guard case let .executableDefinition(.operation(opDef)) = newDocument.definitions.first else {
            XCTFail("Unexpected definition")
            return
        }
        guard case let .field(field) = opDef.selectionSet.selections.first else {
            XCTFail("Unexpected selection")
            return
        }
        XCTAssertEqual("baz", field.name.value)
    }
    
    
    func testVisitorCanEditArray() throws {
        struct IntIncrementer: Visitor {
            func enter(intValue: IntValue, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<IntValue> {
                let newVal = Int(intValue.value)! + 1
                return .node(IntValue(loc: nil, value: String(newVal)))
            }
            
            func leave(argument: Argument, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<Argument> {
                if argument.value == .intValue(IntValue(value: "2")) {
                    return .node(nil)
                }
                return .continue
            }
        }
        let document = try! parse(source: """
            query foo {
                bar(a: 1, b: 2, c: 3)
            }
        """)
        let visitor = IntIncrementer()
        let newDocument = visit(root: document, visitor: visitor)
        guard case let .executableDefinition(.operation(opDef)) = newDocument.definitions.first else {
            XCTFail("Unexpected definition")
            return
        }
        guard case let .field(field) = opDef.selectionSet.selections.first else {
            XCTFail("Unexpected selection")
            return
        }
        let expectedInts = [3,4]
        for (argument, expected) in zip(field.arguments, expectedInts) {
            switch argument.value {
            case .intValue(let intVal) where Int(intVal.value) == expected:
                break
            default:
                XCTFail("Unexpected value")
                return
            }
        }
    }
    
    func testVisitorBreaks() {
        class FieldVisitor: Visitor {
            var visited = false
            func enter(field: Field, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<Field> {
                if (visited) {
                    XCTFail("Visited the nested field and didn't break")
                }
                visited = true
                return .break
            }
            func leave(field: Field, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<Field> {
                XCTFail("Left the field and didn't break")
                return .continue
            }
            func leave(operationDefinition: OperationDefinition, key: AnyKeyPath?, parent: VisitorParent?, ancestors: [VisitorParent]) -> VisitResult<OperationDefinition> {
                XCTFail("Left the operation definition and didn't break")
                return .continue
            }
        }
        let document = try! parse(source: """
            {
                bar {
                    baz
                }
            }
        """)
        let visitor = FieldVisitor()
        visit(root: document, visitor: visitor)
        XCTAssert(visitor.visited)
    }
}
