extension AnyExtensions {
    
    mutating func mutableStorage() -> UnsafeMutableRawPointer {
        return GraphQL.mutableStorage(instance: &self)
    }
    
    mutating func storage() -> UnsafeRawPointer {
        return GraphQL.storage(instance: &self)
    }
    
}

func mutableStorage<T>(instance: inout T) -> UnsafeMutableRawPointer {
    return mutableStorage(instance: &instance, type: type(of: instance))
}

func mutableStorage<T>(instance: inout T, type: Any.Type) -> UnsafeMutableRawPointer {
    return UnsafeMutableRawPointer(mutating: storage(instance: &instance, type: type))
}   

func storage<T>(instance: inout T) -> UnsafeRawPointer {
    return storage(instance: &instance, type: type(of: instance))
}

func storage<T>(instance: inout T, type: Any.Type) -> UnsafeRawPointer {
    return withUnsafePointer(to: &instance) { pointer in
        if type is AnyClass {
            return UnsafeRawPointer(bitPattern: UnsafePointer<Int>(pointer).pointee)!
        } else {
            return UnsafeRawPointer(pointer)
        }
    }
}
