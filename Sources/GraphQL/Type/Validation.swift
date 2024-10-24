/**
 * Implements the "Type Validation" sub-sections of the specification's
 * "Type System" section.
 *
 * Validation runs synchronously, returning an array of encountered errors, or
 * an empty array if no errors were encountered and the Schema is valid.
 */
func validateSchema(
    schema: GraphQLSchema
) throws -> [GraphQLError] {
    // If this Schema has already been validated, return the previous results.
    if let validationErrors = schema.validationErrors {
        return validationErrors
    }

    // Validate the schema, producing a list of errors.
    let context = SchemaValidationContext(schema: schema)
    validateRootTypes(context: context)
    validateDirectives(context: context)
    try validateTypes(context: context)

    // Persist the results of validation before returning to ensure validation
    // does not run multiple times for this schema.
    let errors = context.getErrors()
    schema.validationErrors = errors
    return errors
}

/**
 * Utility function which asserts a schema is valid by throwing an error if
 * it is invalid.
 */
func assertValidSchema(schema: GraphQLSchema) throws {
    let errors = try validateSchema(schema: schema)
    if !errors.isEmpty {
        throw GraphQLError(message: errors.map { error in error.message }.joined(separator: "\n\n"))
    }
}

class SchemaValidationContext {
    var _errors: [GraphQLError]
    let schema: GraphQLSchema

    init(schema: GraphQLSchema) {
        _errors = []
        self.schema = schema
    }

    func reportError(
        message: String,
        nodes: [Node?]
    ) {
        let _nodes = nodes.compactMap { $0 }
        _errors.append(GraphQLError(message: message, nodes: _nodes))
    }

    func reportError(
        message: String,
        node: Node?
    ) {
        let _nodes = [node].compactMap { $0 }
        _errors.append(GraphQLError(message: message, nodes: _nodes))
    }

    func getErrors() -> [GraphQLError] {
        return _errors
    }
}

func validateRootTypes(context: SchemaValidationContext) {
    let schema = context.schema

    if schema.queryType == nil {
        context.reportError(message: "Query root type must be provided.", node: schema.astNode)
    }

    var rootTypesMap = [GraphQLObjectType: [OperationType]]()
    for operationType in OperationType.allCases {
        switch operationType {
        case .query:
            if let queryType = schema.queryType {
                var operationTypes = rootTypesMap[queryType] ?? []
                operationTypes.append(operationType)
                rootTypesMap[queryType] = operationTypes
            }
        case .mutation:
            if let mutationType = schema.mutationType {
                var operationTypes = rootTypesMap[mutationType] ?? []
                operationTypes.append(operationType)
                rootTypesMap[mutationType] = operationTypes
            }
        case .subscription:
            if let subscriptionType = schema.subscriptionType {
                var operationTypes = rootTypesMap[subscriptionType] ?? []
                operationTypes.append(operationType)
                rootTypesMap[subscriptionType] = operationTypes
            }
        }
    }

    for (rootType, operationTypes) in rootTypesMap {
        if operationTypes.count > 1 {
            let operationList = operationTypes.map { $0.rawValue }.andList()
            context.reportError(
                message: "All root types must be different, \"\(rootType)\" type is used as \(operationList) root types.",
                nodes: operationTypes.map { operationType in
                    getOperationTypeNode(schema: schema, operation: operationType)
                }
            )
        }
    }
}

func getOperationTypeNode(
    schema: GraphQLSchema,
    operation: OperationType
) -> Node? {
    let nodes: [SchemaDefinition?] = [schema.astNode]
    // TODO: Add schema operation extension support
//    nodes.append(contentsOf: schema.extensionASTNodes)
    return nodes.flatMap { schemaNode in
        schemaNode?.operationTypes ?? []
    }.find { operationNode in operationNode.operation == operation }?.type
}

func validateDirectives(context: SchemaValidationContext) {
    for directive in context.schema.directives {
        // Ensure they are named correctly.
        validateName(context: context, name: directive.name, astNode: directive.astNode)

        if directive.locations.count == 0 {
            context.reportError(
                message: "Directive @\(directive.name) must include 1 or more locations.",
                node: directive.astNode
            )
        }

        // Ensure the arguments are valid.
        for arg in directive.args {
            // Ensure they are named correctly.
            validateName(context: context, name: arg.name, astNode: arg.astNode)

            if isRequiredArgument(arg), arg.deprecationReason != nil {
                context.reportError(
                    message: "Required argument @\(directive.name)(\(arg.name):) cannot be deprecated.",
                    nodes: [
                        getDeprecatedDirectiveNode(directives: arg.astNode?.directives),
                        arg.astNode?.type,
                    ]
                )
            }
        }
    }
}

