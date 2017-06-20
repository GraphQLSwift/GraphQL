import Foundation

public enum InvalidNameError : Error, CustomStringConvertible {
    case invalidName(String)

    public var description: String {
        switch self {
        case .invalidName(let name):
            return "Names must match /^[_a-zA-Z][_a-zA-Z0-9]*$/ but \(name) does not."
        }
    }
}

func assertValid(name: String) throws {
    
    let regex = try NSRegularExpression(pattern: "^[_a-zA-Z][_a-zA-Z0-9]*$", options: [])

    let range = regex.rangeOfFirstMatch(in: name, options: [], range: NSRange(0..<name.utf16.count))

    guard range.location != NSNotFound else {
        throw InvalidNameError.invalidName(name)
    }
}
