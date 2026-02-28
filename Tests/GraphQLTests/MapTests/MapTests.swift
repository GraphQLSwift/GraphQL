@testable import GraphQL
import Testing

@Suite struct MapTests {
    @Test func throwableConversion() throws {
        #expect(try Map.number(5).intValue() == 5)
        #expect(try Map.number(3.14).doubleValue() == 3.14)
        #expect(try Map.bool(false).boolValue() == false)
        #expect(try Map.bool(true).boolValue() == true)
        #expect(try Map.string("Hello world").stringValue() == "Hello world")
    }

    @Test func optionalConversion() {
        #expect(Map.number(5).int == 5)
        #expect(Map.number(3.14).double == 3.14)
        #expect(Map.bool(false).bool == false)
        #expect(Map.bool(true).bool == true)
        #expect(Map.string("Hello world").string == "Hello world")
    }

    @Test func arrayConversion() throws {
        let map = Map.array([.number(1), .number(4), .number(9)])
        #expect(map.array?.count == 3)

        let array = try map.arrayValue()
        #expect(array.count == 3)

        #expect(try array[0].intValue() == 1)
        #expect(try array[1].intValue() == 4)
        #expect(try array[2].intValue() == 9)
    }

    @Test func dictionaryConversion() throws {
        let map = Map.dictionary(
            [
                "first": .number(1),
                "second": .number(4),
                "third": .number(9),
                "fourth": .null,
                "fifth": .undefined,
            ]
        )
        #expect(map.dictionary?.count == 5)

        let dictionary = try map.dictionaryValue()

        #expect(dictionary.count == 5)
        #expect(try dictionary["first"]?.intValue() == 1)
        #expect(try dictionary["second"]?.intValue() == 4)
        #expect(try dictionary["third"]?.intValue() == 9)
        #expect(dictionary["fourth"]?.isNull == true)
        #expect(dictionary["fifth"]?.isUndefined == true)
    }

    /// Ensure that default decoding preserves undefined becoming nil
    @Test func nilAndUndefinedDecodeToNilByDefault() throws {
        struct DecodableTest: Codable {
            let first: Int?
            let second: Int?
            let third: Int?
            let fourth: Int?
        }

        let map = Map.dictionary(
            [
                "first": .number(1),
                "second": .null,
                "third": .undefined,
                // fourth not included
            ]
        )

        let decodable = try MapDecoder().decode(DecodableTest.self, from: map)
        #expect(decodable.first == 1)
        #expect(decodable.second == nil)
        #expect(decodable.third == nil)
        #expect(decodable.fourth == nil)
    }

    /// Ensure that, if custom decoding is defined, provided nulls and unset values can be
    /// differentiated.
    /// This should match JSON in that values set to `null` should be 'contained' by the container,
    /// but
    /// values expected by the result that are undefined or not present should not be.
    @Test func nilAndUndefinedDecoding() throws {
        struct DecodableTest: Codable {
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

                #expect(container.contains(.first))
                // Null value should be contained, but decode to nil
                #expect(container.contains(.second))
                // Undefined value should not be contained
                #expect(!container.contains(.third))
                // Missing value should operate the same as undefined
                #expect(!container.contains(.fourth))

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
                "third": .undefined,
                // fourth not included
            ]
        )

        _ = try MapDecoder().decode(DecodableTest.self, from: map)
    }

    /// Ensure that map encoding includes defined nulls, but skips undefined values
    @Test func mapEncodingNilAndUndefined() throws {
        let map = Map.dictionary(
            [
                "first": .number(1),
                "second": .null,
                "third": .undefined,
            ]
        )

        let data = try GraphQLJSONEncoder().encode(map)
        let json = String(data: data, encoding: .utf8)
        #expect(
            json == """
            {"first":1,"second":null}
            """
        )
    }

    /// Ensure that GraphQLJSONEncoder preserves map dictionary order in output
    @Test func mapEncodingOrderPreserved() throws {
        // Test top level
        #expect(
            try String(
                data: GraphQLJSONEncoder().encode(
                    Map.dictionary([
                        "1": .number(1),
                        "2": .number(2),
                        "3": .number(3),
                        "4": .number(4),
                        "5": .number(5),
                        "6": .number(6),
                        "7": .number(7),
                        "8": .number(8),
                    ])
                ),
                encoding: .utf8
            ) == """
            {"1":1,"2":2,"3":3,"4":4,"5":5,"6":6,"7":7,"8":8}
            """
        )

        // Test embedded
        #expect(
            try String(
                data: GraphQLJSONEncoder().encode(
                    Map.array([
                        Map.dictionary([
                            "1": .number(1),
                            "2": .number(2),
                            "3": .number(3),
                            "4": .number(4),
                            "5": .number(5),
                            "6": .number(6),
                            "7": .number(7),
                            "8": .number(8),
                        ]),
                    ])
                ),
                encoding: .utf8
            ) == """
            [{"1":1,"2":2,"3":3,"4":4,"5":5,"6":6,"7":7,"8":8}]
            """
        )
    }
}
