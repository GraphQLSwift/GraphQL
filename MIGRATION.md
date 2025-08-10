# Migration

## 3 to 4

### NIO removal

All NIO-based arguments and return types were removed, including all `EventLoopGroup` and `EventLoopFuture` parameters.

As such, all `execute` and `subscribe` calls should have the `eventLoopGroup` argument removed, and the `await` keyword should be used.

Also, all resolver closures must remove the `eventLoopGroup` argument, and all that return an `EventLoopFuture` should be converted to an `async` function.

The documentation here will be very helpful in the conversion: https://www.swift.org/documentation/server/guides/libraries/concurrency-adoption-guidelines.html

### Swift Concurrency checking

With the conversion from NIO to Swift Concurrency, types used across async boundaries should conform to `Sendable` to avoid errors and warnings. This includes the Swift types and functions that back the GraphQL schema. For more details on the conversion, see the [Sendable documentation](https://developer.apple.com/documentation/swift/sendable).

### `ExecutionStrategy` argument removals

The `queryStrategy`, `mutationStrategy`, and `subscriptionStrategy` arguments have been removed from `graphql` and `graphqlSubscribe`. Instead Queries and Subscriptions are executed in parallel and Mutations are executed serially, [as required by the spec](https://spec.graphql.org/October2021/#sec-Mutation).


### EventStream removal

The `EventStream` abstraction used to provide pre-concurrency subscription support has been removed. This means that `graphqlSubscribe(...).stream` will now be an `AsyncThrowingStream<GraphQLResult, Error>` type, instead of an `EventStream` type, and that downcasting to `ConcurrentEventStream` is no longer necessary.

### SubscriptionResult removal

The `SubscriptionResult` type was removed, and `graphqlSubscribe` now returns `Result<AsyncThrowingStream<GraphQLResult, Error>, GraphQLErrors>`.

### Instrumentation removal

The `Instrumentation` type has been removed, with anticipated support for tracing using [`swift-distributed-tracing`](https://github.com/apple/swift-distributed-tracing). `instrumentation` arguments must be removed from `graphql` and `graphqlSubscribe` calls.

### AST Node `set`

The deprecated `Node.set(value: Node?, key: String)` function was removed in preference of the `Node.set(value _: NodeResult?, key _: String)`. Change any calls from `node.set(value: node, key: string)` to `node.set(.node(node), string)`.

## 2 to 3

### TypeReference removal

The `GraphQLTypeReference` type was removed in v3.0.0, since it was made unnecessary by introducing closure-based `field` API that allows the package to better control the order of type resolution.

To remove `GraphQLTypeReference`, you can typically just replace it with a reference to the `GraphQLObjectType` instance:

```swift
// Before
let object1 = try GraphQLObjectType(
  name: "Object1"
)
let object2 = try GraphQLObjectType(
  name: "Object2"
  fields: ["object1": GraphQLField(type: GraphQLTypeReference("Object1"))]
)

// After
let object1 = try GraphQLObjectType(
  name: "Object1"
)
let object2 = try GraphQLObjectType(
  name: "Object2"
  fields: ["object1": GraphQLField(type: object1)]
)
```

For more complex cyclic or recursive types, simply create the types first and assign the `fields` property afterward. Here's an example:

```swift
// Before
let object1 = try GraphQLObjectType(
  name: "Object1"
  fields: ["object2": GraphQLField(type: GraphQLTypeReference("Object2"))]
)
let object2 = try GraphQLObjectType(
  name: "Object2"
  fields: ["object1": GraphQLField(type: GraphQLTypeReference("Object1"))]
)

// After
let object1 = try GraphQLObjectType(name: "Object1")
let object2 = try GraphQLObjectType(name: "Object2")
object1.fields = { [weak object2] in
    guard let object2 = object2 else { return [:] }
    return ["object2": GraphQLField(type: object2)]
}
object2.fields = { [weak object1] in
    guard let object1 = object1 else { return [:] }
    return ["object1": GraphQLField(type: object1)]
}
```

Note that this also gives you the chance to explicitly handle the memory cycle that cyclic types cause as well.

### Type Definition Arrays

The following type properties were changed from arrays to closures. To get the array version, in most cases you can just call the `get`-style function (i.e. for `GraphQLObject.fields`, use `GraphQLObject.getFields()`):

- `GraphQLObjectType.fields`
- `GraphQLObjectType.interfaces`
- `GraphQLInterfaceType.fields`
- `GraphQLInterfaceType.interfaces`
- `GraphQLUnionType.types`
- `GraphQLInputObjectType.fields`

### Directive description is optional

`GraphQLDirective` has changed from a struct to a class, and its `description` property is now optional.

### GraphQL type codability

With GraphQL type definitions now including closures, many of the objects in [Definition](https://github.com/GraphQLSwift/GraphQL/blob/main/Sources/GraphQL/Type/Definition.swift) are no longer codable. If you are depending on codability, you can conform the type appropriately in your downstream package.
