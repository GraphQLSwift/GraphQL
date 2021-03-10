import XCTest
import NIO
import RxSwift
@testable import GraphQL

/// This follows the graphql-js testing, with deviations where noted.
class SubscriptionTests : XCTestCase {
    
    // MARK: Test primary graphqlSubscribe function
    
    /// This test is not present in graphql-js, but just tests basic functionality.
    func testGraphqlSubscribe() throws {
        let db = EmailDb()
        let schema = db.defaultSchema()
        let query = """
            subscription ($priority: Int = 0) {
                importantEmail(priority: $priority) {
                  email {
                    from
                    subject
                  }
                  inbox {
                    unread
                    total
                  }
                }
              }
        """
        
        let subscriptionResult = try graphqlSubscribe(
            schema: schema,
            request: query,
            eventLoopGroup: eventLoopGroup
        ).wait()
        guard let subscription = subscriptionResult.stream else {
            XCTFail(subscriptionResult.errors.description)
            return
        }
        guard let stream = subscription as? ObservableSubscriptionEventStream else {
            XCTFail("stream isn't ObservableSubscriptionEventStream")
            return
        }
        
        var currentResult = GraphQLResult()
        let _ = stream.observable.subscribe { event in
            currentResult = try! event.element!.wait()
        }.disposed(by: db.disposeBag)
        
        db.trigger(email: Email(
            from: "yuzhi@graphql.org",
            subject: "Alright",
            message: "Tests are good",
            unread: true
        ))
        
        XCTAssertEqual(currentResult, GraphQLResult(
            data: ["importantEmail": [
                "inbox":[
                    "total": 2,
                    "unread": 1
                ],
                "email":[
                    "subject": "Alright",
                    "from": "yuzhi@graphql.org"
                ]
            ]]
        ))
    }
    
    // MARK: Subscription Initialization Phase

    /// accepts multiple subscription fields defined in schema
    func testAcceptsMultipleSubscriptionFields() throws {
        let db = EmailDb()
        let schema = try GraphQLSchema(
            query: EmailQueryType,
            subscription: try! GraphQLObjectType(
                name: "Subscription",
                fields: [
                    "importantEmail": GraphQLField(
                        type: EmailEventType,
                        args: [
                            "priority": GraphQLArgument(
                                type: GraphQLInt
                            )
                        ],
                        resolve: {emailAny, _, _, eventLoopGroup, _ throws -> EventLoopFuture<Any?> in
                            let email = emailAny as! Email
                            return eventLoopGroup.next().makeSucceededFuture(EmailEvent(
                                email: email,
                                inbox: Inbox(emails: db.emails)
                            ))
                        },
                        subscribe: {_, _, _, eventLoopGroup, _ throws -> EventLoopFuture<Any?> in
                            return eventLoopGroup.next().makeSucceededFuture(db.publisher.toEventStream())
                        }
                    ),
                    "notImportantEmail": GraphQLField(
                        type: EmailEventType,
                        args: [
                            "priority": GraphQLArgument(
                                type: GraphQLInt
                            )
                        ],
                        resolve: {emailAny, _, _, eventLoopGroup, _ throws -> EventLoopFuture<Any?> in
                            let email = emailAny as! Email
                            return eventLoopGroup.next().makeSucceededFuture(EmailEvent(
                                email: email,
                                inbox: Inbox(emails: db.emails)
                            ))
                        },
                        subscribe: {_, _, _, eventLoopGroup, _ throws -> EventLoopFuture<Any?> in
                            return eventLoopGroup.next().makeSucceededFuture(db.publisher.toEventStream())
                        }
                    )
                ]
            )
        )
        let subscription = try createSubscription(schema: schema, query: """
            subscription ($priority: Int = 0) {
                importantEmail(priority: $priority) {
                  email {
                    from
                    subject
                  }
                  inbox {
                    unread
                    total
                  }
                }
              }
        """)
        guard let stream = subscription as? ObservableSubscriptionEventStream else {
            XCTFail("stream isn't ObservableSubscriptionEventStream")
            return
        }
        
        var currentResult = GraphQLResult()
        let _ = stream.observable.subscribe { event in
            currentResult = try! event.element!.wait()
        }.disposed(by: db.disposeBag)
        
        db.trigger(email: Email(
            from: "yuzhi@graphql.org",
            subject: "Alright",
            message: "Tests are good",
            unread: true
        ))
        
        XCTAssertEqual(currentResult, GraphQLResult(
            data: ["importantEmail": [
                "inbox":[
                    "total": 2,
                    "unread": 1
                ],
                "email":[
                    "subject": "Alright",
                    "from": "yuzhi@graphql.org"
                ]
            ]]
        ))
    }

