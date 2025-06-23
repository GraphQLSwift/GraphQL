# Migration

## 3 to 4

### NIO removal

All NIO-based arguments and return types were removed, including all `EventLoopGroup` and `EventLoopFuture` parameters.

As such, all `execute` and `subscribe` calls should have the `eventLoopGroup` argument removed, and the `await` keyword should be used.

Also, all resolver closures must remove the `eventLoopGroup` argument, and all that return an `EventLoopFuture` should be converted to an `async` function.

The documentation here will be very helpful in the conversion: https://www.swift.org/documentation/server/guides/libraries/concurrency-adoption-guidelines.html

### `ConcurrentDispatchFieldExecutionStrategy`

This was changed to `ConcurrentFieldExecutionStrategy`, and takes no parameters.

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