func validateName(
    context: SchemaValidationContext,
    name: String,
    astNode: Node?
) {
    // Ensure names are valid, however introspection types opt out.
    if name.hasPrefix("__") {
        context.reportError(
            message: "Name \"\(name)\" must not begin with \"__\", which is reserved by GraphQL introspection.",
            node: astNode
        )
    }
}

func validateTypes(context: SchemaValidationContext) throws {
    let validateInputObjectCircularRefs =
        try createInputObjectCircularRefsValidator(context: context)
    let typeMap = context.schema.typeMap
    for type in typeMap.values {
        var astNode: Node?

        if let type = type as? GraphQLObjectType {
            astNode = type.astNode

            // Ensure fields are valid
            try validateFields(context: context, type: type)

            // Ensure objects implement the interfaces they claim to.
            try validateInterfaces(context: context, type: type)
        } else if let type = type as? GraphQLInterfaceType {
            astNode = type.astNode

            // Ensure fields are valid.
            try validateFields(context: context, type: type)

            // Ensure interfaces implement the interfaces they claim to.
            try validateInterfaces(context: context, type: type)
        } else if let type = type as? GraphQLUnionType {
            astNode = type.astNode

            // Ensure Unions include valid member types.
            try validateUnionMembers(context: context, union: type)
        } else if let type = type as? GraphQLEnumType {
            astNode = type.astNode

            // Ensure Enums have valid values.
            validateEnumValues(context: context, enumType: type)
        } else if let type = type as? GraphQLInputObjectType {
            astNode = type.astNode

            // Ensure Input Object fields are valid.
            try validateInputFields(context: context, inputObj: type)

            // Ensure Input Objects do not contain non-nullable circular references
            try validateInputObjectCircularRefs(type)
        } else if let type = type as? GraphQLScalarType {
            astNode = type.astNode
        }

        // Ensure it is named correctly (excluding introspection types).
        if let astNode = astNode, !isIntrospectionType(type: type) {
            validateName(context: context, name: type.name, astNode: astNode)
        }
    }
}

func validateFields(
    context: SchemaValidationContext,
    type: GraphQLObjectType
) throws {
    let fields = try type.getFields()

    // Objects and Interfaces both must define one or more fields.
    if fields.count == 0 {
        var nodes: [Node?] = [type.astNode]
        nodes.append(contentsOf: type.extensionASTNodes)
        context.reportError(message: "Type \(type) must define one or more fields.", nodes: nodes)
    }

    for field in fields.values {
        // Ensure they are named correctly.
        validateName(context: context, name: field.name, astNode: field.astNode)

        // Ensure the arguments are valid
        for arg in field.args {
            let argName = arg.name

            // Ensure they are named correctly.
            validateName(context: context, name: arg.name, astNode: arg.astNode)

            // Ensure the type is an input type
            if !isInputType(type: arg.type) {
                context.reportError(
                    message: "The type of \(type).\(field.name)(\(argName):) must be Input " +
                        "Type but got: \(arg.type).",
                    node: arg.astNode?.type
                )
            }

            if isRequiredArgument(arg), arg.deprecationReason != nil {
                context.reportError(
                    message: "Required argument \(type).\(field.name)(\(argName):) cannot be deprecated.",
                    nodes: [
                        getDeprecatedDirectiveNode(directives: arg.astNode?.directives),
                        arg.astNode?.type,
                    ]
                )
            }
        }
    }
}

