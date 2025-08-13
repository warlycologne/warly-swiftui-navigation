import Combine
import SwiftUI

public enum NavigationResolverError: Error {
    case requirementMissing(RequirementIdentifier)
    case requirementFailed(RequirementIdentifier)
}

public protocol NavigationResolver: AnyObject, DeeplinkResolver {
    // Deeplinks
    func registerDeeplinkProvider(_ provider: any DeeplinkProvider)

    // Requirements
    func registerRequirement(_ requirement: any Requirement)
    func nextUnresolvedRequirement(for destination: any ViewDestination) async throws(NavigationResolverError) -> (any Requirement)?
    func resolveRequirements(for destination: any ViewDestination, navigator: any Navigator) async throws(NavigationResolverError)
    func updatePublisher(for identifier: RequirementIdentifier) throws(NavigationResolverError) -> RequirementUpdatePublisher

    // Coordinators
    func makeTabCoordinator(destination: any ViewDestination, reference: DestinationReference?) -> any Coordinator
    func makeCoordinator(root: NavigationItem, parent: (any Coordinator)?) -> any Coordinator

    // Destinations
    /// Register a view factory that resolves a `ViewDestination` to a `View`
    /// - Parameter viewFactory: the view factory to register
    func registerViewFactory<T: ViewFactory>(_ viewFactory: T)
    /// Register a mapper for a destination type, e.g. `ExternalDestination`, `URLDestination` or `TabDestination`
    /// - Parameter destination: The type of destination the mapper should handle
    /// - Parameter mapper: The resolve to map the given destination to a different destination. The resolver may return nil, if there is no view destination to resolve to (e.g. the destination is handled otherwise)
    func registerMapper<T: Destination>(for destination: T.Type, mapper: @escaping (T) -> Destination?)
    /// Method to convert any destination to a ViewDestination
    /// - Parameter destination: The destination to find the `ViewDestination` for
    /// - Returns the `ViewDestination` to display. Return `nil` if the destination has been handled otherwise and does not result in a view. Returns an `UnknownDestination` if the destination could not be resolved
    func resolveDestination<D: Destination>(_ destination: D) -> (any ViewDestination)?

    @MainActor
    func view<D: ViewDestination>(
        for destination: D,
        navigator: any Navigator,
        context: inout ViewContext
    ) -> any View

    @MainActor
    func decorateNavigationStack<T: View, D: ViewDestination>(
        _ navigationStack: T,
        for destination: D,
        navigator: any Navigator,
        context: ViewContext
    ) -> any View

    @MainActor
    func decorateStateView(_ stateView: StateView, navigator: any Navigator, context: ViewContext) -> any View
}

extension NavigationResolver {
    public func makeTabCoordinator(destination: any ViewDestination) -> any Coordinator {
        makeTabCoordinator(destination: destination, reference: nil)
    }
}

public class DefaultNavigationResolver<C: Coordinator>: NavigationResolver {
    private let stateDestinationViewFactory: any StateDestinationViewFactory
    private let deeplinkConfiguration: DeeplinkConfiguration
    private let coordinatorType: C.Type

    private var deeplinkProviders: [any DeeplinkProvider] = []
    private var requirements: [RequirementIdentifier: any Requirement] = [:]
    private var destinationMappers: [String: any DestinationMapper] = [:]
    private var viewFactories: [String: any ViewFactory] = [:]

    /// Creates a new navigation resolver
    /// - Parameter stateDestinationViewFactory: The view factory used to create navigation related views
    /// - Parameter coordinatorType: The class used to instanatiate new coordinators
    public init(
        stateDestinationViewFactory: any StateDestinationViewFactory,
        deeplinkConfiguration: DeeplinkConfiguration = .init(),
        coordinatorType: C.Type = DefaultCoordinator.self
    ) {
        self.stateDestinationViewFactory = stateDestinationViewFactory
        self.deeplinkConfiguration = deeplinkConfiguration
        self.coordinatorType = coordinatorType

        registerViewFactory(stateDestinationViewFactory)
    }

    // MARK: - Deeplinks
    public func registerDeeplinkProvider(_ provider: any DeeplinkProvider) {
        deeplinkProviders.append(provider)
    }

    // MARK: - Requirements
    public func registerRequirement(
        _ requirement: any Requirement
    ) {
        requirements[requirement.identifier] = requirement
    }

    public func nextUnresolvedRequirement(for destination: any ViewDestination) async throws(NavigationResolverError) -> (any Requirement)? {
        for identifier in destination.requirements {
            guard let requirement = requirements[identifier] else {
                assertionFailure("Requirement '\(identifier)' has not been registered")
                throw .requirementMissing(identifier)
            }
            guard await !requirement.isResolved() else { continue }
            return requirement
        }

        return nil
    }

