public extension Error {
    var reflection: [String: AnyCodable] {
        let errorReflection: Mirror = Mirror(reflecting: self)
        return Dictionary(uniqueKeysWithValues: errorReflection.children.lazy.map({ (label: String?, value: Any) -> (String, AnyCodable)? in
            guard let key = label,
                  let codableValue = value as? Codable else {
                      return nil
            }
            
            return (key, AnyCodable(codableValue))
        }).compactMap { $0 })
    }
}
