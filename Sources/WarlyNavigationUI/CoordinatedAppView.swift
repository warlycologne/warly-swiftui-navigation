import SwiftUI
import WarlyNavigation

/// A view that provides all necessary setup for a coordinated app
/// Use `CoordinatedTabView` or `CoordinatedNavigationStack` with content to utilize the coordination system
public struct CoordinatedAppView<C: View>: View {
    let content: C

    @State private var manager: CoordinatedAppManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Namespace private var transitionNamespace

    /// Create a new coordinated app view
    /// - Parameter coordinatorStack: An instance of `CoordinatorStack` to hold all active coordinators
    /// - Parameter resolver: The navigation resolver to tregister the `URLDestination` and `AlertDestination` with
    /// - Parameter urlHandler: The handler to be called when a url comes from inside or outside the app
    /// - Parameter content: The view to display as the app content
    public init(
        coordinatorStack: CoordinatorStack,
        resolver: any NavigationResolver,
        urlHandler: any URLHandler = DefaultURLHandler(),
        @ViewBuilder content: () -> C
    ) {
        self.content = content()
        _manager = .init(initialValue: CoordinatedAppManager(
            coordinatorStack: coordinatorStack,
            resolver: resolver,
            urlHandler: urlHandler
        ))
    }

    public var body: some View {
        content
            .environment(\.coordinatorStack, manager.coordinatorStack)
            .environment(\.transitionNamespace, transitionNamespace)
            .environment(\.actionCenter, manager.actionCenter)
            .environment(\.appHorizontalSizeClass, horizontalSizeClass)
            // handle urls tapped inside the app
            .environment(\.openURL, manager.outgoingURLHandler)
            // handle urls coming into the app
            .onOpenURL(perform: manager.handleIncomingURL)
            .onAppear(perform: manager.setUp)
    }
}

/// The manager of the coordinated app view. Ensures the view is not retained past its lifetime
/// It handles incoming and outgoing urls as well as registers `URLDestination` and `AlertDestination`
@MainActor
private final class CoordinatedAppManager {
    var outgoingURLHandler: OpenURLAction {
        .init { [weak self] url in
            guard let self else { return .systemAction }
            return urlHandler.handleOutgoingURL(url, navigator: coordinatorStack.last) ? .handled : .systemAction
        }
    }

    var actionCenter: any DestinationActionCenter {
        resolver
    }
    let coordinatorStack: CoordinatorStack
    private let resolver: any NavigationResolver
    private let urlHandler: any URLHandler
    private var didSetUp = false

    init(coordinatorStack: CoordinatorStack, resolver: any NavigationResolver, urlHandler: any URLHandler) {
        self.coordinatorStack = coordinatorStack
        self.resolver = resolver
        self.urlHandler = urlHandler
    }

    func setUp() {
        guard !didSetUp else { return }
        didSetUp = true

        resolver.registerMapper(for: URLDestination.self) { [weak self] destination in
            guard let self else { return nil }
            urlHandler.handleOutgoingURL(destination.url, navigator: coordinatorStack.last)
            return nil
        }
        resolver.registerMapper(for: AlertDestination.self) { [weak self] destination in
            self?.coordinatorStack.last?.showAlert(destination.alertViewModel)
            return nil
        }
    }

    func handleIncomingURL(_ url: URL) {
        urlHandler.handleIncomingURL(url, navigator: coordinatorStack.last)
    }
}
