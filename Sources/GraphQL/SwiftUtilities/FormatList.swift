extension Collection where Element == String, Index == Int {
    /// Given ["A", "B", "C"] return "A, B, or C".
    func orList() -> String {
        return formatList("or")
    }

    /// Given ["A", "B", "C"] return "A, B, and C".
    func andList() -> String {
        return formatList("and")
    }

    private func formatList(_ conjunction: String) -> String {
        switch count {
        case 0:
            return ""
        case 1:
            return self[0]
        case 2:
            return joined(separator: " \(conjunction) ")
        default:
            let allButLast = self[0 ... count - 2]
            let lastItem = self[count - 1]

            return allButLast.joined(separator: ", ") + ", \(conjunction) \(lastItem)"
        }
    }
}
