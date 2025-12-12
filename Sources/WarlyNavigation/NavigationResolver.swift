import Combine
import SwiftUI

public enum NavigationResolverError: Error {
    case requirementMissing(RequirementIdentifier)
    case requirementFailed(RequirementIdentifier)
}

/// A result from resolving a destination
public typealias ResolveDestinationResult = (destination: any ViewDestination, action: DestinationAction?)

public protocol NavigationResolver: AnyObject, DeeplinkResolver, DestinationActionCenter {
    // Deeplinks
    func registerDeeplinkProvider(_ provider: any DeeplinkProvider)

    // Requirements
    func registerRequirement(_ requirement: any Requirement)
    func nextUnresolvedRequirement(of identifiers: [RequirementIdentifier]) async throws(NavigationResolverError) -> (any Requirement)?
    func resolveRequirements(_ identifiers: [RequirementIdentifier], navigator: any Navigator) async throws(NavigationResolverError)
    func updatePublisher(for identifier: RequirementIdentifier) throws(NavigationResolverError) -> RequirementUpdatePublisher

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
    func resolveDestination<D: Destination>(_ destination: D) -> ResolveDestinationResult?

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
        isPresenting: Bool,
        navigator: any Navigator,
        context: ViewContext
    ) -> any View
}

public class DefaultNavigationResolver: NavigationResolver {
    private let stateDestinationViewFactory: any StateDestinationViewFactory
    private let deeplinkConfiguration: DeeplinkConfiguration

    private var deeplinkProviders: [any DeeplinkProvider] = []
    private var requirements: [RequirementIdentifier: any Requirement] = [:]
    private var destinationMappers: [ObjectIdentifier: any DestinationMapper] = [:]
    private var viewFactories: [ObjectIdentifier: any ViewFactory] = [:]
    private var actionSubject: PassthroughSubject<TargetedDestinationAction, Never> = .init()
    private var actionCancellables: [UUID: AnyCancellable] = [:]

    /// Creates a new navigation resolver
    /// - Parameter stateDestinationViewFactory: The view factory used to create navigation related views
    /// - Parameter deeplinkConfiguration: The configuration used when matching deeplinks
    public init(
        stateDestinationViewFactory: any StateDestinationViewFactory,
        deeplinkConfiguration: DeeplinkConfiguration = .init()
    ) {
        self.stateDestinationViewFactory = stateDestinationViewFactory
        self.deeplinkConfiguration = deeplinkConfiguration

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

    public func nextUnresolvedRequirement(of identifiers: [RequirementIdentifier]) async throws(NavigationResolverError) -> (any Requirement)? {
        for identifier in identifiers {
            guard let requirement = requirements[identifier] else {
                assertionFailure("Requirement '\(identifier)' has not been registered")
                throw .requirementMissing(identifier)
            }
            guard await !requirement.isResolved() else { continue }
            return requirement
        }

        return nil
    }

    public func resolveRequirements(_ identifiers: [RequirementIdentifier], navigator: any Navigator) async throws(NavigationResolverError) {
        while let requirement = try await nextUnresolvedRequirement(of: identifiers) {
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

    // MARK: - Destinations
    public func registerViewFactory<T: ViewFactory>(_ viewFactory: T) {
        viewFactories.insert(T.Destination.self, value: viewFactory)
    }

    public func registerMapper<D: Destination>(
        for destination: D.Type,
        mapper: @escaping (D) -> Destination?
    ) {
        destinationMappers.insert(D.self, value: DefaultDestinationMapper(map: mapper))
    }

    public func resolveDestination<D: Destination>(_ destination: D) -> ResolveDestinationResult? {
        // The destination is already a `ViewDestination`, just return it
        if let viewDestination = destination as? any ViewDestination {
            return (viewDestination, nil)
        }

        if let actionableDestination = destination as? ActionableDestination,
            let viewDestination = resolveDestination(actionableDestination.destination)?.destination {
            return (viewDestination, actionableDestination.action)
        }

        guard let mapper = destinationMappers[D.self] else {
            assertionFailure("Unhandled destination \(String(reflecting: destination))")
            return (StateDestination.notResolvable(destination), nil)
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
        let view = viewFactories[D.self]?.view(for: destination, navigator: navigator, context: &context)
            ?? stateDestinationViewFactory.view(for: .missingViewFactory(destination), navigator: navigator, context: &context)

        let stateView: StateView
        if case .bottomSheet = context.presentation {
            stateView = .bottomSheet(AnyView(view), showCloseButton: context.showCloseButton)
        } else {
            stateView = .navigationStackContent(AnyView(view), context.isRoot ? .root(showCloseButton: context.showCloseButton) : .path)
        }

        return stateDestinationViewFactory.decorate(stateView, navigator: navigator, context: context)
    }

    public func decorateNavigationStack<T: View, D: ViewDestination>(
        _ navigationStack: T,
        for destination: D,
        isPresenting: Bool,
        navigator: any Navigator,
        context: ViewContext
    ) -> any View {
        let decoratedNavigationStack = viewFactories[D.self]?.decorateNavigationStack(
            AnyView(navigationStack),
            for: destination,
            navigator: navigator,
            context: context
        ) ?? navigationStack

        return stateDestinationViewFactory.decorate(
            .navigationStack(AnyView(decoratedNavigationStack), isPresenting: isPresenting),
            navigator: navigator,
            context: context
        )
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

// MARK: Actions
extension DefaultNavigationResolver {
    public func sendAction<T: DestinationAction>(_ action: T, to target: DestinationReference) {
        actionSubject.send(.init(target: target, action: action))
    }

    public func subscribe<T: DestinationAction>(
        target: DestinationReference,
        to action: T.Type,
        condition: AnyPublisher<Bool, Never>,
        handler: @escaping (T) -> Void
    ) -> UUID {
        let subscriptionID = UUID()
        actionCancellables[subscriptionID] = actionSubject
            .filter { target == $0.target }
            .compactMap { $0.action as? T }
            .flatMap { action in
                // Wait for the condition to be true before publishing the action
                condition
                    .first { $0 }
                    .map { _ in action }
            }
            .sink(receiveValue: handler)

        return subscriptionID
    }

    public func unsubscribe(_ subscriptionID: UUID) {
        actionCancellables.removeValue(forKey: subscriptionID)
    }
}