    /// 'should only resolve the first field of invalid multi-field'
    ///
    /// Note that due to implementation details in Swift, this will not resolve the "first" one, but rather a random one of the two
    func testInvalidMultiField() throws {
        let db = EmailDb()

        var didResolveImportantEmail = false
        var didResolveNonImportantEmail = false

        let schema = try GraphQLSchema(
            query: EmailQueryType,
            subscription: try! GraphQLObjectType(
                name: "Subscription",
                fields: [
                    "importantEmail": GraphQLField(
                        type: EmailEventType,
                        resolve: {_, _, _, eventLoopGroup, _ throws -> EventLoopFuture<Any?> in
                            return eventLoopGroup.next().makeSucceededFuture(nil)
                        },
                        subscribe: {_, _, _, eventLoopGroup, _ throws -> EventLoopFuture<Any?> in
                            didResolveImportantEmail = true
                            return eventLoopGroup.next().makeSucceededFuture(db.publisher.toEventStream())
                        }
                    ),
                    "notImportantEmail": GraphQLField(
                        type: EmailEventType,
                        resolve: {_, _, _, eventLoopGroup, _ throws -> EventLoopFuture<Any?> in
                            return eventLoopGroup.next().makeSucceededFuture(nil)
                        },
                        subscribe: {_, _, _, eventLoopGroup, _ throws -> EventLoopFuture<Any?> in
                            didResolveNonImportantEmail = true
                            return eventLoopGroup.next().makeSucceededFuture(db.publisher.toEventStream())
                        }
                    )
                ]
            )
        )
        let subscription = try createSubscription(schema: schema, query: """
            subscription {
                importantEmail
                notImportantEmail
            }
        """)
        guard let stream = subscription as? ObservableSubscriptionEventStream else {
            XCTFail("stream isn't ObservableSubscriptionEventStream")
            return
        }
        
        let _ = stream.observable.subscribe{ event in
            let _ = try! event.element!.wait()
        }.disposed(by: db.disposeBag)
        db.trigger(email: Email(
            from: "yuzhi@graphql.org",
            subject: "Alright",
            message: "Tests are good",
            unread: true
        ))

        // One and only one should be true
        XCTAssertTrue(didResolveImportantEmail || didResolveNonImportantEmail)
        XCTAssertFalse(didResolveImportantEmail && didResolveNonImportantEmail)
    }

    // 'throws an error if schema is missing'
    // Not implemented because this is taken care of by Swift optional types

    // 'throws an error if document is missing'
    // Not implemented because this is taken care of by Swift optional types

    /// 'resolves to an error for unknown subscription field'
    func testErrorUnknownSubscriptionField() throws {
        let db = EmailDb()
        XCTAssertThrowsError(
            try db.subscription(query: """
                subscription {
                    unknownField
                }
                """
            )
        ) { error in
            let graphQLError = error as! GraphQLError
            XCTAssertEqual(graphQLError.message, "The subscription field 'unknownField' is not defined.")
            XCTAssertEqual(graphQLError.locations, [SourceLocation(line: 2, column: 5)])
        }
    }

    /// 'should pass through unexpected errors thrown in subscribe'
    func testPassUnexpectedSubscribeErrors() throws {
        let db = EmailDb()
        XCTAssertThrowsError(
            try db.subscription(query: "")
        )
    }

    /// 'throws an error if subscribe does not return an iterator'
    func testErrorIfSubscribeIsntIterator() throws {
        let schema = emailSchemaWithResolvers(
            resolve: {_, _, _, eventLoopGroup, _ throws -> EventLoopFuture<Any?> in
                return eventLoopGroup.next().makeSucceededFuture(nil)
            },
            subscribe: {_, _, _, eventLoopGroup, _ throws -> EventLoopFuture<Any?> in
                return eventLoopGroup.next().makeSucceededFuture("test")
            }
        )
        XCTAssertThrowsError(
            try createSubscription(schema: schema, query: """
                subscription {
                    importantEmail
                }
            """)
        ) { error in
            let graphQLError = error as! GraphQLError
            XCTAssertEqual(
                graphQLError.message,
                "Subscription field resolver must return EventStream<Any>. Received: 'test'"
            )
        }
    }

