extension Dictionary where Key == ObjectIdentifier {
    func key<T>(for type: T.Type) -> ObjectIdentifier {
        ObjectIdentifier(type)
    }

    mutating func insert<T>(_ type: T.Type, value: Value) {
        let key = key(for: type)
        // There should always be only one resolver per destination
        if self[key] != nil {
            assertionFailure("Inserting value for already registered type \(key)")
        }

        self[key] = value
    }
}
