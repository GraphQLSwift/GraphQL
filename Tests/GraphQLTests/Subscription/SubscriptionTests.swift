import XCTest
import NIO
import RxSwift
@testable import GraphQL


class SubscriptionTests : XCTestCase {
    
    /// Creates a subscription result for the input pub/sub, schema, and AST document
    private func createSubscription(
        pubsub:Observable<Any>,
        schema:GraphQLSchema? = nil,
        document:Document = defaultSubscriptionAST
    ) throws -> Observable<GraphQLResult> {
        
        var emails = [
            Email(
                from: "joe@graphql.org",
                subject: "Hello",
                message: "Hello World",
                unread: false
            )
        ]
        
        let testSchema = schema ?? emailSchemaWithResolvers(
            subscribe: {_, _, _, eventLoopGroup, _ throws -> EventLoopFuture<Any?> in
                return eventLoopGroup.next().makeSucceededFuture(pubsub)
            },
            resolve: {emailAny, _, _, eventLoopGroup, _ throws -> EventLoopFuture<Any?> in
                let email = emailAny as! Email
                emails.append(email)
                return eventLoopGroup.next().makeSucceededFuture(EmailEvent(
                    email: email,
                    inbox: Inbox(emails: emails)
                ))
            }
        )
        
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        
        let subscriptionResult = try subscribe(
            queryStrategy: SerialFieldExecutionStrategy(),
            mutationStrategy: SerialFieldExecutionStrategy(),
            subscriptionStrategy: SerialFieldExecutionStrategy(),
            instrumentation: NoOpInstrumentation,
            schema: testSchema,
            documentAST: document,
            rootValue: Void(),
            context: Void(),
            eventLoopGroup: eventLoopGroup,
            variableValues: [:],
            operationName: nil
        ).wait()
        
        switch subscriptionResult {
        case .success(let subscription):
            return subscription
        case .failure(let error):
            throw error
        }
    }
    
    // MARK: Basic test to see if publishing is working
    func testBasic() throws {
        let disposeBag = DisposeBag()
        let pubsub = PublishSubject<Any>()
        let subscription = try createSubscription(pubsub: pubsub)
        
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
            XCTAssertEqual(event.element, expected)
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
//    func testAcceptsMultipleSubscriptionFields() throws {
//        let pubsub = PublishSubject<Any>()
//        let subscriptionTypeMultiple = try GraphQLObjectType(
//            name: "Subscription",
//            fields: [
//                "importantEmail": GraphQLField (type: EmailEventType),
//                "notImportantEmail": GraphQLField (type: EmailEventType)
//            ]
//        )
//        let testSchema = try GraphQLSchema(
//            query: EmailQueryType,
//            subscription: subscriptionTypeMultiple
//        )
//        let subscription = try createSubscription(pubsub: pubsub, schema: testSchema)
//        pubsub.onNext(Email(
//            from: "yuzhi@graphql.org",
//            subject: "Alright",
//            message: "Tests are good",
//            unread: true
//        ))
//    }
//
//
//    // TODO Not working. I think it's because it's checking the Resolver return against the Schema-defined return type...
//    func testResolverReturningErrorSchema() throws {
//        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
//        let schema = emailSchemaWithResolvers(
//            subscribe: {_, _, _, eventLoopGroup, _ throws -> EventLoopFuture<Any?> in
//                return eventLoopGroup.next().makeSucceededFuture(GraphQLError(message: "test error"))
//            },
//            resolve: nil
//        )
//        let document = try parse(source: """
//            subscription {
//                importantEmail
//            }
//        """)
//        let result = try createSourceEventStream(
//            queryStrategy: SerialFieldExecutionStrategy(),
//            mutationStrategy: SerialFieldExecutionStrategy(),
//            subscriptionStrategy: SerialFieldExecutionStrategy(),
//            instrumentation: NoOpInstrumentation,
//            schema: schema,
//            documentAST: document,
//            rootValue: Void(),
//            context: Void(),
//            eventLoopGroup: eventLoopGroup
//        ).wait()
//
//        switch result {
//        case .success:
//            XCTFail()
//        case .failure(let error):
//            let expected = GraphQLError(message:"test error")
//            XCTAssertEqual(expected, error)
//        }
//    }
//
//    // Working!!!
//    func testResolverThrowingErrorSchema() throws {
//        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
//        let schema = emailSchemaWithResolvers(
//            subscribe: {_, _, _, eventLoopGroup, _ throws -> EventLoopFuture<Any?> in
//                throw GraphQLError(message: "test error")
//            },
//            resolve: nil
//        )
//        let document = try parse(source: """
//            subscription {
//                importantEmail
//            }
//        """)
//        let result = try createSourceEventStream(
//            queryStrategy: SerialFieldExecutionStrategy(),
//            mutationStrategy: SerialFieldExecutionStrategy(),
//            subscriptionStrategy: SerialFieldExecutionStrategy(),
//            instrumentation: NoOpInstrumentation,
//            schema: schema,
//            documentAST: document,
//            rootValue: Void(),
//            context: Void(),
//            eventLoopGroup: eventLoopGroup
//        ).wait()
//
//        switch result {
//        case .success(let observable):
//            XCTFail()
//        case .failure(let error):
//            let expected = GraphQLError(message:"test error")
//            XCTAssertEqual(expected, error)
//        }
//    }
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
