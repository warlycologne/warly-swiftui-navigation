import Combine
import SwiftUI
import WarlyNavigation

public struct CoordinatedTabView: View {
    @Environment(\.coordinatorStack) private var coordinatorStack
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var badges: [TabID: String?] = [:]
    @State private var manager: CoordinatedTabManager

    private let selectedTabColor: Color?
    private let contentTint: Color?

    private var iconRenderingMode: Image.TemplateRenderingMode {
        if #available(iOS 26, *) {
            // starting with iOS 26 the unselected tab bar icon adopts the color of the text
            .template
        } else {
            // In prior versions the tab icon is gray when unselected, possibly not matching the style
            .original
        }
    }

    /// Create a new coordinated tab view
    /// - Parameter tabs: The tabs to display in the tab bar
    /// - Parameter selectedTabColor: The color the selected tab should be tinted in
    /// - Parameter contentTint: The accent color used for the content
    /// - Parameter resolver: The navigation resolver to tregister the `TabDestination` with
    public init(
        tabs: [TabItem],
        selectedTabColor: Color? = nil,
        contentTint: Color? = nil,
        resolver: any NavigationResolver
    ) {
        self.selectedTabColor = selectedTabColor
        self.contentTint = contentTint
        _manager = .init(initialValue: CoordinatedTabManager(resolver: resolver, tabs: tabs))
    }

    public var body: some View {
        TabView(selection: $manager.selectedTab) {
            ForEach(manager.tabs) { tab in
                CoordinatedNavigationStack(coordinator: tab.coordinator)
                    .tint(contentTint)
                    .id(tab.id)
                    .tabItem {
                        let isSelected = tab.id == manager.selectedTab
                        (isSelected ? tab.icon.selected : tab.icon.normal)
                            .renderingMode(iconRenderingMode)
                        Text(horizontalSizeClass == .compact || isSelected ? tab.title : "")
                    }
                    .badge(badges[tab.id] ?? "")
                    .onReceive(tab.badgePublisher) { badge in
                        badges[tab.id] = badge
                    }
                    .onAppear(perform: manager.tabDidAppear)
            }
        }
        .tint(selectedTabColor)
        .onAppear {
            manager.setUp(coordinatorStack: coordinatorStack)
        }
    }
}

/// The manager of the coordinated tab view. Ensures the view is not retained past its lifetime
/// It registers the `TabDestination` for manual tab switching
@Observable @MainActor
private final class CoordinatedTabManager {
    let tabs: [TabItem]
    var selectedTab: TabID

    private let resolver: any NavigationResolver
    @ObservationIgnored private var didSetUp = false
    @ObservationIgnored private var appearingContinuation: CheckedContinuation<Void, Never>?

    init(resolver: any NavigationResolver, tabs: [TabItem]) {
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
