/**
 * Given a `Map` value and a GraphQL type, determine if the value will be
 * accepted for that type. This is primarily useful for validating the
 * runtime values of query variables.
 */
func isValidValue(value: Map, type: GraphQLInputType) throws -> [String] {
    // A value must be provided if the type is non-null.
    if let type = type as? GraphQLNonNull {
        if value == .null {
            if let namedType = type.ofType as? GraphQLNamedType {
                return ["Expected \"\(namedType.name)!\", found null."]
            }

            return ["Expected non-null value, found null."]
        }

        return try isValidValue(value: value, type: type.ofType as! GraphQLInputType)
    }

    guard value != .null else {
        return []
    }

    // Lists accept a non-list value as a list of one.
    if let type = type as? GraphQLList {
        let itemType = type.ofType

        if case .array(let values) = value {
            var errors: [String] = []

            for (index, item) in values.enumerated() {
                let e = try isValidValue(value: item, type: itemType as! GraphQLInputType).map {
                    "In element #\(index): \($0)"
                }
                errors.append(contentsOf: e)
            }

            return errors
        }

        return try isValidValue(value: value, type: itemType as! GraphQLInputType)
    }

    // Input objects check each defined field.
    if let type = type as? GraphQLInputObjectType {
        guard case .dictionary(let dictionary) = value else {
            return ["Expected \"\(type.name)\", found not an object."]
        }

        let fields = type.fields
        var errors: [String] = []

        // Ensure every provided field is defined.
        for (providedField, _) in dictionary {
            if fields[providedField] == nil {
                errors.append("In field \"\(providedField)\": Unknown field.")
            }
        }

        // Ensure every defined field is valid.
        for (fieldName, field) in fields {
            let newErrors = try isValidValue(value: value[fieldName], type: field.type).map {
                "In field \"\(fieldName)\": \($0)"
            }

            errors.append(contentsOf: newErrors)
        }

        return errors
    }

    guard let type = type as? GraphQLLeafType else {
        fatalError("Must be input type")
    }
    
    // Scalar/Enum input checks to ensure the type can parse the value to
    // a non-null value.
    let parseResult = try type.parseValue(value: value)
    
    if parseResult == .null {
        return ["Expected type \"\(type.name)\", found \(value)."]
    }
    
    return []
}
