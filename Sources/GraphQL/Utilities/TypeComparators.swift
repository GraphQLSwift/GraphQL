/**
 * Provided two types, return true if the types are equal (invariant).
 */
public func isEqualType(_ typeA: any GraphQLType, _ typeB: any GraphQLType) -> Bool {
    // Equivalent types are equal.
    if typeA == typeB {
        return true
    }

    // If either type is non-null, the other must also be non-null.
    if let typeA = typeA as? GraphQLNonNull, let typeB = typeB as? GraphQLNonNull {
        return isEqualType(typeA.ofType, typeB.ofType)
    }

    // If either type is a list, the other must also be a list.
    if let typeA = typeA as? GraphQLList, let typeB = typeB as? GraphQLList {
        return isEqualType(typeA.ofType, typeB.ofType)
    }

    // Otherwise the types are not equal.
    return false
}

func == (lhs: any GraphQLType, rhs: any GraphQLType) -> Bool {
    switch lhs {
    case let l as GraphQLScalarType:
        if let r = rhs as? GraphQLScalarType {
            return l == r
        }
    case let l as GraphQLObjectType:
        if let r = rhs as? GraphQLObjectType {
            return l == r
        }
    case let l as GraphQLInterfaceType:
        if let r = rhs as? GraphQLInterfaceType {
            return l == r
        }
    case let l as GraphQLUnionType:
        if let r = rhs as? GraphQLUnionType {
            return l == r
        }
    case let l as GraphQLEnumType:
        if let r = rhs as? GraphQLEnumType {
            return l == r
        }
    case let l as GraphQLInputObjectType:
        if let r = rhs as? GraphQLInputObjectType {
            return l == r
        }
    case let l as GraphQLList:
        if let r = rhs as? GraphQLList {
            return l == r
        }
    case let l as GraphQLNonNull:
        if let r = rhs as? GraphQLNonNull {
            return l == r
        }
    case let l as GraphQLTypeReference:
        if let r = rhs as? GraphQLTypeReference {
            return l.name == r.name
        }
    default:
        return false
    }

    return false
}

/**
 * Provided a type and a super type, return true if the first type is either
 * equal or a subset of the second super type (covariant).
 */
public func isTypeSubTypeOf(
    _ schema: GraphQLSchema,
    _ maybeSubType: any GraphQLType,
    _ superType: any GraphQLType
) throws -> Bool {
    // Equivalent type is a valid subtype
    if maybeSubType == superType {
        return true
    }

    // If superType is non-null, maybeSubType must also be non-null.
    if let superType = superType as? GraphQLNonNull {
        if let maybeSubType = maybeSubType as? GraphQLNonNull {
            return try isTypeSubTypeOf(schema, maybeSubType.ofType, superType.ofType)
        }

        return false
    } else if let maybeSubType = maybeSubType as? GraphQLNonNull {
        // If superType is nullable, maybeSubType may be non-null or nullable.
        return try isTypeSubTypeOf(schema, maybeSubType.ofType, superType)
    }

    // If superType type is a list, maybeSubType type must also be a list.
    if let superType = superType as? GraphQLList {
        if let maybeSubType = maybeSubType as? GraphQLList {
            return try isTypeSubTypeOf(schema, maybeSubType.ofType, superType.ofType)
        }

        return false
    } else if maybeSubType is GraphQLList {
        // If superType is not a list, maybeSubType must also be not a list.
        return false
    }

    // If superType type is an abstract type, check if it is super type of maybeSubType.
    if
        let superType = superType as? (any GraphQLAbstractType),
        let maybeSubType = maybeSubType as? GraphQLObjectType,
        schema.isSubType(
            abstractType: superType,
            maybeSubType: maybeSubType
       )
    {
        return true
    }
    
    if
        let superType = superType as? (any GraphQLAbstractType),
        let maybeSubType = maybeSubType as? GraphQLInterfaceType,
        schema.isSubType(
            abstractType: superType,
            maybeSubType: maybeSubType
        )
    {
        return true
    }

    // Otherwise, the child type is not a valid subtype of the parent type.
    return false
}

/**
 * Provided two composite types, determine if they "overlap". Two composite
 * types overlap when the Sets of possible concrete types for each intersect.
 *
 * This is often used to determine if a fragment of a given type could possibly
 * be visited in a context of another type.
 *
 * This function is commutative.
 */
func doTypesOverlap(
    schema: GraphQLSchema,
    typeA: any GraphQLCompositeType,
    typeB: any GraphQLCompositeType
) -> Bool {
    // Equivalent types overlap
    if typeA == typeB {
        return true
    }

    if let typeA = typeA as? (any GraphQLAbstractType) {
        if let typeB = typeB as? (any GraphQLAbstractType) {
            // If both types are abstract, then determine if there is any intersection
            // between possible concrete types of each.
            return schema.getPossibleTypes(abstractType: typeA).contains { typeA in
                schema.isSubType(
                    abstractType: typeB,
                    maybeSubType: typeA
                )
            }
        }

        if let typeB = typeB as? GraphQLObjectType {
            // Determine if the latter type is a possible concrete type of the former.
            return schema.isSubType(
                abstractType: typeA,
                maybeSubType: typeB
            )
        }
    }

    if let typeB = typeB as? (any GraphQLAbstractType) {
        // Determine if the former type is a possible concrete type of the latter.
        return schema.isSubType(
            abstractType: typeB,
            maybeSubType: typeA
        )
    }
    
    // Otherwise the types do not overlap.
    return false
}
