@testable import GraphQL

// MARK: Types

struct Email: Encodable {
    let from: String
    let subject: String
    let message: String
    let unread: Bool
    let priority: Int

    init(from: String, subject: String, message: String, unread: Bool, priority: Int = 0) {
        self.from = from
        self.subject = subject
        self.message = message
        self.unread = unread
        self.priority = priority
    }
}

struct Inbox: Encodable, Sendable {
    let emails: [Email]
}

struct EmailEvent: Encodable, Sendable {
    let email: Email
    let inbox: Inbox
}

// MARK: Schema

let EmailType = try! GraphQLObjectType(
    name: "Email",
    fields: [
        "from": GraphQLField(
            type: GraphQLString
        ),
        "subject": GraphQLField(
            type: GraphQLString
        ),
        "message": GraphQLField(
            type: GraphQLString
        ),
        "unread": GraphQLField(
            type: GraphQLBoolean
        ),
    ]
)
let InboxType = try! GraphQLObjectType(
    name: "Inbox",
    fields: [
        "emails": GraphQLField(
            type: GraphQLList(EmailType)
        ),
        "total": GraphQLField(
            type: GraphQLInt,
            resolve: { inbox, _, _, _ in
                (inbox as! Inbox).emails.count
            }
        ),
        "unread": GraphQLField(
            type: GraphQLInt,
            resolve: { inbox, _, _, _ in
                (inbox as! Inbox).emails.filter { $0.unread }.count
            }
        ),
    ]
)
let EmailEventType = try! GraphQLObjectType(
    name: "EmailEvent",
    fields: [
        "email": GraphQLField(
            type: EmailType
        ),
        "inbox": GraphQLField(
            type: InboxType
        ),
    ]
)
let EmailQueryType = try! GraphQLObjectType(
    name: "Query",
    fields: [
        "inbox": GraphQLField(
            type: InboxType
        ),
    ]
)

// MARK: Test Helpers

actor EmailDb {
    var emails: [Email]
    let publisher: SimplePubSub<Email>

    init() {
        emails = [
            Email(
                from: "joe@graphql.org",
                subject: "Hello",
                message: "Hello World",
                unread: false
            ),
        ]
        publisher = SimplePubSub<Email>()
    }

    /// Adds a new email to the database and triggers all observers
    func trigger(email: Email) async {
        emails.append(email)
        await publisher.emit(event: email)
    }

    func stop() async {
        await publisher.cancel()
    }

    /// Returns the default email schema, with standard resolvers.
    func defaultSchema() throws -> GraphQLSchema {
        return try emailSchemaWithResolvers(
            resolve: { emailAny, _, _, _ throws -> Any? in
                if let email = emailAny as? Email {
                    return await EmailEvent(
                        email: email,
                        inbox: Inbox(emails: self.emails)
                    )
                } else {
                    throw GraphQLError(message: "\(type(of: emailAny)) is not Email")
                }
            },
            subscribe: { _, args, _, _ throws -> Any? in
                let priority = args["priority"].int ?? 0
                let filtered = await self.publisher.subscribe().filter { email throws in
                    return email.priority >= priority
                }
                return filtered
            }
        )
    }

    /// Generates a subscription to the database using the default schema and resolvers
    func subscription(
        query: String,
        variableValues: [String: Map] = [:]
    ) async throws -> AsyncThrowingStream<GraphQLResult, Error> {
        return try await createSubscription(
            schema: defaultSchema(),
            query: query,
            variableValues: variableValues
        )
    }
}

/// Generates an email schema with the specified resolve and subscribe methods
func emailSchemaWithResolvers(
    resolve: GraphQLFieldResolve? = nil,
    subscribe: GraphQLFieldResolve? = nil
) throws -> GraphQLSchema {
    return try GraphQLSchema(
        query: EmailQueryType,
        subscription: try! GraphQLObjectType(
            name: "Subscription",
            fields: [
                "importantEmail": GraphQLField(
                    type: EmailEventType,
                    args: [
                        "priority": GraphQLArgument(
                            type: GraphQLInt
                        ),
                    ],
                    resolve: resolve,
                    subscribe: subscribe
                ),
            ]
        )
    )
}

/// Generates a subscription from the given schema and query. It's expected that the
/// resolver/database interactions are configured by the caller.
func createSubscription(
    schema: GraphQLSchema,
    query: String,
    variableValues: [String: Map] = [:]
) async throws -> AsyncThrowingStream<GraphQLResult, Error> {
    let result = try await graphqlSubscribe(
        queryStrategy: SerialFieldExecutionStrategy(),
        mutationStrategy: SerialFieldExecutionStrategy(),
        subscriptionStrategy: SerialFieldExecutionStrategy(),
        schema: schema,
        request: query,
        rootValue: (),
        context: (),
        variableValues: variableValues,
        operationName: nil
    )
    return try result.get()
}
