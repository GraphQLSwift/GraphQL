import Foundation

/// Converts an AST into a string, using one set of reasonable
/// formatting rules.
public func print(ast: Node) -> String {
    ast.printed
}

private protocol Printable {
    var printed: String { get }
}

private let MAX_LINE_LENGTH = 80

extension Name: Printable {
    var printed: String { value }
}

extension Variable: Printable {
    var printed: String { "$" + name }
}

// MARK: - Document

extension Document: Printable {
    var printed: String {
        // Since Definition is a protocol
        let definitions = definitions.map { $0 as? Printable }
        return join(definitions, "\n\n")
    }
}

extension OperationDefinition: Printable {
    var printed: String {
        let varDefs = wrap("(", join(variableDefinitions, ", "), ")")
        let prefix = join([
            operation.rawValue,
            join([name, varDefs]),
            join(directives, " "),
        ], " ")

        // Anonymous queries with no directives or variable definitions can use
        // the query short form.
        return (prefix == "query" ? "" : prefix + " ") + selectionSet
    }
}

extension VariableDefinition: Printable {
    var printed: String {
        variable + ": " + type.printed + wrap(" = ", defaultValue?.printed)
            + wrap(" ", join(directives, " "))
    }
}

extension SelectionSet: Printable {
    var printed: String {
        let selections = selections.map { $0 as? Printable }
        return block(selections)
    }
}

extension Field: Printable {
    var printed: String {
        let prefix = join([wrap("", alias, ": "), name], "")
        var argsLine = prefix + wrap("(", join(arguments, ", "), ")")

        if argsLine.count > MAX_LINE_LENGTH {
            argsLine = prefix + wrap("(\n", indent(join(arguments, "\n")), "\n)")
        }

        return join([
            argsLine,
            wrap(" ", join(directives, " ")),
            wrap(" ", selectionSet),
        ])
    }
}

extension Argument: Printable {
    var printed: String {
        return name + ": " + value.printed
    }
}

// TODO: Add Nullability Modifiers

// MARK: - Nullability Modifiers

//
//  ListNullabilityOperator: {
//    leave({ nullabilityAssertion }) {
//      return join(['[', nullabilityAssertion, ']']);
//    },
//  },
//
//  NonNullAssertion: {
//    leave({ nullabilityAssertion }) {
//      return join([nullabilityAssertion, '!']);
//    },
//  },
//
//  ErrorBoundary: {
//    leave({ nullabilityAssertion }) {
//      return join([nullabilityAssertion, '?']);
//    },
//  },

// MARK: - Fragments

extension FragmentSpread: Printable {
    var printed: String { "..." + name + wrap(" ", join(directives, " ")) }
}

extension InlineFragment: Printable {
    var printed: String {
        join([
            "...",
            wrap("on ", typeCondition),
            join(directives, " "),
            selectionSet,
        ], " ")
    }
}

extension FragmentDefinition: Printable {
    var printed: String {
        "fragment " + name + " on " + typeCondition + " " + wrap("", join(directives, " "), " ") +
            selectionSet
    }
}

// MARK: - Value

extension IntValue: Printable {
    var printed: String { value }
}

extension FloatValue: Printable {
    var printed: String { value }
}

extension StringValue: Printable {
    var printed: String {
        block == true ? printBlockString(value) : printString(value)
    }
}

extension BooleanValue: Printable {
    var printed: String { value ? "true" : "false" }
}

extension NullValue: Printable {
    var printed: String { "null" }
}

extension EnumValue: Printable {
    var printed: String { value }
}

extension ListValue: Printable {
    var printed: String {
        let values = values.map { $0 as? Printable }
        let valuesLine = "[" + join(values, ", ") + "]"

        if valuesLine.count > MAX_LINE_LENGTH {
            return "[\n" + indent(join(values, "\n")) + "\n]"
        }

        return valuesLine
    }
}

extension ObjectValue: Printable {
    var printed: String {
        let fieldsLine = "{ " + join(fields, ", ") + " }"

        if fieldsLine.count > MAX_LINE_LENGTH {
            return block(fields)
        }

        return fieldsLine
    }
}

extension ObjectField: Printable {
    var printed: String { name + ": " + value.printed }
}

// MARK: - Directive

extension Directive: Printable {
    var printed: String { "@" + name + wrap("(", join(arguments, ", "), ")") }
}

// MARK: - Type

extension NamedType: Printable {
    var printed: String { name.printed }
}

extension ListType: Printable {
    var printed: String { "[" + type.printed + "]" }
}

extension NonNullType: Printable {
    var printed: String { type.printed + "!" }
}

// MARK: - Type System Definitions

extension SchemaDefinition: Printable {
    var printed: String {
        wrap("", description, "\n") +
            join(["schema", join(directives, " "), block(operationTypes)], " ")
    }
}

extension OperationTypeDefinition: Printable {
    var printed: String { operation.rawValue + ": " + type }
}

extension ScalarTypeDefinition: Printable {
    var printed: String {
        wrap("", description, "\n") +
            join(["scalar", name.printed, join(directives, " ")], " ")
    }
}

extension ObjectTypeDefinition: Printable {
    var printed: String {
        wrap("", description, "\n") +
            join(
                [
                    "type",
                    name,
                    wrap("implements ", join(interfaces, " & ")),
                    join(directives, " "),
                    block(fields),
                ],
                " "
            )
    }
}

