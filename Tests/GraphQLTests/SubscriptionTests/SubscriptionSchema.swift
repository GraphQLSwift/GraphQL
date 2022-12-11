@testable import GraphQL
import NIO

#if compiler(>=5.5) && canImport(_Concurrency)

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

    struct Inbox: Encodable {
        let emails: [Email]
    }

    struct EmailEvent: Encodable {
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

    let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)

    @available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
    class EmailDb {
        var emails: [Email]
        let publisher: SimplePubSub<Any>

        init() {
            emails = [
                Email(
                    from: "joe@graphql.org",
                    subject: "Hello",
                    message: "Hello World",
                    unread: false
                ),
            ]
            publisher = SimplePubSub<Any>()
        }

        /// Adds a new email to the database and triggers all observers
        func trigger(email: Email) {
            emails.append(email)
            publisher.emit(event: email)
        }

        func stop() {
            publisher.cancel()
        }

        /// Returns the default email schema, with standard resolvers.
        func defaultSchema() throws -> GraphQLSchema {
            return try emailSchemaWithResolvers(
                resolve: { emailAny, _, _, eventLoopGroup, _ throws -> EventLoopFuture<Any?> in
                    if let email = emailAny as? Email {
                        return eventLoopGroup.next().makeSucceededFuture(EmailEvent(
                            email: email,
                            inbox: Inbox(emails: self.emails)
                        ))
                    } else {
                        throw GraphQLError(message: "\(type(of: emailAny)) is not Email")
                    }
                },
                subscribe: { _, args, _, eventLoopGroup, _ throws -> EventLoopFuture<Any?> in
                    let priority = args["priority"].int ?? 0
                    let filtered = self.publisher.subscribe().stream
                        .filterStream { emailAny throws in
                            if let email = emailAny as? Email {
                                return email.priority >= priority
                            } else {
                                return true
                            }
                        }
                    return eventLoopGroup.next()
                        .makeSucceededFuture(ConcurrentEventStream<Any>(filtered))
                }
            )
        }

        /// Generates a subscription to the database using the default schema and resolvers
        func subscription(
            query: String,
            variableValues: [String: Map] = [:]
        ) throws -> SubscriptionEventStream {
            return try createSubscription(
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
    ) throws -> SubscriptionEventStream {
        let result = try graphqlSubscribe(
            queryStrategy: SerialFieldExecutionStrategy(),
            mutationStrategy: SerialFieldExecutionStrategy(),
            subscriptionStrategy: SerialFieldExecutionStrategy(),
            instrumentation: NoOpInstrumentation,
            schema: schema,
            request: query,
            rootValue: (),
            context: (),
            eventLoopGroup: eventLoopGroup,
            variableValues: variableValues,
            operationName: nil
        ).wait()

        if let stream = result.stream {
            return stream
        } else {
            throw result.errors.first! // We may have more than one...
        }
    }

#endif
