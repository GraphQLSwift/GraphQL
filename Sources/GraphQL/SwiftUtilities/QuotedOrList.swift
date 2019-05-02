/**
 * Given ["A", "B", "C"] return "\"A\", \"B\", or \"C\"".
 */
func quotedOrList(items: [String]) -> String {
    let maxLength = min(5, items.count)
    let selected = items[0..<maxLength]

    return selected.map({ "\"" + $0 + "\"" }).enumerated().reduce("") { list, quoted in
        if selected.count == 1 {
            return quoted.element
        }

        let or = quoted.offset == 0 ? "" : (quoted.offset == selected.count - 1 ? " or " : ", ")
        return list + or + quoted.element
    }
}
