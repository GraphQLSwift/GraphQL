/**
 * Given an invalid input string and a list of valid options, returns a filtered
 * list of valid options sorted based on their similarity with the input.
 */
func suggestionList(
    input: String,
    options: [String]
) -> [String] {
    var optionsByDistance: [String: Int] = [:]
    let oLength = options.count
    let inputThreshold = input.utf8.count / 2

    for i in 0..<oLength {
        let distance = lexicalDistance(input, options[i])
        let threshold = max(inputThreshold, options[i].utf8.count / 2, 1)

        if distance <= threshold {
            optionsByDistance[options[i]] = distance
        }

    }
    return optionsByDistance.keys.sorted {
        optionsByDistance[$0]! - optionsByDistance[$1]! != 0
    }
}

/**
 * Computes the lexical distance between strings A and B.
 *
 * The "distance" between two strings is given by counting the minimum number
 * of edits needed to transform string A into string B. An edit can be an
 * insertion, deletion, or substitution of a single character, or a swap of two
 * adjacent characters.
 *
 * This distance can be useful for detecting typos in input or sorting
 *
 */
func lexicalDistance(_ a: String, _ b: String) -> Int {
    let aLength = a.utf8.count
    let bLength = b.utf8.count
    var d: [[Int]] = [[Int]](repeating: [Int](repeating: 0, count: bLength + 1), count: aLength + 1)

    for i in 0...aLength {
        d[i][0] = i
    }

    for j in 1...bLength {
        d[0][j] = j
    }

    for i in 1...aLength {
        for j in 1...bLength {
            let cost = a.charCode(at: i - 1) == b.charCode(at: j - 1) ? 0 : 1

            let stupidCompiler = min(d[i][j - 1] + 1, d[i - 1][j - 1] + cost)
            d[i][j] = min(d[i - 1][j] + 1, stupidCompiler)

            if i > 1 && j > 1 && a.charCode(at: i - 1) == b.charCode(at: j - 2) && a.charCode(at: i - 2) == b.charCode(at: j - 1) {
                d[i][j] = min(d[i][j], d[i - 2][j - 2] + cost)
            }
        }
    }
    
    return d[aLength][bLength]
}
