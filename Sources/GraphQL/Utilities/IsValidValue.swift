/**
 * Given a `Map` value and a GraphQL type, determine if the value will be
 * accepted for that type. This is primarily useful for validating the
 * runtime values of query variables.
 */
func validate(value: Map, forType type: GraphQLInputType) throws -> [String] {
    // A value must be provided if the type is non-null.
    if let nonNullType = type as? GraphQLNonNull {
        guard let wrappedType = nonNullType.ofType as? GraphQLInputType else {
            throw GraphQLError(message: "Input non-null type must wrap another input type")
        }

        if value == .null {
            return ["Expected non-null value, found null."]
        }
        if value == .undefined {
            return ["Expected non-null value was not provided."]
        }

        return try validate(value: value, forType: wrappedType)
    }

    // If nullable, either null or undefined are allowed
    guard value != .null, value != .undefined else {
        return []
    }

    // Lists accept a non-list value as a list of one.
    if let listType = type as? GraphQLList {
        guard let itemType = listType.ofType as? GraphQLInputType else {
            throw GraphQLError(message: "Input list type must wrap another input type")
        }

        if case let .array(values) = value {
            var errors: [String] = []

            for (index, item) in values.enumerated() {
                let e = try validate(value: item, forType: itemType).map {
                    "In element #\(index): \($0)"
                }
                errors.append(contentsOf: e)
            }

            return errors
        }

        return try validate(value: value, forType: itemType)
    }

    // Input objects check each defined field.
    if let objectType = type as? GraphQLInputObjectType {
        guard case let .dictionary(dictionary) = value else {
            return ["Expected \"\(objectType.name)\", found not an object."]
        }

        let fields = objectType.fields
        var errors: [String] = []

        // Ensure every provided field is defined.
        for (providedField, _) in dictionary {
            if fields[providedField] == nil {
                errors.append("In field \"\(providedField)\": Unknown field.")
            }
        }

        // Ensure every defined field is valid.
        for (fieldName, field) in fields {
            let newErrors = try validate(value: value[fieldName], forType: field.type).map {
                "In field \"\(fieldName)\": \($0)"
            }

            errors.append(contentsOf: newErrors)
        }

        return errors
    }

    if let leafType = type as? GraphQLLeafType {
        // Scalar/Enum input checks to ensure the type can parse the value to
        // a non-null value.
        do {
            let parseResult = try leafType.parseValue(value: value)
            if parseResult == .null || parseResult == .undefined {
                return ["Expected type \"\(leafType.name)\", found \(value)."]
            }
        } catch {
            return ["Expected type \"\(leafType.name)\", found \(value)."]
        }

        return []
    }

    throw GraphQLError(message: "Provided type was not provided")
}
