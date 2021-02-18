import XCTest
import NIO
import RxSwift
@testable import GraphQL

class SubscriptionTests : XCTestCase {
    
    private func createSubscription(
        pubsub:Observable<Email>,
        schema:GraphQLSchema = EmailSchema,
        document:Document = defaultSubscriptionAST
    ) -> EventLoopFuture<SubscriptionResult> {
        
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        
        // TODO figure out how to generate the subscription
//        return subscribe(
//            schema: schema,
//            documentAST: document,
//            eventLoopGroup: eventLoopGroup
//        )
        
        // TODO Remove placeholder below
        return eventLoopGroup.next().makeSucceededFuture(SubscriptionResult.failure(GraphQLError(message:"PLACEHOLDER")))
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

let emails = [
    Email(
        from: "joe@graphql.org",
        subject: "Hello",
        message: "Hello World",
        unread: false
    )
]

func importantEmail(priority: Int) -> Observable<EmailEvent> {
    let inbox = Inbox(emails: emails)
    let emailObs = Observable.from(emails)
    let emailEventObs = emailObs.map { email -> EmailEvent in
        return EmailEvent(email: email, inbox: inbox)
    }
    return emailEventObs
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

let EmailSchema = try! GraphQLSchema(
    query: try! GraphQLObjectType(
        name: "Query",
        fields: [
            "inbox": GraphQLField(
                type: InboxType
            )
        ]
    ),
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
                resolve: { _, arguments, _, _ in
                    let priority = arguments["priority"].int!
                    return importantEmail(priority: priority)
                }
    //            subscribe: subscribeFn // TODO Fill in the subscribe function
            )
        ]
    )
)