    /// 'resolves to an error for subscription resolver errors'
    func testErrorForSubscriptionResolverErrors() throws {
        func verifyError(schema: GraphQLSchema) {
            XCTAssertThrowsError(
                try createSubscription(schema: schema, query: """
                    subscription {
                        importantEmail
                    }
                """)
            ) { error in
                let graphQLError = error as! GraphQLError
                XCTAssertEqual(graphQLError.message, "test error")
            }
        }

        // Throwing an error
        verifyError(schema: emailSchemaWithResolvers(
            subscribe: {_, _, _, eventLoopGroup, _ throws -> EventLoopFuture<Any?> in
                throw GraphQLError(message: "test error")
            }
        ))

        // Resolving to an error
        verifyError(schema: emailSchemaWithResolvers(
            subscribe: {_, _, _, eventLoopGroup, _ throws -> EventLoopFuture<Any?> in
                return eventLoopGroup.next().makeSucceededFuture(GraphQLError(message: "test error"))
            }
        ))

        // Rejecting with an error
        verifyError(schema: emailSchemaWithResolvers(
            subscribe: {_, _, _, eventLoopGroup, _ throws -> EventLoopFuture<Any?> in
                return eventLoopGroup.next().makeFailedFuture(GraphQLError(message: "test error"))
            }
        ))
    }


    /// 'resolves to an error for source event stream resolver errors'
    // Tests above cover this

    /// 'resolves to an error if variables were wrong type'
    func testErrorVariablesWrongType() throws {
        let db = EmailDb()
        let query = """
            subscription ($priority: Int) {
                importantEmail(priority: $priority) {
                  email {
                    from
                    subject
                  }
                  inbox {
                    unread
                    total
                  }
                }
              }
        """

        XCTAssertThrowsError(
            try db.subscription(
                query: query,
                variableValues: [
                    "priority": "meow"
                ]
            )
        ) { error in
            let graphQLError = error as! GraphQLError
            XCTAssertEqual(
                graphQLError.message,
                "Variable \"$priority\" got invalid value \"meow\".\nExpected type \"Int\", found \"meow\"."
            )
        }
    }


    // MARK: Subscription Publish Phase

    /// 'produces a payload for a single subscriber'
    func testSingleSubscriber() throws {
        let db = EmailDb()
        let subscription = try db.subscription(query: """
            subscription ($priority: Int = 0) {
                importantEmail(priority: $priority) {
                  email {
                    from
                    subject
                  }
                  inbox {
                    unread
                    total
                  }
                }
              }
        """)
        guard let stream = subscription as? ObservableSubscriptionEventStream else {
            XCTFail("stream isn't ObservableSubscriptionEventStream")
            return
        }
        
        var currentResult = GraphQLResult()
        let _ = stream.observable.subscribe { event in
            currentResult = try! event.element!.wait()
        }.disposed(by: db.disposeBag)
        
        db.trigger(email: Email(
            from: "yuzhi@graphql.org",
            subject: "Alright",
            message: "Tests are good",
            unread: true
        ))
        XCTAssertEqual(currentResult, GraphQLResult(
            data: ["importantEmail": [
                "inbox":[
                    "total": 2,
                    "unread": 1
                ],
                "email":[
                    "subject": "Alright",
                    "from": "yuzhi@graphql.org"
                ]
            ]]
        ))
    }

    /// 'produces a payload for multiple subscribe in same subscription'
    func testMultipleSubscribers() throws {
        let db = EmailDb()
        let subscription = try db.subscription(query: """
            subscription ($priority: Int = 0) {
                importantEmail(priority: $priority) {
                  email {
                    from
                    subject
                  }
                  inbox {
                    unread
                    total
                  }
                }
              }
        """)
        guard let stream = subscription as? ObservableSubscriptionEventStream else {
            XCTFail("stream isn't ObservableSubscriptionEventStream")
            return
        }
        
        // Subscription 1
        var sub1Value = GraphQLResult()
        let _ = stream.observable.subscribe { event in
            sub1Value = try! event.element!.wait()
        }.disposed(by: db.disposeBag)
        
        // Subscription 2
        var sub2Value = GraphQLResult()
        let _ = stream.observable.subscribe { event in
            sub2Value = try! event.element!.wait()
        }.disposed(by: db.disposeBag)

        db.trigger(email: Email(
            from: "yuzhi@graphql.org",
            subject: "Alright",
            message: "Tests are good",
            unread: true
        ))
        
        let expected = GraphQLResult(
            data: ["importantEmail": [
                "inbox":[
                    "total": 2,
                    "unread": 1
                ],
                "email":[
                    "subject": "Alright",
                    "from": "yuzhi@graphql.org"
                ]
            ]]
        )
        
        XCTAssertEqual(sub1Value, expected)
        XCTAssertEqual(sub2Value, expected)
    }
    
