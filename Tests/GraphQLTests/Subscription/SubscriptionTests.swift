import XCTest
import NIO
import RxSwift
@testable import GraphQL


class SubscriptionTests : XCTestCase {
    
    // MARK: Basic test to see if publishing is working
    func testBasic() throws {
        let disposeBag = DisposeBag()
        let pubsub = PublishSubject<Any>()
        let subscription = try createDbAndSubscription(pubsub: pubsub, query: defaultQuery)
        
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
        let _ = subscription.subscribe { event in
            let payload = try! event.element!.wait()
            XCTAssertEqual(payload, expected)
        }.disposed(by: disposeBag)
        pubsub.onNext(Email(
            from: "yuzhi@graphql.org",
            subject: "Alright",
            message: "Tests are good",
            unread: true
        ))
    }


    // MARK: Subscription Initialization Phase

    /// accepts multiple subscription fields defined in schema
    func testAcceptsMultipleSubscriptionFields() throws {
        let disposeBag = DisposeBag()
        let pubsub = PublishSubject<Any>()
        
        var emails = defaultEmails
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
                            emails.append(email)
                            return eventLoopGroup.next().makeSucceededFuture(EmailEvent(
                                email: email,
                                inbox: Inbox(emails: emails)
                            ))
                        },
                        subscribe: {_, _, _, eventLoopGroup, _ throws -> EventLoopFuture<Any?> in
                            return eventLoopGroup.next().makeSucceededFuture(pubsub)
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
                            emails.append(email)
                            return eventLoopGroup.next().makeSucceededFuture(EmailEvent(
                                email: email,
                                inbox: Inbox(emails: emails)
                            ))
                        },
                        subscribe: {_, _, _, eventLoopGroup, _ throws -> EventLoopFuture<Any?> in
                            return eventLoopGroup.next().makeSucceededFuture(pubsub)
                        }
                    )
                ]
            )
        )
        let subscription = try createSubscription(pubsub: pubsub, schema: schema, query: defaultQuery)
        
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
        let _ = subscription.subscribe { event in
            let payload = try! event.element!.wait()
            XCTAssertEqual(payload, expected)
        }.disposed(by: disposeBag)
        pubsub.onNext(Email(
            from: "yuzhi@graphql.org",
            subject: "Alright",
            message: "Tests are good",
            unread: true
        ))
    }
    
    /// 'should only resolve the first field of invalid multi-field'
    func testInvalidMultiField() throws {
        let disposeBag = DisposeBag()
        let pubsub = PublishSubject<Any>()
        
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
                            return eventLoopGroup.next().makeSucceededFuture(pubsub)
                        }
                    ),
                    "notImportantEmail": GraphQLField(
                        type: EmailEventType,
                        resolve: {_, _, _, eventLoopGroup, _ throws -> EventLoopFuture<Any?> in
                            return eventLoopGroup.next().makeSucceededFuture(nil)
                        },
                        subscribe: {_, _, _, eventLoopGroup, _ throws -> EventLoopFuture<Any?> in
                            didResolveNonImportantEmail = true
                            return eventLoopGroup.next().makeSucceededFuture(pubsub)
                        }
                    )
                ]
            )
        )
        let subscription = try createSubscription(pubsub: pubsub, schema: schema, query: """
            subscription {
                importantEmail
                notImportantEmail
            }
        """)
        
        let _ = subscription.subscribe{ event in
            let _ = try! event.element!.wait()
        }.disposed(by: disposeBag)
        pubsub.onNext(Email(
            from: "yuzhi@graphql.org",
            subject: "Alright",
            message: "Tests are good",
            unread: true
        ))
        
        XCTAssertTrue(didResolveImportantEmail)
        XCTAssertFalse(didResolveNonImportantEmail)
    }
}

// MARK: Types
struct Email : Encodable {
    let from:String
    let subject:String
    let message:String
    let unread:Bool
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

let defaultQuery = """
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

let defaultEmails = [
    Email(
        from: "joe@graphql.org",
        subject: "Hello",
        message: "Hello World",
        unread: false
    )
]

/// Generates a default schema and email database, and returns the subscription
private func createDbAndSubscription(
    pubsub:Observable<Any>,
    query:String
) throws -> SubscriptionObservable {
    
    var emails = defaultEmails
    
    let schema = emailSchemaWithResolvers(
        resolve: {emailAny, _, _, eventLoopGroup, _ throws -> EventLoopFuture<Any?> in
            let email = emailAny as! Email
            emails.append(email)
            return eventLoopGroup.next().makeSucceededFuture(EmailEvent(
                email: email,
                inbox: Inbox(emails: emails)
            ))
        },
        subscribe: {_, _, _, eventLoopGroup, _ throws -> EventLoopFuture<Any?> in
            return eventLoopGroup.next().makeSucceededFuture(pubsub)
        }
    )
    
    return try createSubscription(pubsub: pubsub, schema: schema, query: query)
}

/// Generates a subscription from the given schema and query. It's expected that the database is managed by the caller.
private func createSubscription(
    pubsub: Observable<Any>,
    schema: GraphQLSchema,
    query: String
) throws -> SubscriptionObservable {
    let document = try parse(source: query)
    let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    let subscriptionOrError = try subscribe(
        queryStrategy: SerialFieldExecutionStrategy(),
        mutationStrategy: SerialFieldExecutionStrategy(),
        subscriptionStrategy: SerialFieldExecutionStrategy(),
        instrumentation: NoOpInstrumentation,
        schema: schema,
        documentAST: document,
        rootValue: Void(),
        context: Void(),
        eventLoopGroup: eventLoopGroup,
        variableValues: [:],
        operationName: nil
    ).wait()
    return try extractSubscription(subscriptionOrError)
}

private func emailSchemaWithResolvers(resolve: GraphQLFieldResolve?, subscribe: GraphQLFieldResolve?) -> GraphQLSchema {
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

private func extractSubscription(_ subscriptionResult: SubscriptionResult) throws -> SubscriptionObservable {
    switch subscriptionResult {
    case .success(let subscription):
        return subscription
    case .failure(let error):
        throw error
    }
}
