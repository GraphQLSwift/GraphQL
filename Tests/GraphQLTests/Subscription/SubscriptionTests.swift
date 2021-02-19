import XCTest
import NIO
import RxSwift
@testable import GraphQL

class SubscriptionTests : XCTestCase {
    
    private func createSubscription(
        pubsub:Observable<Any>,
        schema:GraphQLSchema = emailSchemaWithResolvers(subscribe: nil, resolve: nil),
        document:Document = defaultSubscriptionAST
    ) -> EventLoopFuture<SubscriptionResult> {
        
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        
        
        var emails = [
            Email(
                from: "joe@graphql.org",
                subject: "Hello",
                message: "Hello World",
                unread: false
            )
        ]

        func importantEmail(priority: Int) -> Observable<EmailEvent> {
            let inbox = Inbox(emails: emails)
            let emailSubject = PublishSubject<Email>()
            let emailEventSubject = emailSubject.map { email -> EmailEvent in
                emails.append(email)
                return EmailEvent(email: email, inbox: inbox)
            }
            return emailEventSubject
        }
        
        // TODO This seems weird and should probably be an object type
        let rootValue:[String:Any] = [
            "inbox": Inbox(emails: emails),
            "importantEmail": importantEmail
        ]
        
        return subscribe(
            queryStrategy: SerialFieldExecutionStrategy(),
            mutationStrategy: SerialFieldExecutionStrategy(),
            subscriptionStrategy: SerialFieldExecutionStrategy(),
            instrumentation: NoOpInstrumentation,
            schema: schema,
            documentAST: document,
            rootValue: rootValue,
            context: Void(),
            eventLoopGroup: eventLoopGroup,
            variableValues: [:],
            operationName: nil
        )
    }
    
    
    
    // TODO Delete me - this just goes thru the entire pipeline
    func testDELETEME() throws {
        let pubsub = PublishSubject<Any>()
        let testSchema = emailSchemaWithResolvers(
            subscribe: {_, _, _, eventLoopGroup, _ throws -> EventLoopFuture<Any?> in
                return eventLoopGroup.next().makeSucceededFuture(pubsub)
            },
            resolve: nil
        )
        let subscriptionResult = try createSubscription(pubsub: pubsub, schema: testSchema).wait()
        switch subscriptionResult {
        case .success(let subscription):
            let subscriber = subscription.subscribe {
                print("Event: \($0)")
            }
            pubsub.onNext(Email(
                from: "yuzhi@graphql.org",
                subject: "Alright",
                message: "Tests are good",
                unread: true
            ))
        case .failure(let error):
            throw error
        }
    }
    
    // MARK: Subscription Initialization Phase
    
    /// accepts multiple subscription fields defined in schema
    // TODO Finish up this test
    func testAcceptsMultipleSubscriptionFields() throws {
        let pubsub = PublishSubject<Any>()
        let subscriptionTypeMultiple = try GraphQLObjectType(
            name: "Subscription",
            fields: [
                "importantEmail": GraphQLField (type: EmailEventType),
                "notImportantEmail": GraphQLField (type: EmailEventType)
            ]
        )
        let testSchema = try GraphQLSchema(
            query: EmailQueryType,
            subscription: subscriptionTypeMultiple
        )
        let subscriptionResult = try createSubscription(pubsub: pubsub, schema: testSchema).wait()
        switch subscriptionResult {
        case .success:
            pubsub.onNext(Email(
                from: "yuzhi@graphql.org",
                subject: "Alright",
                message: "Tests are good",
                unread: true
            ))
        case .failure(let error):
            throw error
        }
    }
    
    
    // TODO Not working. I think it's because it's checking the Resolver return against the Schema-defined return type...
    func testResolverReturningErrorSchema() throws {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        let schema = emailSchemaWithResolvers(
            subscribe: {_, _, _, eventLoopGroup, _ throws -> EventLoopFuture<Any?> in
                return eventLoopGroup.next().makeSucceededFuture(GraphQLError(message: "test error"))
            },
            resolve: nil
        )
        let document = try parse(source: """
            subscription {
                importantEmail
            }
        """)
        let result = try createSourceEventStream(
            queryStrategy: SerialFieldExecutionStrategy(),
            mutationStrategy: SerialFieldExecutionStrategy(),
            subscriptionStrategy: SerialFieldExecutionStrategy(),
            instrumentation: NoOpInstrumentation,
            schema: schema,
            documentAST: document,
            rootValue: Void(),
            context: Void(),
            eventLoopGroup: eventLoopGroup
        ).wait()
        
        switch result {
        case .success:
            XCTFail()
        case .failure(let error):
            let expected = GraphQLError(message:"test error")
            XCTAssertEqual(expected, error)
        }
    }
    
    // Working!!!
    func testResolverThrowingErrorSchema() throws {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        let schema = emailSchemaWithResolvers(
            subscribe: {_, _, _, eventLoopGroup, _ throws -> EventLoopFuture<Any?> in
                throw GraphQLError(message: "test error")
            },
            resolve: nil
        )
        let document = try parse(source: """
            subscription {
                importantEmail
            }
        """)
        let result = try createSourceEventStream(
            queryStrategy: SerialFieldExecutionStrategy(),
            mutationStrategy: SerialFieldExecutionStrategy(),
            subscriptionStrategy: SerialFieldExecutionStrategy(),
            instrumentation: NoOpInstrumentation,
            schema: schema,
            documentAST: document,
            rootValue: Void(),
            context: Void(),
            eventLoopGroup: eventLoopGroup
        ).wait()
        
        switch result {
        case .success(let observable):
            XCTFail()
        case .failure(let error):
            let expected = GraphQLError(message:"test error")
            XCTAssertEqual(expected, error)
        }
    }
}

let defaultSubscriptionAST = try! parse(source: """
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

// MARK: Types
struct Email {
    let from:String
    let subject:String
    let message:String
    let unread:Bool
}

struct Inbox {
    let emails:[Email]
}

struct EmailEvent {
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
        // TODO figure out how to do searches
//            "unread": GraphQLField(
//                type: GraphQLInt,
//                resolve: { inbox, _, _, _ in
//                    (inbox as! InboxType).emails.
//                }
//            ),
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

func emailSchemaWithResolvers(subscribe: GraphQLFieldResolve?, resolve: GraphQLFieldResolve?) -> GraphQLSchema {
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