    /// 'produces a payload per subscription event'
    func testPayloadPerEvent() throws {
        let db = EmailDb()
        let subscription = try db.subscription(query: """
            subscription ($priority: Int = 0) {
                importantEmail(priority: $priority) {
                  email {
                    from
                    subject
                  }
                  inbox {
                    unread
                    total
                  }
                }
              }
        """)
        guard let stream = subscription as? ObservableSubscriptionEventStream else {
            XCTFail("stream isn't ObservableSubscriptionEventStream")
            return
        }
        
        var currentResult = GraphQLResult()
        let _ = stream.observable.subscribe { event in
            currentResult = try! event.element!.wait()
            print(currentResult)
        }.disposed(by: db.disposeBag)

        db.trigger(email: Email(
            from: "yuzhi@graphql.org",
            subject: "Alright",
            message: "Tests are good",
            unread: true
        ))
        XCTAssertEqual(currentResult, GraphQLResult(
            data: ["importantEmail": [
                "inbox":[
                    "total": 2,
                    "unread": 1
                ],
                "email":[
                    "subject": "Alright",
                    "from": "yuzhi@graphql.org"
                ]
            ]]
        ))
        
        db.trigger(email: Email(
            from: "hyo@graphql.org",
            subject: "Tools",
            message: "I <3 making things",
            unread: true
        ))
        XCTAssertEqual(currentResult, GraphQLResult(
            data: ["importantEmail": [
                "inbox":[
                    "total": 3,
                    "unread": 2
                ],
                "email":[
                    "subject": "Tools",
                    "from": "hyo@graphql.org"
                ]
            ]]
        ))
    }
    
    /// Tests that subscriptions use arguments correctly.
    /// This is not in the graphql-js tests.
    func testArguments() throws {
        let db = EmailDb()
        let subscription = try db.subscription(query: """
            subscription ($priority: Int = 5) {
                importantEmail(priority: $priority) {
                  email {
                    from
                    subject
                  }
                  inbox {
                    unread
                    total
                  }
                }
              }
        """)
        guard let stream = subscription as? ObservableSubscriptionEventStream else {
            XCTFail("stream isn't ObservableSubscriptionEventStream")
            return
        }
        
        var currentResult = GraphQLResult()
        let _ = stream.observable.subscribe { event in
            currentResult = try! event.element!.wait()
        }.disposed(by: db.disposeBag)

        db.trigger(email: Email(
            from: "yuzhi@graphql.org",
            subject: "Alright",
            message: "Tests are good",
            unread: true,
            priority: 7
        ))
        let firstMessageExpected = GraphQLResult(
            data: ["importantEmail": [
                "inbox":[
                    "total": 2,
                    "unread": 1
                ],
                "email":[
                    "subject": "Alright",
                    "from": "yuzhi@graphql.org"
                ]
            ]]
        )
        XCTAssertEqual(currentResult, firstMessageExpected)
        
        // Low priority email shouldn't trigger an event
        db.trigger(email: Email(
            from: "hyo@graphql.org",
            subject: "Not Important",
            message: "Ignore this email",
            unread: true,
            priority: 2
        ))
        XCTAssertEqual(currentResult, firstMessageExpected)
        
        // Higher priority one should trigger again
        db.trigger(email: Email(
            from: "hyo@graphql.org",
            subject: "Tools",
            message: "I <3 making things",
            unread: true,
            priority: 5
        ))
        XCTAssertEqual(currentResult, GraphQLResult(
            data: ["importantEmail": [
                "inbox":[
                    "total": 4,
                    "unread": 3
                ],
                "email":[
                    "subject": "Tools",
                    "from": "hyo@graphql.org"
                ]
            ]]
        ))
    }

