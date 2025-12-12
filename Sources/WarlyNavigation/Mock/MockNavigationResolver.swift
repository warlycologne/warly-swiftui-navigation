import Combine
import SwiftUI

public final class MockNavigationResolver: NavigationResolver {
    public var requirementsToFail: [RequirementIdentifier] = []
    public private(set) var requestedViews: [any ViewDestination] = []

    public init() {
        // Does nothing
    }

    public func registerDeeplinkProvider(_ provider: any DeeplinkProvider) {
        // Does nothing
    }

    public func destinationForDeeplink(url: URL) -> (any Destination)? {
        nil
    }

    public func registerRequirement(_ requirement: any Requirement) {
        // Does nothing
    }

    public func nextUnresolvedRequirement(of identifiers: [RequirementIdentifier]) async throws(NavigationResolverError) -> (any Requirement)? {
        nil
    }

    public func resolveRequirements(_ identifiers: [RequirementIdentifier], navigator: any Navigator) async throws(NavigationResolverError) {
        let failingRequirements = identifiers.filter { requirementsToFail.contains($0) }
        if let firstFailingRequirement = failingRequirements.first {
            throw .requirementFailed(firstFailingRequirement)
        }
    }

    public func updatePublisher(for requirement: RequirementIdentifier) throws(NavigationResolverError) -> RequirementUpdatePublisher {
        Empty().eraseToAnyPublisher()
    }

    public func registerViewFactory<T: ViewFactory>(_ viewFactory: T) {
        // Does nothing
    }

    public func registerMapper<T: Destination>(for destination: T.Type, mapper: @escaping (T) -> Destination?) {
        // Does nothing
    }

    public func resolveDestination<D: Destination>(_ destination: D) -> ResolveDestinationResult? {
        guard let viewDestination = destination as? ViewDestination else { return nil }
        return (viewDestination, nil)
    }

    public func view<D: ViewDestination>(for destination: D, navigator: any Navigator, context: inout ViewContext) -> any View {
        requestedViews.append(destination)
        return EmptyView()
    }

    public func decorateNavigationStack<T: View, D: ViewDestination>(
        _ navigationStack: T,
        for destination: D,
        isPresenting: Bool,
        navigator: any Navigator,
        context: ViewContext
    ) -> any View {
        navigationStack
    }
}

extension MockNavigationResolver {
    public func sendAction<T: DestinationAction>(_ action: T, to target: DestinationReference) {
        // Does nothing
    }

    public func subscribe<T: DestinationAction>(
        target: DestinationReference,
        to action: T.Type,
        condition: AnyPublisher<Bool, Never>,
        handler: @escaping (T) -> Void
    ) -> UUID {
        UUID()
    }

    public func unsubscribe(_ subscriptionID: UUID) {
        // Does nothing
    }
}
