
#if swift(>=4)
func relativePointer<T, U, V>(base: UnsafePointer<T>, offset: U) -> UnsafePointer<V> where U : BinaryInteger {
    let p = UnsafeRawPointer(base).assumingMemoryBound(to: Int8.self)
    return UnsafeRawPointer(p.advanced(by: Int(integer: offset))).assumingMemoryBound(to: V.self)
}

extension Int {
    fileprivate init<T : BinaryInteger>(integer: T) {
        switch integer {
        case let value as Int: self = value
        case let value as Int32: self = Int(value)
        case let value as Int16: self = Int(value)
        case let value as Int8: self = Int(value)
        default: self = 0
        }
    }
}

#else

func relativePointer<T, U, V>(base: UnsafePointer<T>, offset: U) -> UnsafePointer<V> where U : Integer {
    let p = UnsafeRawPointer(base).assumingMemoryBound(to: Int8.self)
    return UnsafeRawPointer(p.advanced(by: Int(integer: offset))).assumingMemoryBound(to: V.self)
}

extension Int {
    fileprivate init<T : Integer>(integer: T) {
        switch integer {
        case let value as Int: self = value
        case let value as Int32: self = Int(value)
        case let value as Int16: self = Int(value)
        case let value as Int8: self = Int(value)
        default: self = 0
        }
    }
}

#endif
