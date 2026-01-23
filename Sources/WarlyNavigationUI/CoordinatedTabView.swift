import Combine
import SwiftUI
import WarlyNavigation

public struct CoordinatedTabView<C: View, T: TabItem>: View {
    @Environment(\.coordinatorStack) private var coordinatorStack
    @State private var manager: CoordinatedTabManager<T>

    private let content: (T, _ isSelected: Bool) -> C

    /// Create a new coordinated tab view
    /// - Parameter tabs: The tabs to display in the tab bar
    /// - Parameter resolver: The navigation resolver to tregister the `TabDestination` with
    public init(
        tabs: [T],
        resolver: any NavigationResolver,
        @ViewBuilder content: @escaping (T, _ isSelected: Bool) -> C
    ) {
        self.content = content
        _manager = .init(initialValue: CoordinatedTabManager(resolver: resolver, tabs: tabs))
    }

    public var body: some View {
        TabView(selection: $manager.selectedTab) {
            ForEach(manager.tabs) { tab in
                content(tab, manager.selectedTab == tab.id)
                    .onAppear(perform: manager.tabDidAppear)
            }
        }
        .onAppear {
            manager.setUp(coordinatorStack: coordinatorStack)
        }
    }
}

/// The manager of the coordinated tab view. Ensures the view is not retained past its lifetime
/// It registers the `TabDestination` for manual tab switching
@Observable @MainActor
private final class CoordinatedTabManager<T: TabItem> {
    let tabs: [T]
    var selectedTab: TabID

    private let resolver: any NavigationResolver
    @ObservationIgnored private var didSetUp = false
    @ObservationIgnored private var appearingContinuation: CheckedContinuation<Void, Never>?

    init(resolver: any NavigationResolver, tabs: [T]) {
        self.resolver = resolver
        self.tabs = tabs
        selectedTab = tabs.first?.id ?? .none
    }

    func setUp(coordinatorStack: CoordinatorStack) {
        guard !didSetUp else { return }
        didSetUp = true

        resolver.registerMapper(for: TabDestination.self) { [weak self] destination in
            HandledDestination { [weak self] in
                guard let self, let tab = tabs[destination.tabID] else { return nil }
                guard let coordinator = coordinatorStack.first,
                      await coordinator.dismiss() else {
                    return nil
                }

                if selectedTab != destination.tabID {
                    selectedTab = destination.tabID
                    await withCheckedContinuation { continuation in
                        appearingContinuation = continuation
                    }
                }

                if destination.popToRoot {
                    await tab.coordinator.navigateBack(to: tab.coordinator.root.id)
                }

                return tab.coordinator
            }
        }
    }

    func tabDidAppear() {
        appearingContinuation?.resume()
        appearingContinuation = nil
    }
}

extension TabID {
    fileprivate static let none = Self(name: "none")
}
