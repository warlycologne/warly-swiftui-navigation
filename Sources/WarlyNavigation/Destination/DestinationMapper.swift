/// A destination mapper
protocol DestinationMapper<Source> {
    associatedtype Source: Destination

    var map: (Source) -> Destination? { get }
}

struct DefaultDestinationMapper<D: Destination>: DestinationMapper {
    let map: (D) -> Destination?
}

extension Dictionary where Key == ObjectIdentifier, Value == any DestinationMapper {
    subscript<D: Destination>(destination: D.Type) -> (any DestinationMapper<D>)? {
        self[key(for: D.self)] as? any DestinationMapper<D>
    }
}
