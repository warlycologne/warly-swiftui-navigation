import Combine
import SwiftUI

/// The tab id of a tab. You may use this to navigate to a specific tab in the app
/// Extend this struct to add any tab id you need. Example:
///
///     extension TabID {
///         public #Identifier("start")
///     }
public struct TabID: Hashable, Sendable {
    private let id = UUID()
    private let name: String

    nonisolated public init(name: String) {
        self.name = name
    }
}

extension Array where Element == TabItem {
    public subscript(tabID: TabID) -> TabItem? {
        first { $0.id == tabID }
    }
}

extension DestinationReference {
    /// Use this reference to navigate back to the root of the currently active tab
    public static let tabRoot = Self(rawValue: "tabRoot")
}

public struct TabItem: Identifiable, Hashable {
    public let id: TabID
    public let title: String
    public let icon: (normal: Image, selected: Image)
    public let coordinator: any Coordinator
    public let badgePublisher: AnyPublisher<String?, Never>

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

    public static func == (lhs: TabItem, rhs: TabItem) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
