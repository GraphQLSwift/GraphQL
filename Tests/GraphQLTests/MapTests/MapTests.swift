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
                "third": .number(9),
                "fourth": .null,
                "fifth": .undefined
            ]
        )
        XCTAssertEqual(map.dictionary?.count, 5)

        let dictionary = try map.dictionaryValue()

        XCTAssertEqual(dictionary.count, 5)
        XCTAssertEqual(try dictionary["first"]?.intValue(), 1)
        XCTAssertEqual(try dictionary["second"]?.intValue(), 4)
        XCTAssertEqual(try dictionary["third"]?.intValue(), 9)
        XCTAssertEqual(dictionary["fourth"]?.isNull, true)
        XCTAssertEqual(dictionary["fifth"]?.isUndefined, true)
    }
    
    // Ensure that default decoding preserves undefined becoming nil
    func testNilAndUndefinedDecodeToNilByDefault() throws {
        struct DecodableTest : Codable {
            let first: Int?
            let second: Int?
            let third: Int?
            let fourth: Int?
        }
        
        let map = Map.dictionary(
            [
                "first": .number(1),
                "second": .null,
                "third": .undefined
                // fourth not included
            ]
        )
        
        let decodable = try MapDecoder().decode(DecodableTest.self, from: map)
        XCTAssertEqual(decodable.first, 1)
        XCTAssertEqual(decodable.second, nil)
        XCTAssertEqual(decodable.third, nil)
        XCTAssertEqual(decodable.fourth, nil)
    }
    
    // Ensure that, if custom decoding is defined, provided nulls and unset values can be differentiated.
    // This should match JSON in that values set to `null` should be 'contained' by the container, but
    // values expected by the result that are undefined or not present should not be.
    func testNilAndUndefinedDecoding() throws {
        struct DecodableTest : Codable {
            let first: Int?
            let second: Int?
            let third: Int?
            let fourth: Int?
            
            init(
                first: Int?,
                second: Int?,
                third: Int?,
                fourth: Int?
            ) {
                self.first = first
                self.second = second
                self.third = third
                self.fourth = fourth
            }
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                XCTAssertTrue(container.contains(.first))
                // Null value should be contained, but decode to nil
                XCTAssertTrue(container.contains(.second))
                // Undefined value should not be contained
                XCTAssertFalse(container.contains(.third))
                // Missing value should operate the same as undefined
                XCTAssertFalse(container.contains(.fourth))
                
                first = try container.decodeIfPresent(Int.self, forKey: .first)
                second = try container.decodeIfPresent(Int.self, forKey: .second)
                third = try container.decodeIfPresent(Int.self, forKey: .third)
                fourth = try container.decodeIfPresent(Int.self, forKey: .fourth)
            }
        }
        
        let map = Map.dictionary(
            [
                "first": .number(1),
                "second": .null,
                "third": .undefined
                // fourth not included
            ]
        )
        
        _ = try MapDecoder().decode(DecodableTest.self, from: map)
    }
    
    // Ensure that map encoding includes defined nulls, but skips undefined values
    func testMapEncoding() throws {
        let map = Map.dictionary(
            [
                "first": .number(1),
                "second": .null,
                "third": .undefined
            ]
        )
        
        let data = try JSONEncoder().encode(map)
        let json = String(data: data, encoding: .utf8)
        XCTAssertEqual(
            json,
            """
            {"first":1,"second":null}
            """
        )
    }
}
