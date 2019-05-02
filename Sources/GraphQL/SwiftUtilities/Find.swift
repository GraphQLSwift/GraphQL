extension Array {
    func find(_ predicate: (Element) throws -> Bool) rethrows -> Element? {
        for item in self where try predicate(item) {
            return item
        }
        return nil
    }
}

extension Dictionary {
    func find(_ predicate: (Key, Value) throws -> Bool) rethrows -> Value? {
        for (key, value) in self where try predicate(key, value) {
            return value
        }
        return nil
    }
}