func validateFields(
    context: SchemaValidationContext,
    type: GraphQLInterfaceType
) throws {
    let fields = try type.getFields()

    // Objects and Interfaces both must define one or more fields.
    if fields.count == 0 {
        var nodes: [Node?] = [type.astNode]
        nodes.append(contentsOf: type.extensionASTNodes)
        context.reportError(message: "Type \(type) must define one or more fields.", nodes: nodes)
    }

    for field in fields.values {
        // Ensure they are named correctly.
        validateName(context: context, name: field.name, astNode: field.astNode)

        // Ensure the arguments are valid
        for arg in field.args {
            let argName = arg.name

            // Ensure they are named correctly.
            validateName(context: context, name: arg.name, astNode: arg.astNode)

            // Ensure the type is an input type
            if !isInputType(type: arg.type) {
                context.reportError(
                    message: "The type of \(type).\(field.name)(\(argName):) must be Input " +
                        "Type but got: \(arg.type).",
                    node: arg.astNode?.type
                )
            }

            if isRequiredArgument(arg), arg.deprecationReason != nil {
                context.reportError(
                    message: "Required argument \(type).\(field.name)(\(argName):) cannot be deprecated.",
                    nodes: [
                        getDeprecatedDirectiveNode(directives: arg.astNode?.directives),
                        arg.astNode?.type,
                    ]
                )
            }
        }
    }
}

func validateInterfaces(
    context: SchemaValidationContext,
    type: GraphQLObjectType
) throws {
    var ifaceTypeNames = Set<String>()
    for iface in try type.getInterfaces() {
        if type == iface {
            context.reportError(
                message: "Type \(type) cannot implement itself because it would create a circular reference.",
                nodes: getAllImplementsInterfaceNodes(type: type, iface: iface)
            )
            continue
        }

        if ifaceTypeNames.contains(iface.name) {
            context.reportError(
                message: "Type \(type) can only implement \(iface.name) once.",
                nodes: getAllImplementsInterfaceNodes(type: type, iface: iface)
            )
            continue
        }

        ifaceTypeNames.insert(iface.name)

        try validateTypeImplementsAncestors(context: context, type: type, iface: iface)
        try validateTypeImplementsInterface(context: context, type: type, iface: iface)
    }
}

func validateInterfaces(
    context: SchemaValidationContext,
    type: GraphQLInterfaceType
) throws {
    var ifaceTypeNames = Set<String>()
    for iface in try type.getInterfaces() {
        if type == iface {
            context.reportError(
                message: "Type \(type) cannot implement itself because it would create a circular reference.",
                nodes: getAllImplementsInterfaceNodes(type: type, iface: iface)
            )
            continue
        }

        if ifaceTypeNames.contains(iface.name) {
            context.reportError(
                message: "Type \(type) can only implement \(iface.name) once.",
                nodes: getAllImplementsInterfaceNodes(type: type, iface: iface)
            )
            continue
        }

        ifaceTypeNames.insert(iface.name)

        try validateTypeImplementsAncestors(context: context, type: type, iface: iface)
        try validateTypeImplementsInterface(context: context, type: type, iface: iface)
    }
}

func validateTypeImplementsInterface(
    context: SchemaValidationContext,
    type: GraphQLObjectType,
    iface: GraphQLInterfaceType
) throws {
    let typeFieldMap = try type.getFields()

    // Assert each interface field is implemented.
    for ifaceField in try iface.getFields().values {
        let fieldName = ifaceField.name
        let typeField = typeFieldMap[fieldName]

        // Assert interface field exists on type.
        guard let typeField = typeField else {
            var nodes: [Node?] = [ifaceField.astNode, type.astNode]
            nodes.append(contentsOf: type.extensionASTNodes)
            context.reportError(
                message: "Interface field \(iface.name).\(fieldName) expected but \(type) does not provide it.",
                nodes: nodes
            )
            continue
        }

        // Assert interface field type is satisfied by type field type, by being
        // a valid subtype. (covariant)
        if try !isTypeSubTypeOf(context.schema, typeField.type, ifaceField.type) {
            context.reportError(
                message: "Interface field \(iface.name).\(fieldName) expects type " +
                    "\(ifaceField.type) but \(type).\(fieldName) " +
                    "is type \(typeField.type).",
                nodes: [ifaceField.astNode?.type, typeField.astNode?.type]
            )
        }

        // Assert each interface field arg is implemented.
        for ifaceArg in ifaceField.args {
            let argName = ifaceArg.name
            let typeArg = typeField.args.find { arg in arg.name == argName }

            // Assert interface field arg exists on object field.
            guard let typeArg = typeArg else {
                context.reportError(
                    message: "Interface field argument \(iface.name).\(fieldName)(\(argName):) expected but \(type).\(fieldName) does not provide it.",
                    nodes: [ifaceArg.astNode, typeField.astNode]
                )
                continue
            }

            // Assert interface field arg type matches object field arg type.
            // (invariant)
            // TODO: change to contravariant?
            if !isEqualType(ifaceArg.type, typeArg.type) {
                context.reportError(
                    message: "Interface field argument \(iface.name).\(fieldName)(\(argName):) " +
                        "expects type \(ifaceArg.type) but " +
                        "\(type).\(fieldName)(\(argName):) is type " +
                        "\(typeArg.type).",
                    nodes: [ifaceArg.astNode?.type, typeArg.astNode?.type]
                )
            }

            // TODO: validate default values?
        }

        // Assert additional arguments must not be required.
        for typeArg in typeField.args {
            let argName = typeArg.name
            let ifaceArg = ifaceField.args.find { arg in arg.name == argName }
            if ifaceArg == nil, isRequiredArgument(typeArg) {
                context.reportError(
                    message: "Argument \"\(type).\(fieldName)(\(argName):)\" must not be required type \"\(typeArg.type)\" if not provided by the Interface field \"\(iface.name).\(fieldName)\".",
                    nodes: [typeArg.astNode, ifaceField.astNode]
                )
            }
        }
    }
}

