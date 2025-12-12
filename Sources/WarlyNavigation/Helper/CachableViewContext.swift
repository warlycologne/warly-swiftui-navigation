public protocol CachableViewContext {
    var cache: [ObjectIdentifier: AnyObject] { get set }
}

extension CachableViewContext {
    /// Use this method to cache any `@Observable`/`ObservableObjects` that should be created once per view
    /// - Parameter builder: The object to cache
    /// - Returns the created object. Either from cache or fresh
    public mutating func cache<T: AnyObject>(_ builder: @autoclosure () -> T) -> T {
        cache(builder)
    }

    /// Use this method to cache any `@Observable`/`ObservableObjects` that should be created once per view
    /// - Parameter builder: The object to cache
    /// - Returns the created object. Either from cache or fresh
    public mutating func cache<T: AnyObject>(_ builder: () -> T) -> T {
        let key = ObjectIdentifier(T.self)
        if let cachedObject = cache[key] as? T {
            return cachedObject
        }

        let object = builder()
        cache[key] = object
        return object
    }

    /// Use this method to extract any cached object
    /// - Parameter type: The type to extract from the context.
    /// - Returns the cached object. **Attention**: This methods throws a `fatalError` when the object is not stored in the context
    /// Make sure the extracted object has been cached via `cache(_:)` before!
    public func extract<T: AnyObject>(_ type: T.Type) -> T {
        let key = ObjectIdentifier(T.self)
        if let cachedObject = cache[key] as? T {
            return cachedObject
        } else {
            fatalError("Context does not contain userInfo of type \(T.self)")
        }
    }
}
