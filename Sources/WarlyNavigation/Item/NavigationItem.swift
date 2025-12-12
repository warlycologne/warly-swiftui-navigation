import Foundation
import SwiftUI

typealias ViewID = String

@MainActor
public struct NavigationItem: Hashable, Identifiable {
    /// The destination reference that uniquely identifies this navigation item
    public let id: DestinationReference = .init(rawValue: UUID().uuidString)
    /// The destination for this navigation item
    /// If this navigation item is blocked it returns the blocking destination instead
    public var visibleDestination: ViewDestination {
        (blockingDestination ?? originalDestination)
    }
    /// How this navigation item should be transitioned to
    public let transition: Transition
    /// Whether this navigation item is blocked
    public var isBlocked: Bool {
        blockingDestination != nil
    }

    /// An id that uniquely identifies the view of the visible destination
    private(set) var viewID: ViewID

    /// All references associated with this navigation item
    let references: [DestinationReference]
    /// Convenience accessor to the requirements of this destination
    /// The blocking destination may not have requirements. A navigation item always represents the original
    var requirements: [RequirementIdentifier] { originalDestination.requirements }

    let originalDestination: ViewDestination
    /// A destination that is blocking the original destination due to missing requirements
    private var blockingDestination: ViewDestination?

    /// Creates a new navigation item with given destination and multiple references
    /// - Parameter destination: The destination this navigation item points to
    /// - Parameter transition: The transition to use when showing the destination
    /// - Parameter references: An array of references to support back navigation
    public init(destination: ViewDestination, transition: Transition = .automatic, references: [DestinationReference?] = []) {
        viewID = id.rawValue
        originalDestination = destination
        self.transition = transition
        self.references = references.compactMap { $0 } + destination.references
    }

    nonisolated public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    /// Compares the id of the navigation items
    nonisolated public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

    /// Compares the id (main reference) as well as the other `references` for equality
    /// - Parameter lhs: The navigation item to check for
    /// - Parameter rhs: The reference to look for
    public static func == (lhs: Self, rhs: DestinationReference) -> Bool {
        lhs.id == rhs || lhs.references.contains(rhs)
    }

    /// Blocks the original destination with the given one
    /// - Parameter destination: The destination to block the original destination with
    mutating func block(with destination: any ViewDestination) {
        blockingDestination = destination
        viewID = UUID().uuidString
    }

    /// Unblocks this navigation item to show the original destination
    mutating func unblock() {
        blockingDestination = nil
        viewID = id.rawValue
    }

    func hasSameOriginal(as navigationItem: Self) -> Bool {
        id == navigationItem.id
    }
}

@MainActor
extension Array where Element == NavigationItem {
    func findIndex(of occurrence: DestinationSearch.Occurrence, _ reference: DestinationReference) -> Index? {
        switch occurrence {
        case .first: firstIndex { $0 == reference }
        case .last: lastIndex { $0 == reference }
        }
    }

    func firstIndex(withSameOriginal navigationItem: NavigationItem) -> Index? {
        firstIndex { $0.hasSameOriginal(as: navigationItem) }
    }
}