func validateTypeImplementsInterface(
    context: SchemaValidationContext,
    type: GraphQLInterfaceType,
    iface: GraphQLInterfaceType
) throws {
    let typeFieldMap = try type.getFields()

    // Assert each interface field is implemented.
    for ifaceField in try iface.getFields().values {
        let fieldName = ifaceField.name
        let typeField = typeFieldMap[fieldName]

        // Assert interface field exists on type.
        guard let typeField = typeField else {
            var nodes: [Node?] = [ifaceField.astNode, type.astNode]
            nodes.append(contentsOf: type.extensionASTNodes)
            context.reportError(
                message: "Interface field \(iface.name).\(fieldName) expected but \(type) does not provide it.",
                nodes: nodes
            )
            continue
        }

        // Assert interface field type is satisfied by type field type, by being
        // a valid subtype. (covariant)
        if try !isTypeSubTypeOf(context.schema, typeField.type, ifaceField.type) {
            context.reportError(
                message: "Interface field \(iface.name).\(fieldName) expects type " +
                    "\(ifaceField.type) but \(type).\(fieldName) " +
                    "is type \(typeField.type).",
                nodes: [ifaceField.astNode?.type, typeField.astNode?.type]
            )
        }

        // Assert each interface field arg is implemented.
        for ifaceArg in ifaceField.args {
            let argName = ifaceArg.name
            let typeArg = typeField.args.find { arg in arg.name == argName }

            // Assert interface field arg exists on object field.
            guard let typeArg = typeArg else {
                context.reportError(
                    message: "Interface field argument \(iface.name).\(fieldName)(\(argName):) expected but \(type).\(fieldName) does not provide it.",
                    nodes: [ifaceArg.astNode, typeField.astNode]
                )
                continue
            }

            // Assert interface field arg type matches object field arg type.
            // (invariant)
            // TODO: change to contravariant?
            if !isEqualType(ifaceArg.type, typeArg.type) {
                context.reportError(
                    message: "Interface field argument \(iface.name).\(fieldName)(\(argName):) " +
                        "expects type \(ifaceArg.type) but " +
                        "\(type).\(fieldName)(\(argName):) is type " +
                        "\(typeArg.type).",
                    nodes: [ifaceArg.astNode?.type, typeArg.astNode?.type]
                )
            }

            // TODO: validate default values?
        }

        // Assert additional arguments must not be required.
        for typeArg in typeField.args {
            let argName = typeArg.name
            let ifaceArg = ifaceField.args.find { arg in arg.name == argName }
            if ifaceArg == nil, isRequiredArgument(typeArg) {
                context.reportError(
                    message: "Argument \"\(type).\(fieldName)(\(argName):)\" must not be required type \"\(typeArg.type)\" if not provided by the Interface field \"\(iface.name).\(fieldName)\".",
                    nodes: [typeArg.astNode, ifaceField.astNode]
                )
            }
        }
    }
}

