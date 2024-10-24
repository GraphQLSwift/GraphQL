/**
 * Provided a collection of ASTs, presumably each from different files,
 * concatenate the ASTs together into batched AST, useful for validating many
 * GraphQL source files which together represent one conceptual application.
 */
func concatAST(
    documents: [Document]
) -> Document {
    var definitions: [Definition] = []
    for doc in documents {
        definitions.append(contentsOf: doc.definitions)
    }
    return Document(definitions: definitions)
}
