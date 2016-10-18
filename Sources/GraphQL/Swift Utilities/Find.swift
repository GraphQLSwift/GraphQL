extension Array {
    func find(_ predicate: (Element) -> Bool) -> Element? {
        for item in self where predicate(item) {
            return item
        }
        return nil
    }
}

extension Dictionary {
    func find(_ predicate: (Key, Value) -> Bool) -> Value? {
        for (key, value) in self where predicate(key, value) {
            return value
        }
        return nil
    }
}

