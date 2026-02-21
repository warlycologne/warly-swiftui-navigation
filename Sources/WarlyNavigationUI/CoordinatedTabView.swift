import Combine
import SwiftUI
import WarlyNavigation

public struct CoordinatedTabView<C: View, T: TabItem>: View {
    @Environment(\.coordinatorStack) private var coordinatorStack
    @State private var manager: CoordinatedTabManager<T>
    private let tabs: [T]
    private var builder: ([T], _ selectedTab: Binding<TabID>) -> C

    public var body: some View {
        builder(tabs, $manager.selectedTab)
            .onAppear {
                manager.setUp(coordinatorStack: coordinatorStack)
            }
    }
}

extension CoordinatedTabView {
    /// Create a new coordinated tab view
    /// - Parameter tabs: The tabs to display in the tab bar
    /// - Parameter resolver: The navigation resolver to tregister the `TabDestination` with
    /// - Parameter content: The ``Tab`` content.
    init<TC: View>(
        tabs: [T],
        resolver: any NavigationResolver,
        @ViewBuilder content: @escaping (T, _ isSelected: Bool) -> TC
    ) where C == TabView<TabID, ForEach<[T], T.ID, TC>> {
        self.tabs = tabs
        _manager = .init(initialValue: CoordinatedTabManager(resolver: resolver, tabs: tabs))
        builder = { tabs, selectedTab in
            TabView(selection: selectedTab) {
                ForEach(tabs) { tab in
                    content(tab, selectedTab.wrappedValue == tab.id)
                }
            }
        }
    }
}

@available(iOS 18.0, *)
extension CoordinatedTabView {
    /// Create a new coordinated tab view
    /// - Parameter tabs: The tabs to display in the tab bar
    /// - Parameter resolver: The navigation resolver to tregister the `TabDestination` with
    /// - Parameter content: The ``Tab`` content.
    public init<TC: TabContent<TabID>>(
        tabs: [T],
        resolver: any NavigationResolver,
        @TabContentBuilder<TabID> content: @escaping ([T], _ isSelected: (T) -> Bool) -> TC
    ) where C == TabContentView<T, TC> {
        self.tabs = tabs
        _manager = .init(initialValue: CoordinatedTabManager(resolver: resolver, tabs: tabs))
        builder = { tabs, selectedTab in
            TabContentView(selectedTab: selectedTab, tabs: tabs, isSelected: { selectedTab.wrappedValue == $0.id }, content: content)
        }
    }
}

@available(iOS 18.0, *)
public struct TabContentView<T: TabItem, TC: TabContent<TabID>>: View {
    @Binding var selectedTab: TabID
    let tabs: [T]
    let isSelected: (T) -> Bool
    let content: ([T], _ isSelected: (T) -> Bool) -> TC

    fileprivate init(
        selectedTab: Binding<TabID>,
        tabs: [T],
        isSelected: @escaping (T) -> Bool,
        content: @escaping ([T], _ isSelected: (T) -> Bool) -> TC
    ) {
        _selectedTab = selectedTab
        self.tabs = tabs
        self.isSelected = isSelected
        self.content = content
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            content(tabs, isSelected)
        }
    }
}

/// The manager of the coordinated tab view. Ensures the view is not retained past its lifetime
/// It registers the `TabDestination` for manual tab switching
@Observable @MainActor
private final class CoordinatedTabManager<T: TabItem> {
    let tabs: [T]
    var selectedTab: TabID {
        didSet {
            tabDidAppear()
        }
    }

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

    private func tabDidAppear() {
        appearingContinuation?.resume()
        appearingContinuation = nil
    }
}

extension TabID {
    fileprivate static let none = Self(name: "none")
}
