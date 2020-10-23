@testable import GraphQL
import XCTest

class MapTests: XCTestCase {
    func testThrowableConversion() throws {
        XCTAssertEqual(try Map.number(5).intValue(), 5)
        XCTAssertEqual(try Map.number(3.14).doubleValue(), 3.14)
        XCTAssertEqual(try Map.bool(false).boolValue(), false)
        XCTAssertEqual(try Map.bool(true).boolValue(), true)
        XCTAssertEqual(try Map.string("Hello world").stringValue(), "Hello world")

    }

    func testOptionalConversion() {
        XCTAssertEqual(Map.number(5).int, 5)
        XCTAssertEqual(Map.number(3.14).double, 3.14)
        XCTAssertEqual(Map.bool(false).bool, false)
        XCTAssertEqual(Map.bool(true).bool, true)
        XCTAssertEqual(Map.string("Hello world").string, "Hello world")
    }

    func testArrayConversion() throws {
        let map = Map.array([.number(1), .number(4), .number(9)])
        XCTAssertEqual(map.array?.count, 3)

        let array = try map.arrayValue()
        XCTAssertEqual(array.count, 3)

        XCTAssertEqual(try array[0].intValue(), 1)
        XCTAssertEqual(try array[1].intValue(), 4)
        XCTAssertEqual(try array[2].intValue(), 9)
    }

    func testDictionaryConversion() throws {
        let map = Map.dictionary(
            [
                "first": .number(1),
                "second": .number(4),
                "third": .number(9)
            ]
        )
        XCTAssertEqual(map.dictionary?.count, 3)

        let dictionary = try map.dictionaryValue()

        XCTAssertEqual(dictionary.count, 3)
        XCTAssertEqual(try dictionary["first"]?.intValue(), 1)
        XCTAssertEqual(try dictionary["second"]?.intValue(), 4)
        XCTAssertEqual(try dictionary["third"]?.intValue(), 9)
    }
}
