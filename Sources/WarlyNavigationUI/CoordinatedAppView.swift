import SwiftUI
import WarlyNavigation

/// A view that provides all necessary setup for a coordinated app
/// Use `CoordinatedTabView` or `CoordinatedNavigationStack` with content to utilize the coordination system
public struct CoordinatedAppView<C: View>: View {
    let content: C
    let resolver: any NavigationResolver
    let urlHandler: any URLHandler

    @State private var coordinatorStackHolder = CoordinatorStackHolder()
    @Namespace private var transitionNamespace
    private var coordinatorStack: Binding<[any Coordinator]> {
        coordinatorStackHolder.binding
    }

    public init(
        resolver: any NavigationResolver,
        urlHandler: any URLHandler = DefaultURLHandler(),
        @ViewBuilder content: () -> C
    ) {
        self.content = content()
        self.resolver = resolver
        self.urlHandler = urlHandler
    }

    public var body: some View {
        content
            .environment(\.coordinatorStack, coordinatorStack)
            .environment(\.transitionNamespace, transitionNamespace)
            .environment(\.actionCenter, resolver)
            // handle urls tapped inside the app
            .environment(\.openURL, OpenURLAction { [coordinatorStack, urlHandler] outgoingURL in
                urlHandler.handleOutgoingURL(outgoingURL, navigator: coordinatorStack.wrappedValue.last) ? .handled : .systemAction
            })
            // handle urls coming into the app
            .onOpenURL { [coordinatorStack, urlHandler] incomingURL in
                urlHandler.handleIncomingURL(incomingURL, navigator: coordinatorStack.wrappedValue.last)
            }
            .onAppear {
                resolver.registerMapper(for: URLDestination.self) { [coordinatorStack, urlHandler] destination in
                    urlHandler.handleOutgoingURL(destination.url, navigator: coordinatorStack.wrappedValue.last)
                    return nil
                }
                resolver.registerMapper(for: AlertDestination.self) { [coordinatorStack] destination in
                    coordinatorStack.wrappedValue.last?.showAlert(destination.alertViewModel)
                    return nil
                }
            }
    }
}

private final class CoordinatorStackHolder {
    @MainActor
    var binding: Binding<[any Coordinator]> {
        .init(
            get: { [weak self] in self?.coordinatorStack ?? [] },
            set: { [weak self] in self?.coordinatorStack = $0 }
        )
    }

    private var coordinatorStack: [any Coordinator] = []
}