    public func resolveRequirements(for destination: any ViewDestination, navigator: any Navigator) async throws(NavigationResolverError) {
        while let requirement = try await nextUnresolvedRequirement(for: destination) {
            guard await requirement.resolve(navigator: navigator) else {
                throw .requirementFailed(requirement.identifier)
            }
        }
    }

    public func updatePublisher(for identifier: RequirementIdentifier) throws(NavigationResolverError) -> RequirementUpdatePublisher {
        guard let requirement = requirements[identifier] else {
            assertionFailure("Requirement '\(identifier)' has not been registered")
            throw .requirementMissing(identifier)
        }

        return requirement.updatePublisher
    }

    // MARK: - Coordinators
    public func makeTabCoordinator(destination: any ViewDestination, reference: DestinationReference?) -> any Coordinator {
        makeCoordinator(
            root: .init(destination: destination, references: [.tabRoot, reference]),
            parent: nil
        )
    }

    public func makeCoordinator(root: NavigationItem, parent: (any Coordinator)?) -> any Coordinator{
        coordinatorType.init(root: root, parent: parent, resolver: self)
    }

    // MARK: - Destinations
    public func registerViewFactory<T: ViewFactory>(_ viewFactory: T) {
        viewFactories.insert(T.D.self, value: viewFactory)
    }

    public func registerMapper<D: Destination>(
        for destination: D.Type,
        mapper: @escaping (D) -> Destination?
    ) {
        destinationMappers.insert(D.self, value: DefaultDestinationMapper(map: mapper))
    }

    public func resolveDestination<D: Destination>(_ destination: D) -> (any ViewDestination)? {
        // The destination is already a `ViewDestination`, just return it
        if let viewDestination = destination as? any ViewDestination {
            return viewDestination
        }

        guard let mapper = destinationMappers[D.self] else {
            assertionFailure("Unhandled destination type \(destinationMappers.key(for: D.self))")
            return UnknownDestination(originalDestination: destination)
        }

        guard let destination = mapper.map(destination) else {
            // The destination is handled, but does not have a view, simply return nil here
            return nil
        }

        return resolveDestination(destination)
    }

    public func view<D: ViewDestination>(
        for destination: D,
        navigator: any Navigator,
        context: inout ViewContext
    ) -> any View {
        viewFactories[D.self]?.view(for: destination, navigator: navigator, context: &context)
            ?? stateDestinationViewFactory.view(for: .notFound(destination), navigator: navigator, context: &context)
    }

    public func decorateNavigationStack<T: View, D: ViewDestination>(
        _ navigationStack: T,
        for destination: D,
        navigator: any Navigator,
        context: ViewContext
    ) -> any View {
        viewFactories[D.self]?.decorateNavigationStack(
            AnyView(navigationStack),
            for: destination,
            navigator: navigator,
            context: context
        ) ?? navigationStack
    }

    public func decorateStateView(_ stateView: StateView, navigator: any Navigator, context: ViewContext) -> any View {
        stateDestinationViewFactory.decorate(stateView, navigator: navigator, context: context)
    }
}

// MARK: Deeplinks
extension DefaultNavigationResolver: DeeplinkResolver {
    public func destinationForDeeplink(url: URL) -> Destination? {
        for deeplinkProvider in deeplinkProviders {
            if let destination = deeplinkProvider.destinationForDeeplink(url: url, configuration: deeplinkConfiguration) {
                return destination
            }
        }

        return nil
    }
}

// MARK: Resolver Dictionary
extension Dictionary where Key == String {
    fileprivate func key<T>(for type: T.Type) -> String {
        String(reflecting: T.self)
    }

    fileprivate mutating func insert<T>(_ type: T.Type, value: Value) {
        // There should always be only one resolver per destination
        if self[key(for: T.self)] != nil {
            assertionFailure("Inserting resolver for already registered destination \(String(reflecting: T.self))")
        }

        self[key(for: T.self)] = value
    }
}

extension Dictionary where Key == String, Value == any ViewFactory {
    fileprivate subscript<D: Destination>(destination: D.Type) -> (any ViewFactory<D>)? {
        self[key(for: D.self)] as? any ViewFactory<D>
    }
}

extension Dictionary where Key == String, Value == any DestinationMapper {
    fileprivate subscript<D: Destination>(destination: D.Type) -> (any DestinationMapper<D>)? {
        self[key(for: D.self)] as? any DestinationMapper<D>
    }
}

/// A destination mapper
private protocol DestinationMapper<D> {
    associatedtype D: Destination

    var map: (D) -> Destination? { get }
}

private struct DefaultDestinationMapper<D: Destination>: DestinationMapper {
    let map: (D) -> Destination?
}
