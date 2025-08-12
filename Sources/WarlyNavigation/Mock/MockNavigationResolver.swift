import Combine
import SwiftUI

public final class MockNavigationResolver: NavigationResolver {
    public init() {
        // Does nothing
    }

    public func registerDeeplinkProvider(_ provider: any DeeplinkProvider) {
        // Does nothing
    }

    public func destinationForDeeplink(url: URL) -> Destination? {
        nil
    }

    public func registerRequirement(_ requirement: any Requirement) {
        // Does nothing
    }

    public func nextUnresolvedRequirement(for destination: any ViewDestination) async throws(NavigationResolverError) -> (any Requirement)? {
        nil
    }

    public func resolveRequirements(for destination: any ViewDestination,navigator: any Navigator) async throws(NavigationResolverError) {
        // Does nothing
    }

    public func updatePublisher(for requirement: RequirementIdentifier) throws(NavigationResolverError) -> RequirementUpdatePublisher {
        Empty().eraseToAnyPublisher()
    }

    public func makeTabCoordinator(destination: any ViewDestination, reference: DestinationReference?) -> any Coordinator {
        makeCoordinator(root: .init(destination: destination, references: [.tabRoot, reference]), parent: nil)
    }

    public func makeCoordinator(root: NavigationItem, parent: (any Coordinator)?) -> any Coordinator {
        MockCoordinator(root: root, parent: parent, resolver: self)
    }

    public func registerViewFactory<T: ViewFactory>(_ viewFactory: T) {
        // Does nothing
    }

    public func registerMapper<T: Destination>(for destination: T.Type, mapper: @escaping (T) -> Destination?) {
        // Does nothing
    }

    public func resolveDestination<D: Destination>(_ destination: D) -> (any ViewDestination)? {
        nil
    }

    public func view<D: ViewDestination>(for destination: D, navigator: any Navigator, context: inout ViewContext) -> any View {
        EmptyView()
    }

    public func decorateNavigationStack<T: View, D: ViewDestination>(
        _ navigationStack: T,
        for destination: D,
        navigator: any Navigator,
        context: ViewContext
    ) -> any View {
        navigationStack
    }

    public func decorateStateView(_ stateView: StateView, navigator: any Navigator, context: ViewContext) -> any View {
        switch stateView {
        case .navigationStack(let view, _): view
        case .navigationStackContent(let view, _): view
        case .bottomSheet(let view, _): view
        }
    }
}