    /// 'should not trigger when subscription is already done'
    func testNoTriggerAfterDone() throws {
        let db = EmailDb()
        let subscription = try db.subscription(query: """
            subscription ($priority: Int = 0) {
                importantEmail(priority: $priority) {
                  email {
                    from
                    subject
                  }
                  inbox {
                    unread
                    total
                  }
                }
              }
        """)
        guard let stream = subscription as? ObservableSubscriptionEventStream else {
            XCTFail("stream isn't ObservableSubscriptionEventStream")
            return
        }
        
        var currentResult = GraphQLResult()
        let subscriber = stream.observable.subscribe { event in
            currentResult = try! event.element!.wait()
        }
        
        let expected = GraphQLResult(
            data: ["importantEmail": [
                "inbox":[
                    "total": 2,
                    "unread": 1
                ],
                "email":[
                    "subject": "Alright",
                    "from": "yuzhi@graphql.org"
                ]
            ]]
        )
        
        db.trigger(email: Email(
            from: "yuzhi@graphql.org",
            subject: "Alright",
            message: "Tests are good",
            unread: true
        ))
        XCTAssertEqual(currentResult, expected)

        subscriber.dispose()

        // This should not trigger an event.
        db.trigger(email: Email(
            from: "hyo@graphql.org",
            subject: "Tools",
            message: "I <3 making things",
            unread: true
        ))
        XCTAssertEqual(currentResult, expected)
    }

    /// 'should not trigger when subscription is thrown'
    // Not necessary - Pub/sub implementation handles throwing/closing itself.

    /// 'event order is correct for multiple publishes'
    // Not necessary - Pub/sub implementation handles event ordering

    /// 'should handle error during execution of source event'
    func testErrorDuringSubscription() throws {
        let db = EmailDb()

        let schema = emailSchemaWithResolvers(
            resolve: {emailAny, _, _, eventLoopGroup, _ throws -> EventLoopFuture<Any?> in
                let email = emailAny as! Email
                if email.subject == "Goodbye" { // Force the system to fail here.
                    throw GraphQLError(message:"Never leave.")
                }
                return eventLoopGroup.next().makeSucceededFuture(EmailEvent(
                    email: email,
                    inbox: Inbox(emails: db.emails)
                ))
            },
            subscribe: {_, _, _, eventLoopGroup, _ throws -> EventLoopFuture<Any?> in
                return eventLoopGroup.next().makeSucceededFuture(db.publisher.toEventStream())
            }
        )

        let subscription = try createSubscription(schema: schema, query: """
            subscription {
                importantEmail {
                    email {
                        subject
                    }
                }
            }
        """)
        guard let stream = subscription as? ObservableSubscriptionEventStream else {
            XCTFail("stream isn't ObservableSubscriptionEventStream")
            return
        }
        
        var currentResult = GraphQLResult()
        let _ = stream.observable.subscribe { event in
            currentResult = try! event.element!.wait()
        }.disposed(by: db.disposeBag)
        
        db.trigger(email: Email(
            from: "yuzhi@graphql.org",
            subject: "Hello",
            message: "Tests are good",
            unread: true
        ))
        XCTAssertEqual(currentResult, GraphQLResult(
            data: ["importantEmail": [
                "email":[
                    "subject": "Hello"
                ]
            ]]
        ))

        // An error in execution is presented as such.
        db.trigger(email: Email(
            from: "yuzhi@graphql.org",
            subject: "Goodbye",
            message: "Tests are good",
            unread: true
        ))
        XCTAssertEqual(currentResult, GraphQLResult(
            data: ["importantEmail": nil],
            errors: [
                GraphQLError(message: "Never leave.")
            ]
        ))

        // However that does not close the response event stream. Subsequent events are still executed.
        db.trigger(email: Email(
            from: "yuzhi@graphql.org",
            subject: "Bonjour",
            message: "Tests are good",
            unread: true
        ))
        XCTAssertEqual(currentResult, GraphQLResult(
            data: ["importantEmail": [
                "email":[
                    "subject": "Bonjour"
                ]
            ]]
        ))
    }
    
    /// 'should pass through error thrown in source event stream'
    // Not necessary - Pub/sub implementation handles event erroring
    
    /// 'should resolve GraphQL error from source event stream'
    // Not necessary - Pub/sub implementation handles event erroring
    
