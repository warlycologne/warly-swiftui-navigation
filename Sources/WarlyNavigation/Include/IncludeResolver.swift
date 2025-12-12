import SwiftUI

public protocol IncludeResolver {
    func registerMapper<D: IncludeDestination>(for destination: D.Type, mapper: @escaping (D) -> IncludeDestination?)
    func registerViewFactory<T: IncludeViewFactory>(_ viewFactory: T)

    @MainActor
    func view<D: IncludeViewDestination>(for destination: D, navigator: any Navigator, context: inout IncludeContext) -> (any View)?
    func resolve<D: IncludeDestination>(_ destination: D) -> (any IncludeViewDestination)?
}

public final class DefaultIncludeViewResolver: IncludeResolver {
    private var mappers: [ObjectIdentifier: any IncludeDestinationMapper] = [:]
    private var factories: [ObjectIdentifier: any IncludeViewFactory] = [:]

    public init() {
        // Does nothing
    }

    public func registerMapper<D: IncludeDestination>(for destination: D.Type, mapper: @escaping (D) -> IncludeDestination?) {
        mappers.insert(D.self, value: DefaultIncludeDestinationMapper(map: mapper))
    }

    public func registerViewFactory<T: IncludeViewFactory>(_ viewFactory: T) {
        factories.insert(T.IncludeDestination.self, value: viewFactory)
    }

    public func view<D: IncludeViewDestination>(for destination: D, navigator: any Navigator, context: inout IncludeContext) -> (any View)? {
        factories[D.self]?.view(for: destination, navigator: navigator, context: &context)
    }

    public func resolve<D: IncludeDestination>(_ destination: D) -> (any IncludeViewDestination)? {
        if let viewDestination = destination as? any IncludeViewDestination {
            return viewDestination
        }

        guard let destination = mappers[D.self]?.map(destination) else {
            return nil
        }

        return resolve(destination)
    }
}

// MARK: Resolver Dictionary
extension Dictionary where Key == ObjectIdentifier, Value == any IncludeViewFactory {
    fileprivate subscript<D: IncludeViewDestination>(destination: D.Type) -> (any IncludeViewFactory<D>)? {
        self[key(for: D.self)] as? any IncludeViewFactory<D>
    }
}

extension Dictionary where Key == ObjectIdentifier, Value == any IncludeDestinationMapper {
    fileprivate subscript<D: IncludeDestination>(source: D.Type) -> (any IncludeDestinationMapper<D>)? {
        self[key(for: D.self)] as? any IncludeDestinationMapper<D>
    }
}

/// An include destination mapper
private protocol IncludeDestinationMapper<Source> {
    associatedtype Source
    var map: (Source) -> (any IncludeDestination)? { get }
}

private struct DefaultIncludeDestinationMapper<S>: IncludeDestinationMapper {
    let map: (S) -> (any IncludeDestination)?
}
