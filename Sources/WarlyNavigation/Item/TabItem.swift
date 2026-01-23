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

extension Array where Element: TabItem {
    /// Returns the `TabItem` with the given tab id if available
    /// - Parameter tabID: The unique id of the tab in question
    /// - Returns the `TabItem` of the id if available
    public subscript(tabID: TabID) -> Element? {
        first { $0.id == tabID }
    }
}

extension DestinationReference {
    /// Use this reference to navigate back to the root of the currently active tab
    public static let tabRoot = Self(rawValue: "tabRoot")
}

public protocol TabItem: Identifiable, Hashable {
    var id: TabID { get }
    var coordinator: any Coordinator { get }
}

extension TabItem {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
