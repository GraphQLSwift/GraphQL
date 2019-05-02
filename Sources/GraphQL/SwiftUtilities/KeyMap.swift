/**
 * Creates a dictionary from an array, given a function to produce the keys
 * for each value in the array.
 *
 * This provides a convenient lookup for the array items if the key function
 * produces unique results.
 *
 *     let phoneBook = [
 *         ["name": "Jon", "num": "555-1234"],
 *         ["name": "Jenny", "num": "867-5309"],
 *     ]
 *
 *     // ["Jon": ["name": "Jon", "num": "555-1234"],
 *     //   Jenny: ["name": "Jenny", "num": "867-5309"]]
 *     let entriesByName = phoneBook.keyMap({ $0.name })
 *
 *     // ["name": "Jenny", "num": "857-6309"]
 *     let jennyEntry = entriesByName["Jenny"]
 *
 */
extension Array {
    func keyMap(_ keyFunction: (Element) -> String) -> [String: Element] {
        return self.reduce([:]) { map, item in
            var mapCopy = map
            mapCopy[keyFunction(item)] = item
            return mapCopy
        }
    }
}