extension FieldDefinition: Printable {
    var printed: String {
        let prefix = wrap("", description, "\n") + name

        let args = hasMultilineItems(arguments) ?
            wrap("(\n", indent(join(arguments, "\n")), "\n)") :
            wrap("(", join(arguments, ", "), ")")

        return prefix + args + ": " + type.printed + wrap(" ", join(directives, " "))
    }
}

extension InputValueDefinition: Printable {
    var printed: String {
        wrap("", description, "\n") +
            join(
                [
                    name + ": " + type.printed,
                    wrap("= ", defaultValue?.printed),
                    join(directives, " "),
                ],
                " "
            )
    }
}

extension InterfaceTypeDefinition: Printable {
    var printed: String {
        wrap("", description, "\n") +
            join(
                [
                    "interface",
                    name,
                    wrap("implements ", join(interfaces, " & ")),
                    join(directives, " "),
                    block(fields),
                ],
                " "
            )
    }
}

extension UnionTypeDefinition: Printable {
    var printed: String {
        wrap("", description, "\n") +
            join(["union", name, join(directives, " "), wrap("= ", join(types, " | "))], " ")
    }
}

extension EnumTypeDefinition: Printable {
    var printed: String {
        wrap("", description, "\n") +
            join(["enum", name, join(directives, " "), block(values)], " ")
    }
}

extension EnumValueDefinition: Printable {
    var printed: String {
        wrap("", description, "\n") +
            join([name, join(directives, " ")], " ")
    }
}

extension InputObjectTypeDefinition: Printable {
    var printed: String {
        wrap("", description, "\n") +
            join(["input", name, join(directives, " "), block(fields)], " ")
    }
}

extension DirectiveDefinition: Printable {
    var printed: String {
        let prefix = wrap("", description, "\n") + "directive @" + name

        let args = hasMultilineItems(arguments) ?
            wrap("(\n", indent(join(arguments, "\n")), "\n)") :
            wrap("(", join(arguments, ", "), ")")

        return prefix + args + (repeatable ? " repeatable" : "") + " on " + join(locations, " | ")
    }
}

extension SchemaExtensionDefinition: Printable {
    var printed: String {
        join(["extend", definition], " ")
    }
}

extension ScalarExtensionDefinition: Printable {
    var printed: String {
        join(["extend", definition], " ")
    }
}

extension TypeExtensionDefinition: Printable {
    var printed: String {
        join(["extend", definition], " ")
    }
}

extension InterfaceExtensionDefinition: Printable {
    var printed: String {
        join(["extend", definition], " ")
    }
}

extension UnionExtensionDefinition: Printable {
    var printed: String {
        join(["extend", definition], " ")
    }
}

extension EnumExtensionDefinition: Printable {
    var printed: String {
        join(["extend", definition], " ")
    }
}

extension InputObjectExtensionDefinition: Printable {
    var printed: String {
        join(["extend", definition], " ")
    }
}

/// If content is not null or empty, then wrap with start and end, otherwise print an empty string.
private func wrap(_ start: String, _ content: String?, _ end: String = "") -> String {
    guard let content = content, !content.isEmpty else {
        return ""
    }
    return start + content + end
}

private func wrap(_ start: String, _ content: Printable?, _ end: String = "") -> String {
    wrap(start, content?.printed, end)
}

private func indent(_ string: String) -> String {
    wrap("  ", string.replacingOccurrences(of: "\n", with: "\n  "))
}

private func indent(_ string: Printable) -> String {
    indent(string.printed)
}

/// Given array, print an empty string if it is null or empty, otherwise
/// print all items together separated by separator if provided
private func join(_ array: [String?]?, _ seperator: String = "") -> String {
    array?.compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: seperator) ?? ""
}

private func join(_ array: [Printable?]?, _ seperator: String = "") -> String {
    join(array?.map { $0?.printed }, seperator)
}

/// Given array, print each item on its own line, wrapped in an indented `{ }` block.
private func block(_ array: [String?]?) -> String {
    wrap("{\n", indent(join(array, "\n")), "\n}")
}

private func block(_ array: [Printable?]?) -> String {
    block(array?.map { $0?.printed })
}

private func hasMultilineItems(_ array: [String]?) -> Bool {
    // FIXME: https://github.com/graphql/graphql-js/issues/2203
    array?.contains { x in x.contains { $0.isNewline } } ?? false
}

private func hasMultilineItems(_ array: [Printable]?) -> Bool {
    hasMultilineItems(array?.map { $0.printed })
}

private func + (lhs: String, rhs: Printable) -> String {
    lhs + rhs.printed
}

private func + (lhs: Printable, rhs: String) -> String {
    lhs.printed + rhs
}

extension String: Printable {
    fileprivate var printed: String { self }
}

private extension Node {
    var printed: String {
        (self as? Printable)?.printed ?? "UnknownNode"
    }
}

private extension Value {
    var printed: String {
        (self as? Printable)?.printed ?? "UnknownValue"
    }
}

private extension Selection {
    var printed: String {
        (self as? Printable)?.printed ?? "UnknownSelection"
    }
}

private extension Type {
    var printed: String {
        (self as? Printable)?.printed ?? "UnknownType"
    }
}
