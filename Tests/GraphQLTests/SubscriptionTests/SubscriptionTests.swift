import GraphQL
import NIO
import XCTest

#if compiler(>=5.5) && canImport(_Concurrency)

    @available(macOS 12, iOS 15, watchOS 8, tvOS 15, *)
    /// This follows the graphql-js testing, with deviations where noted.
    class SubscriptionTests: XCTestCase {
        let timeoutDuration = 0.5 // in seconds

        // MARK: Test primary graphqlSubscribe function

        /// This test is not present in graphql-js, but just tests basic functionality.
        func testGraphqlSubscribe() async throws {
            let db = EmailDb()
            let schema = try db.defaultSchema()
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
            guard let stream = subscription as? ConcurrentEventStream else {
                XCTFail("stream isn't ConcurrentEventStream")
                return
            }
            var iterator = stream.stream.makeAsyncIterator()

            db.trigger(email: Email(
                from: "yuzhi@graphql.org",
                subject: "Alright",
                message: "Tests are good",
                unread: true
            ))
            db.stop()
            let result = try await iterator.next()?.get()
            XCTAssertEqual(
                result,
                GraphQLResult(
                    data: ["importantEmail": [
                        "email": [
                            "from": "yuzhi@graphql.org",
                            "subject": "Alright",
                        ],
                        "inbox": [
                            "unread": 1,
                            "total": 2,
                        ],
                    ]]
                )
            )
        }

        // MARK: Subscription Initialization Phase

        /// accepts multiple subscription fields defined in schema
        func testAcceptsMultipleSubscriptionFields() async throws {
            let db = EmailDb()
            let schema = try GraphQLSchema(
                query: EmailQueryType,
                subscription: GraphQLObjectType(
                    name: "Subscription",
                    fields: [
                        "importantEmail": GraphQLField(
                            type: EmailEventType,
                            args: [
                                "priority": GraphQLArgument(
                                    type: GraphQLInt
                                ),
                            ],
                            resolve: { emailAny, _, _, eventLoopGroup, _ throws -> EventLoopFuture<Any?> in
                                guard let email = emailAny as? Email else {
                                    throw GraphQLError(
                                        message: "Source is not Email type: \(type(of: emailAny))"
                                    )
                                }
                                return eventLoopGroup.next().makeSucceededFuture(EmailEvent(
                                    email: email,
                                    inbox: Inbox(emails: db.emails)
                                ))
                            },
                            subscribe: { _, _, _, eventLoopGroup, _ throws -> EventLoopFuture<Any?> in
                                eventLoopGroup.next().makeSucceededFuture(db.publisher.subscribe())
                            }
                        ),
                        "notImportantEmail": GraphQLField(
                            type: EmailEventType,
                            args: [
                                "priority": GraphQLArgument(
                                    type: GraphQLInt
                                ),
                            ],
                            resolve: { emailAny, _, _, eventLoopGroup, _ throws -> EventLoopFuture<Any?> in
                                guard let email = emailAny as? Email else {
                                    throw GraphQLError(
                                        message: "Source is not Email type: \(type(of: emailAny))"
                                    )
                                }
                                return eventLoopGroup.next().makeSucceededFuture(EmailEvent(
                                    email: email,
                                    inbox: Inbox(emails: db.emails)
                                ))
                            },
                            subscribe: { _, _, _, eventLoopGroup, _ throws -> EventLoopFuture<Any?> in
                                eventLoopGroup.next().makeSucceededFuture(db.publisher.subscribe())
                            }
                        ),
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
            guard let stream = subscription as? ConcurrentEventStream else {
                XCTFail("stream isn't ConcurrentEventStream")
                return
            }
            var iterator = stream.stream.makeAsyncIterator()

            db.trigger(email: Email(
                from: "yuzhi@graphql.org",
                subject: "Alright",
                message: "Tests are good",
                unread: true
            ))

            let result = try await iterator.next()?.get()
            XCTAssertEqual(
                result,
                GraphQLResult(
                    data: ["importantEmail": [
                        "email": [
                            "from": "yuzhi@graphql.org",
                            "subject": "Alright",
                        ],
                        "inbox": [
                            "unread": 1,
                            "total": 2,
                        ],
                    ]]
                )
            )
        }

        /// 'should only resolve the first field of invalid multi-field'
        ///
        /// Note that due to implementation details in Swift, this will not resolve the "first" one,
        /// but rather a random one of the two
        func testInvalidMultiField() async throws {
            let db = EmailDb()

            var didResolveImportantEmail = false
            var didResolveNonImportantEmail = false

            let schema = try GraphQLSchema(
                query: EmailQueryType,
                subscription: GraphQLObjectType(
                    name: "Subscription",
                    fields: [
                        "importantEmail": GraphQLField(
                            type: EmailEventType,
                            resolve: { _, _, _, eventLoopGroup, _ throws -> EventLoopFuture<Any?> in
                                eventLoopGroup.next().makeSucceededFuture(nil)
                            },
                            subscribe: { _, _, _, eventLoopGroup, _ throws -> EventLoopFuture<Any?> in
                                didResolveImportantEmail = true
                                return eventLoopGroup.next()
                                    .makeSucceededFuture(db.publisher.subscribe())
                            }
                        ),
                        "notImportantEmail": GraphQLField(
                            type: EmailEventType,
                            resolve: { _, _, _, eventLoopGroup, _ throws -> EventLoopFuture<Any?> in
                                eventLoopGroup.next().makeSucceededFuture(nil)
                            },
                            subscribe: { _, _, _, eventLoopGroup, _ throws -> EventLoopFuture<Any?> in
                                didResolveNonImportantEmail = true
                                return eventLoopGroup.next()
                                    .makeSucceededFuture(db.publisher.subscribe())
                            }
                        ),
                    ]
                )
            )
            let _ = try createSubscription(schema: schema, query: """
                subscription {
                    importantEmail {
                        email {
                            from
                        }
                    }
                    notImportantEmail {
                        email {
                            from
                        }
                    }
                }
            """)

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
                """)
            ) { error in
                guard let graphQLError = error as? GraphQLError else {
                    XCTFail("Error was not of type GraphQLError")
                    return
                }
                XCTAssertEqual(
                    graphQLError.message,
                    "Cannot query field \"unknownField\" on type \"Subscription\"."
                )
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
            let schema = try emailSchemaWithResolvers(
                resolve: { _, _, _, eventLoopGroup, _ throws -> EventLoopFuture<Any?> in
                    eventLoopGroup.next().makeSucceededFuture(nil)
                },
                subscribe: { _, _, _, eventLoopGroup, _ throws -> EventLoopFuture<Any?> in
                    eventLoopGroup.next().makeSucceededFuture("test")
                }
            )
            XCTAssertThrowsError(
                try createSubscription(schema: schema, query: """
                    subscription {
                        importantEmail {
                            email {
                                from
                            }
                        }
                    }
                """)
            ) { error in
                guard let graphQLError = error as? GraphQLError else {
                    XCTFail("Error was not of type GraphQLError")
                    return
                }
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
                            importantEmail {
                                email {
                                    from
                                }
                            }
                        }
                    """)
                ) { error in
                    guard let graphQLError = error as? GraphQLError else {
                        XCTFail("Error was not of type GraphQLError")
                        return
                    }
                    XCTAssertEqual(graphQLError.message, "test error")
                }
            }

            // Throwing an error
            try verifyError(schema: emailSchemaWithResolvers(
                subscribe: { _, _, _, _, _ throws -> EventLoopFuture<Any?> in
                    throw GraphQLError(message: "test error")
                }
            ))

            // Resolving to an error
            try verifyError(schema: emailSchemaWithResolvers(
                subscribe: { _, _, _, eventLoopGroup, _ throws -> EventLoopFuture<Any?> in
                    eventLoopGroup.next().makeSucceededFuture(GraphQLError(message: "test error"))
                }
            ))

            // Rejecting with an error
            try verifyError(schema: emailSchemaWithResolvers(
                subscribe: { _, _, _, eventLoopGroup, _ throws -> EventLoopFuture<Any?> in
                    eventLoopGroup.next().makeFailedFuture(GraphQLError(message: "test error"))
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
                        "priority": "meow",
                    ]
                )
            ) { error in
                guard let graphQLError = error as? GraphQLError else {
                    XCTFail("Error was not of type GraphQLError")
                    return
                }
                XCTAssertEqual(
                    graphQLError.message,
                    "Variable \"$priority\" got invalid value \"\"meow\"\".\nExpected type \"Int\", found \"meow\"."
                )
            }
        }

        // MARK: Subscription Publish Phase

        /// 'produces a payload for a single subscriber'
        func testSingleSubscriber() async throws {
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
            guard let stream = subscription as? ConcurrentEventStream else {
                XCTFail("stream isn't ConcurrentEventStream")
                return
            }
            var iterator = stream.stream.makeAsyncIterator()

            db.trigger(email: Email(
                from: "yuzhi@graphql.org",
                subject: "Alright",
                message: "Tests are good",
                unread: true
            ))
            db.stop()

            let result = try await iterator.next()?.get()
            XCTAssertEqual(
                result,
                GraphQLResult(
                    data: ["importantEmail": [
                        "email": [
                            "from": "yuzhi@graphql.org",
                            "subject": "Alright",
                        ],
                        "inbox": [
                            "unread": 1,
                            "total": 2,
                        ],
                    ]]
                )
            )
        }

        /// 'produces a payload for multiple subscribe in same subscription'
        func testMultipleSubscribers() async throws {
            let db = EmailDb()
            let subscription1 = try db.subscription(query: """
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
            guard let stream1 = subscription1 as? ConcurrentEventStream else {
                XCTFail("stream isn't ConcurrentEventStream")
                return
            }

            let subscription2 = try db.subscription(query: """
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
            guard let stream2 = subscription2 as? ConcurrentEventStream else {
                XCTFail("stream isn't ConcurrentEventStream")
                return
            }

            var iterator1 = stream1.stream.makeAsyncIterator()
            var iterator2 = stream2.stream.makeAsyncIterator()

            db.trigger(email: Email(
                from: "yuzhi@graphql.org",
                subject: "Alright",
                message: "Tests are good",
                unread: true
            ))

            let result1 = try await iterator1.next()?.get()
            let result2 = try await iterator2.next()?.get()

            let expected = GraphQLResult(
                data: ["importantEmail": [
                    "email": [
                        "from": "yuzhi@graphql.org",
                        "subject": "Alright",
                    ],
                    "inbox": [
                        "unread": 1,
                        "total": 2,
                    ],
                ]]
            )

            XCTAssertEqual(result1, expected)
            XCTAssertEqual(result2, expected)
        }

        /// 'produces a payload per subscription event'
        func testPayloadPerEvent() async throws {
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
            guard let stream = subscription as? ConcurrentEventStream else {
                XCTFail("stream isn't ConcurrentEventStream")
                return
            }
            var iterator = stream.stream.makeAsyncIterator()

            // A new email arrives!
            db.trigger(email: Email(
                from: "yuzhi@graphql.org",
                subject: "Alright",
                message: "Tests are good",
                unread: true
            ))
            let result1 = try await iterator.next()?.get()
            XCTAssertEqual(
                result1,
                GraphQLResult(
                    data: ["importantEmail": [
                        "email": [
                            "from": "yuzhi@graphql.org",
                            "subject": "Alright",
                        ],
                        "inbox": [
                            "unread": 1,
                            "total": 2,
                        ],
                    ]]
                )
            )

            // Another new email arrives
            db.trigger(email: Email(
                from: "hyo@graphql.org",
                subject: "Tools",
                message: "I <3 making things",
                unread: true
            ))
            let result2 = try await iterator.next()?.get()
            XCTAssertEqual(
                result2,
                GraphQLResult(
                    data: ["importantEmail": [
                        "email": [
                            "from": "hyo@graphql.org",
                            "subject": "Tools",
                        ],
                        "inbox": [
                            "unread": 2,
                            "total": 3,
                        ],
                    ]]
                )
            )
        }

        /// Tests that subscriptions use arguments correctly.
        /// This is not in the graphql-js tests.
        func testArguments() async throws {
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
            guard let stream = subscription as? ConcurrentEventStream else {
                XCTFail("stream isn't ConcurrentEventStream")
                return
            }

            var results = [GraphQLResult]()
            var expectation = XCTestExpectation()

            // So that the Task won't immediately be cancelled since the ConcurrentEventStream is
            // discarded
            let keepForNow = stream.map { event in
                event.map { result in
                    results.append(result)
                    expectation.fulfill()
                }
            }

            var expected = [GraphQLResult]()

            db.trigger(email: Email(
                from: "yuzhi@graphql.org",
                subject: "Alright",
                message: "Tests are good",
                unread: true,
                priority: 7
            ))
            expected.append(
                GraphQLResult(
                    data: ["importantEmail": [
                        "email": [
                            "from": "yuzhi@graphql.org",
                            "subject": "Alright",
                        ],
                        "inbox": [
                            "unread": 1,
                            "total": 2,
                        ],
                    ]]
                )
            )
            wait(for: [expectation], timeout: timeoutDuration)
            XCTAssertEqual(results, expected)

            // Low priority email shouldn't trigger an event
            expectation = XCTestExpectation()
            expectation.isInverted = true
            db.trigger(email: Email(
                from: "hyo@graphql.org",
                subject: "Not Important",
                message: "Ignore this email",
                unread: true,
                priority: 2
            ))
            wait(for: [expectation], timeout: timeoutDuration)
            XCTAssertEqual(results, expected)

            // Higher priority one should trigger again
            expectation = XCTestExpectation()
            db.trigger(email: Email(
                from: "hyo@graphql.org",
                subject: "Tools",
                message: "I <3 making things",
                unread: true,
                priority: 5
            ))
            expected.append(
                GraphQLResult(
                    data: ["importantEmail": [
                        "email": [
                            "from": "hyo@graphql.org",
                            "subject": "Tools",
                        ],
                        "inbox": [
                            "unread": 3,
                            "total": 4,
                        ],
                    ]]
                )
            )
            wait(for: [expectation], timeout: timeoutDuration)
            XCTAssertEqual(results, expected)

            // So that the Task won't immediately be cancelled since the ConcurrentEventStream is
            // discarded
            _ = keepForNow
        }

        /// 'should not trigger when subscription is already done'
        func testNoTriggerAfterDone() async throws {
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
            guard let stream = subscription as? ConcurrentEventStream else {
                XCTFail("stream isn't ConcurrentEventStream")
                return
            }

            var results = [GraphQLResult]()
            var expectation = XCTestExpectation()
            // So that the Task won't immediately be cancelled since the ConcurrentEventStream is
            // discarded
            let keepForNow = stream.map { event in
                event.map { result in
                    results.append(result)
                    expectation.fulfill()
                }
            }
            var expected = [GraphQLResult]()

            db.trigger(email: Email(
                from: "yuzhi@graphql.org",
                subject: "Alright",
                message: "Tests are good",
                unread: true
            ))
            expected.append(
                GraphQLResult(
                    data: ["importantEmail": [
                        "email": [
                            "from": "yuzhi@graphql.org",
                            "subject": "Alright",
                        ],
                        "inbox": [
                            "unread": 1,
                            "total": 2,
                        ],
                    ]]
                )
            )
            wait(for: [expectation], timeout: timeoutDuration)
            XCTAssertEqual(results, expected)

            db.stop()

            // This should not trigger an event.
            expectation = XCTestExpectation()
            expectation.isInverted = true
            db.trigger(email: Email(
                from: "hyo@graphql.org",
                subject: "Tools",
                message: "I <3 making things",
                unread: true
            ))

            // Ensure that the current result was the one before the db was stopped
            wait(for: [expectation], timeout: timeoutDuration)
            XCTAssertEqual(results, expected)

            // So that the Task won't immediately be cancelled since the ConcurrentEventStream is
            // discarded
            _ = keepForNow
        }

        /// 'should not trigger when subscription is thrown'
        // Not necessary - Swift async stream handles throwing errors

        /// 'event order is correct for multiple publishes'
        func testOrderCorrectForMultiplePublishes() async throws {
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
            guard let stream = subscription as? ConcurrentEventStream else {
                XCTFail("stream isn't ConcurrentEventStream")
                return
            }
            var iterator = stream.stream.makeAsyncIterator()

            db.trigger(email: Email(
                from: "yuzhi@graphql.org",
                subject: "Alright",
                message: "Tests are good",
                unread: true
            ))
            db.trigger(email: Email(
                from: "yuzhi@graphql.org",
                subject: "Message 2",
                message: "Tests are good 2",
                unread: true
            ))

            let result1 = try await iterator.next()?.get()
            XCTAssertEqual(
                result1,
                GraphQLResult(
                    data: ["importantEmail": [
                        "email": [
                            "from": "yuzhi@graphql.org",
                            "subject": "Alright",
                        ],
                        "inbox": [
                            "unread": 2,
                            "total": 3,
                        ],
                    ]]
                )
            )

            let result2 = try await iterator.next()?.get()
            XCTAssertEqual(
                result2,
                GraphQLResult(
                    data: ["importantEmail": [
                        "email": [
                            "from": "yuzhi@graphql.org",
                            "subject": "Message 2",
                        ],
                        "inbox": [
                            "unread": 2,
                            "total": 3,
                        ],
                    ]]
                )
            )
        }

        /// 'should handle error during execution of source event'
        func testErrorDuringSubscription() async throws {
            let db = EmailDb()

            let schema = try emailSchemaWithResolvers(
                resolve: { emailAny, _, _, eventLoopGroup, _ throws -> EventLoopFuture<Any?> in
                    guard let email = emailAny as? Email else {
                        throw GraphQLError(
                            message: "Source is not Email type: \(type(of: emailAny))"
                        )
                    }
                    if email.subject == "Goodbye" { // Force the system to fail here.
                        throw GraphQLError(message: "Never leave.")
                    }
                    return eventLoopGroup.next().makeSucceededFuture(EmailEvent(
                        email: email,
                        inbox: Inbox(emails: db.emails)
                    ))
                },
                subscribe: { _, _, _, eventLoopGroup, _ throws -> EventLoopFuture<Any?> in
                    eventLoopGroup.next().makeSucceededFuture(db.publisher.subscribe())
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
            guard let stream = subscription as? ConcurrentEventStream else {
                XCTFail("stream isn't ConcurrentEventStream")
                return
            }

            var results = [GraphQLResult]()
            var expectation = XCTestExpectation()
            // So that the Task won't immediately be cancelled since the ConcurrentEventStream is
            // discarded
            let keepForNow = stream.map { event in
                event.map { result in
                    results.append(result)
                    expectation.fulfill()
                }
            }
            var expected = [GraphQLResult]()

            db.trigger(email: Email(
                from: "yuzhi@graphql.org",
                subject: "Hello",
                message: "Tests are good",
                unread: true
            ))
            expected.append(
                GraphQLResult(
                    data: ["importantEmail": [
                        "email": [
                            "subject": "Hello",
                        ],
                    ]]
                )
            )
            wait(for: [expectation], timeout: timeoutDuration)
            XCTAssertEqual(results, expected)

            expectation = XCTestExpectation()
            // An error in execution is presented as such.
            db.trigger(email: Email(
                from: "yuzhi@graphql.org",
                subject: "Goodbye",
                message: "Tests are good",
                unread: true
            ))
            expected.append(
                GraphQLResult(
                    data: ["importantEmail": nil],
                    errors: [
                        GraphQLError(message: "Never leave."),
                    ]
                )
            )
            wait(for: [expectation], timeout: timeoutDuration)
            XCTAssertEqual(results, expected)

            expectation = XCTestExpectation()
            // However that does not close the response event stream. Subsequent events are still
            // executed.
            db.trigger(email: Email(
                from: "yuzhi@graphql.org",
                subject: "Bonjour",
                message: "Tests are good",
                unread: true
            ))
            expected.append(
                GraphQLResult(
                    data: ["importantEmail": [
                        "email": [
                            "subject": "Bonjour",
                        ],
                    ]]
                )
            )
            wait(for: [expectation], timeout: timeoutDuration)
            XCTAssertEqual(results, expected)

            // So that the Task won't immediately be cancelled since the ConcurrentEventStream is
            // discarded
            _ = keepForNow
        }

        /// 'should pass through error thrown in source event stream'
        // Handled by AsyncThrowingStream

        /// Test incorrect emitted type errors
        func testErrorWrongEmitType() async throws {
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
            guard let stream = subscription as? ConcurrentEventStream else {
                XCTFail("stream isn't ConcurrentEventStream")
                return
            }
            var iterator = stream.stream.makeAsyncIterator()

            db.publisher.emit(event: "String instead of email")

            let result = try await iterator.next()?.get()
            XCTAssertEqual(
                result,
                GraphQLResult(
                    data: ["importantEmail": nil],
                    errors: [
                        GraphQLError(message: "String is not Email"),
                    ]
                )
            )
        }
    }
#endif
