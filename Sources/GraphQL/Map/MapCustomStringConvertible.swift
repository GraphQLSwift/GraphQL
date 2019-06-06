
import Foundation

// MARK: CustomStringConvertible

extension Map : CustomStringConvertible {
    public var description: String {
        return description(debug: false)
    }
}

// MARK: CustomDebugStringConvertible

extension Map:CustomDebugStringConvertible {
    public var debugDescription:String {
        return description(debug: true)
    }
}


// MARK: Generic Description
extension Map {
    public func description(debug: Bool) -> String {
        var indentLevel = 0

        let escapeMapping: [Character: String] = [
            "\r": "\\r",
            "\n": "\\n",
            "\t": "\\t",
            "\\": "\\\\",
            "\"": "\\\"",

            "\u{2028}": "\\u2028",
            "\u{2029}": "\\u2029",

            "\r\n": "\\r\\n"
        ]

        func escape(_ source: String) -> String {
            var string = "\""

            for character in source {
                if let escapedSymbol = escapeMapping[character] {
                    string.append(escapedSymbol)
                } else {
                    string.append(character)
                }
            }

            string.append("\"")
            return string
        }

        func serialize(map: Map) -> String {
            switch map {
            case .null: return "null"
            case .bool(let bool): return String(bool)
            case .double(let number): return String(number)
            case .int(let number): return String(number)
            case .string(let string): return escape(string)
            case .array(let array): return serialize(array: array)
            case .dictionary(let dictionary): return serialize(dictionary: dictionary)
            }
        }

        func serialize(array: [Map]) -> String {
            var string = "["

            if debug {
                indentLevel += 1
            }

            for index in 0 ..< array.count {
                if debug {
                    string += "\n"
                    string += indent()
                }

                string += serialize(map: array[index])

                if index != array.count - 1 {
                    if debug {
                        string += ", "
                    } else {
                        string += ","
                    }
                }
            }

            if debug {
                indentLevel -= 1
                return string + "\n" + indent() + "]"
            } else {
                return string + "]"
            }
        }

        func serialize(dictionary: [String: Map]) -> String {
            var string = "{"
            var index = 0

            if debug {
                indentLevel += 1
            }

            for (key, value) in dictionary.sorted(by: {$0.0 < $1.0}) {
                if debug {
                    string += "\n"
                    string += indent()
                    string += escape(key) + ": " + serialize(map: value)
                } else {
                    string += escape(key) + ":" + serialize(map: value)
                }

                if index != dictionary.count - 1 {
                    if debug {
                        string += ", "
                    } else {
                        string += ","
                    }
                }

                index += 1
            }

            if debug {
                indentLevel -= 1
                return string + "\n" + indent() + "}"
            } else {
                return string + "}"
            }
        }
        
        func indent() -> String {
            return String(repeating: "    ", count: indentLevel)
        }
        
        return serialize(map: self)
    }
}
