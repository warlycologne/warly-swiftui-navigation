import SwiftUI
import WarlyNavigation

public struct CoordinatedNavigationStack: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.coordinatorStack) @Binding private var coordinatorStack
    @Environment(\.presentation) private var presentation
    @Environment(\.isModal) private var isModal
    @State private var coordinator: any Coordinator
    @State private var isPresenting = false
    @State private var didAppear = false

    /// Tells whether this view is part of the currently visible stack
    private var isActive: Bool {
        coordinatorStack.contains(coordinator)
    }

    /// Creates a new `CoordinatedNavigationStack` with given `coordinator`
    /// - Parameter coordinator: The `Coordinator` to handle navigation
    public init(coordinator: any Coordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        var context = makeContext(
            reference: coordinator.root.id,
            isRoot: true,
            showCloseButton: (presentation != nil && (!isModal || coordinator.root.isBlocked))
        )
        AnyView(coordinator.decorateNavigationStack(
            navigationStack(for: coordinator.root, context: &context),
            isPresenting: isPresenting,
            context: context
        ))
        .alert(viewModel: $coordinator.alertViewModel)
        .sheet(item: $coordinator.sheetItem, onDismiss: coordinator.sheetItem?.onDismiss) { sheetItem in
            presentedNavigationStack(for: sheetItem)
        }
        .fullScreenCover(item: $coordinator.fullScreenItem, onDismiss: coordinator.fullScreenItem?.onDismiss) { fullScreenItem in
            presentedNavigationStack(for: fullScreenItem)
                .background(.background)
        }
        .onAppear {
            coordinator.setUp()
            coordinatorStack.append(coordinator)
        }
        .onDisappear {
            coordinatorStack.remove(coordinator)
        }
        .onChange(of: horizontalSizeClass, initial: true) { coordinator.horizontalSizeClass = horizontalSizeClass }
    }

    @ViewBuilder
    private func navigationStack(for navigationItem: NavigationItem, context: inout ViewContext) -> some View {
        NavigationStack(path: $coordinator.navigationPath) {
            view(for: navigationItem, context: &context)
                .navigationDestination(for: NavigationItem.self) { navigationItem in
                    var context = makeContext(reference: navigationItem.id)
                    view(for: navigationItem, context: &context)
                }
        }
    }

    private func presentedNavigationStack(for presentationItem: PresentationItem) -> some View {
        CoordinatedNavigationStack(coordinator: presentationItem.coordinator)
            .interactiveDismissDisabled(presentationItem.isModal)
            .environment(\.presentation, presentationItem.presentation)
            .environment(\.isModal, presentationItem.isModal)
            .onVisibilityChange(update: $isPresenting)
    }

    private func view(for navigationItem: NavigationItem, context: inout ViewContext) -> some View {
        AnyView(coordinator.view(for: navigationItem, context: &context))
            .bottomSheet(isActive: presentation == .bottomSheet)
            .environment(\.isViewFocused, isActive ? coordinator.isFocused(navigationItem: navigationItem) : false)
    }

    private func makeContext(reference: DestinationReference, isRoot: Bool = false, showCloseButton: Bool = false) -> ViewContext {
        ViewContext(
            isRoot: isRoot,
            reference: reference,
            horizontalSizeClass: horizontalSizeClass,
            presentation: presentation,
            showCloseButton: showCloseButton
        )
    }
}

extension EnvironmentValues {
    /// An array of all active coordinators analogous to a navigation stack
    @Entry public var coordinatorStack: Binding<[any Coordinator]> = .constant([])
    /// Whether this view is focused (no presenting view on top, the user can interact with it)
    @Entry public var isViewFocused = false
    /// How this view is presented if applicable
    @Entry public var presentation: Presentation? = nil
    /// Whether the current navigation stack is presented modally
    @Entry public var isModal: Bool = false
}