func validateTypeImplementsAncestors(
    context: SchemaValidationContext,
    type: GraphQLObjectType,
    iface: GraphQLInterfaceType
) throws {
    let ifaceInterfaces = try type.getInterfaces()
    for transitive in try iface.getInterfaces() {
        if !ifaceInterfaces.contains(transitive) {
            var nodes: [Node?] = getAllImplementsInterfaceNodes(type: iface, iface: transitive)
            nodes.append(contentsOf: getAllImplementsInterfaceNodes(type: type, iface: iface))
            context.reportError(
                message: transitive == type
                    ?
                    "Type \(type) cannot implement \(iface.name) because it would create a circular reference."
                    :
                    "Type \(type) must implement \(transitive.name) because it is implemented by \(iface.name).",
                nodes: nodes
            )
        }
    }
}

func validateTypeImplementsAncestors(
    context: SchemaValidationContext,
    type: GraphQLInterfaceType,
    iface: GraphQLInterfaceType
) throws {
    let ifaceInterfaces = try type.getInterfaces()
    for transitive in try iface.getInterfaces() {
        if !ifaceInterfaces.contains(transitive) {
            var nodes: [Node?] = getAllImplementsInterfaceNodes(type: iface, iface: transitive)
            nodes.append(contentsOf: getAllImplementsInterfaceNodes(type: type, iface: iface))
            context.reportError(
                message: transitive == type
                    ?
                    "Type \(type) cannot implement \(iface.name) because it would create a circular reference."
                    :
                    "Type \(type) must implement \(transitive.name) because it is implemented by \(iface.name).",
                nodes: nodes
            )
        }
    }
}

func validateUnionMembers(
    context: SchemaValidationContext,
    union: GraphQLUnionType
) throws {
    let memberTypes = try union.getTypes()

    if memberTypes.count == 0 {
        var nodes: [Node?] = [union.astNode]
        nodes.append(contentsOf: union.extensionASTNodes)
        context.reportError(
            message: "Union type \(union.name) must define one or more member types.",
            nodes: nodes
        )
    }

    var includedTypeNames = Set<String>()
    for memberType in memberTypes {
        if includedTypeNames.contains(memberType.name) {
            context.reportError(
                message: "Union type \(union.name) can only include type \(memberType) once.",
                nodes: getUnionMemberTypeNodes(union: union, typeName: memberType.name)
            )
            continue
        }
        includedTypeNames.insert(memberType.name)
    }
}

func validateEnumValues(
    context: SchemaValidationContext,
    enumType: GraphQLEnumType
) {
    let enumValues = enumType.values

    if enumValues.count == 0 {
        var nodes: [Node?] = [enumType.astNode]
        nodes.append(contentsOf: enumType.extensionASTNodes)
        context.reportError(
            message: "Enum type \(enumType) must define one or more values.",
            nodes: nodes
        )
    }

    for enumValue in enumValues {
        // Ensure valid name.
        validateName(context: context, name: enumValue.name, astNode: enumValue.astNode)
    }
}

func validateInputFields(
    context: SchemaValidationContext,
    inputObj: GraphQLInputObjectType
) throws {
    let fields = try inputObj.getFields().values

    if fields.count == 0 {
        var nodes: [Node?] = [inputObj.astNode]
        nodes.append(contentsOf: inputObj.extensionASTNodes)
        context.reportError(
            message: "Input Object type \(inputObj.name) must define one or more fields.",
            nodes: nodes
        )
    }

    // Ensure the arguments are valid
    for field in fields {
        // Ensure they are named correctly.
        validateName(context: context, name: field.name, astNode: field.astNode)

        // Ensure the type is an input type
        if !isInputType(type: field.type) {
            context.reportError(
                message: "The type of \(inputObj.name).\(field.name) must be Input Type " +
                    "but got: \(field.type).",
                node: field.astNode?.type
            )
        }

        if isRequiredInputField(field), field.deprecationReason != nil {
            context.reportError(
                message: "Required input field \(inputObj.name).\(field.name) cannot be deprecated.",
                nodes: [
                    getDeprecatedDirectiveNode(directives: field.astNode?.directives),
                    field.astNode?.type,
                ]
            )
        }

        if inputObj.isOneOf {
            validateOneOfInputObjectField(type: inputObj, field: field, context: context)
        }
    }
}

