/**
 * Given an arbitrary Error, presumably thrown while attempting to execute a
 * GraphQL operation, produce a new GraphQLError aware of the location in the
 * document responsible for the original Error.
 */
func locatedError(originalError: Error, nodes: [Node], path: [IndexPathElement]) -> GraphQLError {
    // Note: this uses a brand-check to support GraphQL errors originating from
    // other contexts.
    if let originalError = originalError as? GraphQLError {
        return originalError
    }

    return GraphQLError(
        message: String(describing: originalError),
        nodes: nodes,
        path: path,
        originalError: originalError
    )
}