    /// Test incorrect observable publish type errors
    func testErrorWrongObservableType() throws {
        let db = EmailDb()
        let subscription = try db.subscription(query: """
            subscription ($priority: Int = 0) {
                importantEmail(priority: $priority) {
                  email {
                    from
                    subject
                  }
                  inbox {
                    unread
                    total
                  }
                }
              }
        """)
        guard let stream = subscription as? ObservableSubscriptionEventStream else {
            XCTFail("stream isn't ObservableSubscriptionEventStream")
            return
        }
        
        var currentResult = GraphQLResult()
        let _ = stream.observable.subscribe { event in
            currentResult = try! event.element!.wait()
        }.disposed(by: db.disposeBag)
        
        db.publisher.onNext("String instead of email")
        
        XCTAssertEqual(currentResult, GraphQLResult(
            data: ["importantEmail": nil],
            errors: [
                GraphQLError(message: "String is not Email")
            ]
        ))
    }
}

// MARK: Types
struct Email : Encodable {
    let from:String
    let subject:String
    let message:String
    let unread:Bool
    let priority:Int
    
    init(from:String, subject:String, message:String, unread:Bool, priority:Int = 0) {
        self.from = from
        self.subject = subject
        self.message = message
        self.unread = unread
        self.priority = priority
    }
}

struct Inbox : Encodable {
    let emails:[Email]
}

struct EmailEvent : Encodable {
    let email:Email
    let inbox:Inbox
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
                (inbox as! Inbox).emails.filter({$0.unread}).count
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
        )
    ]
)
let EmailQueryType = try! GraphQLObjectType(
    name: "Query",
    fields: [
        "inbox": GraphQLField(
            type: InboxType
        )
    ]
)

// MARK: Test Helpers

let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)

class EmailDb {
    var emails: [Email]
    let publisher: PublishSubject<Any>
    let disposeBag: DisposeBag
    
    init() {
        emails = [
            Email(
                from: "joe@graphql.org",
                subject: "Hello",
                message: "Hello World",
                unread: false
            )
        ]
        publisher = PublishSubject<Any>()
        disposeBag = DisposeBag()
    }
    
    /// Adds a new email to the database and triggers all observers
    func trigger(email:Email) {
        emails.append(email)
        publisher.onNext(email)
    }
    
    /// Returns the default email schema, with standard resolvers.
    func defaultSchema() -> GraphQLSchema {
        return emailSchemaWithResolvers(
            resolve: {emailAny, _, _, eventLoopGroup, _ throws -> EventLoopFuture<Any?> in
                if let email = emailAny as? Email {
                    return eventLoopGroup.next().makeSucceededFuture(EmailEvent(
                        email: email,
                        inbox: Inbox(emails: self.emails)
                    ))
                } else {
                    throw GraphQLError(message: "\(type(of:emailAny)) is not Email")
                }
            },
            subscribe: {_, args, _, eventLoopGroup, _ throws -> EventLoopFuture<Any?> in
                let priority = args["priority"].int ?? 0
                let filtered = self.publisher.filter { emailAny throws in
                    if let email = emailAny as? Email {
                        return email.priority >= priority
                    } else {
                        return true
                    }
                }
                return eventLoopGroup.next().makeSucceededFuture(filtered.toEventStream())
            }
        )
    }
    
    /// Generates a subscription to the database using the default schema and resolvers
    func subscription (
        query:String,
        variableValues: [String: Map] = [:]
    ) throws -> SubscriptionEventStream {
        return try createSubscription(schema: defaultSchema(), query: query, variableValues: variableValues)
    }
}

/// Generates an email schema with the specified resolve and subscribe methods
private func emailSchemaWithResolvers(resolve: GraphQLFieldResolve? = nil, subscribe: GraphQLFieldResolve? = nil) -> GraphQLSchema {
    return try! GraphQLSchema(
        query: EmailQueryType,
        subscription: try! GraphQLObjectType(
            name: "Subscription",
            fields: [
                "importantEmail": GraphQLField(
                    type: EmailEventType,
                    args: [
                        "priority": GraphQLArgument(
                            type: GraphQLInt
                        )
                    ],
                    resolve: resolve,
                    subscribe: subscribe
                )
            ]
        )
    )
}

/// Generates a subscription from the given schema and query. It's expected that the resolver/database interactions are configured by the caller.
private func createSubscription(
    schema: GraphQLSchema,
    query: String,
    variableValues: [String: Map] = [:]
) throws -> SubscriptionEventStream {
    let document = try parse(source: query)
    let result = try subscribe(
        queryStrategy: SerialFieldExecutionStrategy(),
        mutationStrategy: SerialFieldExecutionStrategy(),
        subscriptionStrategy: SerialFieldExecutionStrategy(),
        instrumentation: NoOpInstrumentation,
        schema: schema,
        documentAST: document,
        rootValue: Void(),
        context: Void(),
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