func validateOneOfInputObjectField(
    type: GraphQLInputObjectType,
    field: InputObjectFieldDefinition,
    context: SchemaValidationContext
) {
    if field.type is GraphQLNonNull {
        context.reportError(
            message: "OneOf input field \(type).\(field.name) must be nullable.",
            node: field.astNode?.type
        )
    }

    if field.defaultValue != nil {
        context.reportError(
            message: "OneOf input field \(type).\(field.name) cannot have a default value.",
            node: field.astNode
        )
    }
}

func createInputObjectCircularRefsValidator(
    context: SchemaValidationContext
) throws -> (GraphQLInputObjectType) throws -> Void {
    // Modified copy of algorithm from 'src/validation/rules/NoFragmentCycles.js'.
    // Tracks already visited types to maintain O(N) and to ensure that cycles
    // are not redundantly reported.
    var visitedTypes = Set<GraphQLInputObjectType>()

    // Array of types nodes used to produce meaningful errors
    var fieldPath: [InputObjectFieldDefinition] = []

    // Position in the type path
    var fieldPathIndexByTypeName: [String: Int] = [:]

    return detectCycleRecursive

    // This does a straight-forward DFS to find cycles.
    // It does not terminate when a cycle is found but continues to explore
    // the graph to find all possible cycles.
    func detectCycleRecursive(inputObj: GraphQLInputObjectType) throws {
        if visitedTypes.contains(inputObj) {
            return
        }

        visitedTypes.insert(inputObj)
        fieldPathIndexByTypeName[inputObj.name] = fieldPath.count

        let fields = try inputObj.getFields().values
        for field in fields {
            if
                let nonNullType = field.type as? GraphQLNonNull,
                let fieldType = nonNullType.ofType as? GraphQLInputObjectType
            {
                let cycleIndex = fieldPathIndexByTypeName[fieldType.name]

                fieldPath.append(field)
                if let cycleIndex = cycleIndex {
                    let cyclePath = fieldPath[cycleIndex ..< fieldPath.count]
                    let pathStr = cyclePath.map { fieldObj in fieldObj.name }.joined(separator: ".")
                    context.reportError(
                        message: "Cannot reference Input Object \"\(fieldType)\" within itself through a series of non-null fields: \"\(pathStr)\".",
                        nodes: cyclePath.map { fieldObj in fieldObj.astNode }
                    )
                } else {
                    try detectCycleRecursive(inputObj: fieldType)
                }
                fieldPath.removeLast()
            }
        }

        fieldPathIndexByTypeName[inputObj.name] = nil
    }
}

func getAllImplementsInterfaceNodes(
    type: GraphQLObjectType,
    iface: GraphQLInterfaceType
) -> [NamedType] {
    var nodes: [NamedType] = []
    nodes.append(contentsOf: type.astNode?.interfaces ?? [])
    // TODO: Add extension support for interface conformance
//    nodes.append(contentsOf: type.extensionASTNodes.flatMap { $0.interfaces })
    return nodes.filter { ifaceNode in ifaceNode.name.value == iface.name }
}

func getAllImplementsInterfaceNodes(
    type: GraphQLInterfaceType,
    iface: GraphQLInterfaceType
) -> [NamedType] {
    var nodes: [NamedType] = []
    nodes.append(contentsOf: type.astNode?.interfaces ?? [])
    // TODO: Add extension support for interface conformance
//    nodes.append(contentsOf: type.extensionASTNodes.flatMap { $0.interfaces })
    return nodes.filter { ifaceNode in ifaceNode.name.value == iface.name }
}

func getUnionMemberTypeNodes(
    union: GraphQLUnionType,
    typeName: String
) -> [NamedType] {
    var nodes: [NamedType] = []
    nodes.append(contentsOf: union.astNode?.types ?? [])
    // TODO: Add extension support for union membership
//    nodes.append(contentsOf: union.extensionASTNodes.flatMap { $0.types })
    return nodes.filter { typeNode in typeNode.name.value == typeName }
}

func getDeprecatedDirectiveNode(
    directives: [Directive]?
) -> Directive? {
    return directives?.find { node in
        node.name.value == GraphQLDeprecatedDirective.name
    }
}
