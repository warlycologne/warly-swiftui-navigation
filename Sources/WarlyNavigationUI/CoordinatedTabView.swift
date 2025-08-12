import Combine
import SwiftUI
import WarlyNavigation

public struct CoordinatedTabView: View {
    @Environment(\.coordinatorStack) private var coordinatorStack
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedTab: TabID
    @State private var badges: [TabID: String?] = [:]
    private let tabs: [TabItem]
    private let selectedTabColor: Color?
    private let contentTint: Color?
    private let resolver: any NavigationResolver

    private var iconRenderingMode: Image.TemplateRenderingMode {
        if #available(iOS 26, *) {
            // starting with iOS 26 the unselected tab bar icon adopts the color of the text
            .template
        } else {
            // In prior versions the tab icon is gray when unselected, possibly not matching the style
            .original
        }
    }

    public init(
        tabs: [TabItem],
        selectedTabColor: Color? = nil,
        contentTint: Color? = nil,
        resolver: any NavigationResolver
    ) {
        self.tabs = tabs
        self.selectedTabColor = selectedTabColor
        self.contentTint = contentTint
        self.resolver = resolver
        selectedTab = tabs.first?.id ?? .none
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(tabs) { tab in
                CoordinatedNavigationStack(coordinator: tab.coordinator)
                    .tint(contentTint)
                    .id(tab.id)
                    .tabItem {
                        let isSelected = tab.id == selectedTab
                        (isSelected ? tab.icon.selected : tab.icon.normal)
                            .renderingMode(iconRenderingMode)
                        Text(horizontalSizeClass == .compact || isSelected ? tab.title : "")
                    }
                    .badge(badges[tab.id] ?? "")
                    .onReceive(tab.badgePublisher) { badge in
                        badges[tab.id] = badge
                    }
            }
        }
        .tint(selectedTabColor)
        .onAppear {
            // Make sure to not capture `self` in the closures, otherwise it creates a retain cycle
            resolver.registerMapper(for: TabDestination.self) { [coordinatorStack, $selectedTab] destination in
                Task { @MainActor in
                    guard let coordinator = coordinatorStack.wrappedValue.first,
                        await coordinator.dismiss() else {
                        return
                    }

                    $selectedTab.wrappedValue = destination.tabID
                }

                return nil
            }
        }
    }
}

extension TabID {
    fileprivate static let none = Self(name: "none")
}
