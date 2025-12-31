import Foundation

public enum InvalidNameError: Error, CustomStringConvertible {
    case invalidName(String)

    public var description: String {
        switch self {
        case let .invalidName(name):
            return "Names must match /^[_a-zA-Z][_a-zA-Z0-9]*$/ but \(name) does not."
        }
    }
}

func assertValid(name: String) throws {
    let range = validNameRegex.rangeOfFirstMatch(
        in: name,
        options: [],
        range: NSRange(0 ..< name.utf16.count)
    )

    guard range.location != NSNotFound else {
        throw InvalidNameError.invalidName(name)
    }
}

private let validNameRegex = try! NSRegularExpression(
    pattern: "^[_a-zA-Z][_a-zA-Z0-9]*$",
    options: []
)
