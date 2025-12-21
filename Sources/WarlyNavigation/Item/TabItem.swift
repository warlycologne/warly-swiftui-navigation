import Combine
import SwiftUI

/// The tab id of a tab. You may use this to navigate to a specific tab in the app
/// Extend this struct to add any tab id you need. Example:
///
///     extension TabID {
///         static let start = Self(name: "start")
///     }
public struct TabID: Hashable, Sendable {
    private let id = UUID()
    private let name: String

    nonisolated public init(name: String) {
        self.name = name
    }
}

extension Array where Element == TabItem {
    /// Returns the `TabItem` with the given tab id if available
    /// - Parameter tabID: The unique id of the tab in question
    /// - Returns the `TabItem` of the id if available
    public subscript(tabID: TabID) -> TabItem? {
        first { $0.id == tabID }
    }
}

extension DestinationReference {
    /// Use this reference to navigate back to the root of the currently active tab
    public static let tabRoot = Self(rawValue: "tabRoot")
}

/// The data model for a tab in a `CoordinatedTabView`
public struct TabItem: Identifiable, Hashable {
    public let id: TabID
    public let title: String
    public let icon: (normal: Image, selected: Image)
    public let coordinator: any Coordinator
    public let badgePublisher: AnyPublisher<String?, Never>

    /// Creates a new tab item data model
    /// - Parameter id: The unique `TabID` of the tab
    /// - Parameter title: The title of the tab
    /// - Parameter icon: The icon of the tab
    /// - Parameter selected: An optional icon used when the tab is selected. Defaults to `icon` if nil
    /// - Parameter coordinator: The coordinator of this tab. Use `Coordinator.makeTabCoordinator(destination:resolver:)` to create it
    /// - Parameter badgePublisher: An optional publisher to set the badge of the tab
    public init(
        id: TabID,
        title: String,
        icon: Image,
        selected: Image? = nil,
        coordinator: any Coordinator,
        badgePublisher: AnyPublisher<String?, Never>? = nil
    ) {
        self.id = id
        self.title = title
        self.icon = (icon, selected ?? icon)
        self.coordinator = coordinator
        self.badgePublisher = badgePublisher ?? Just(nil).eraseToAnyPublisher()
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
