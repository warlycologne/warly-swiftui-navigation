import Foundation
import SwiftUI

public struct NavigationItem: Hashable, Identifiable {
    /// The destination reference that uniquely identifies this navigation item
    public let id: DestinationReference = .init(rawValue: UUID().uuidString)
    /// The destination for this navigation item
    /// If this navigation item is blocked it returns the blocking destination instead
    public var visibleDestination: any ViewDestination {
        (blockingDestination ?? originalDestination)
    }
    /// Whether this navigation item is blocked
    public var isBlocked: Bool {
        blockingDestination != nil
    }

    /// An id that uniquely identifies the view of the visible destination
    private(set) var viewID: String

    /// All references associated with this navigation item
    let references: [DestinationReference]
    /// Convenience accessor to the requirements of this destination
    /// The blocking destination may not have requirements. A navigation item always represents the original
    @MainActor var requirements: [RequirementIdentifier] { originalDestination.requirements }

    let originalDestination: any ViewDestination
    /// A destination that is blocking the original destination due to missing requirements
    private var blockingDestination: (any ViewDestination)?

    /// Creates a new navigation item with given destination and optional reference
    /// - Parameter destination: The destination this navigation item points to
    /// - Parameter reference: An optional reference to support back navigation to this navigation item
    public init(destination: any ViewDestination, reference: DestinationReference? = nil) {
        self.init(destination: destination, references: reference.map { [$0] } ?? [])
    }

    /// Creates a new navigation item with given destination and multiple references
    /// - Parameter destination: The destination this navigation item points to
    /// - Parameter references: An array of references to support back navigation
    public init(destination: any ViewDestination, references: [DestinationReference?]) {
        viewID = id.rawValue
        originalDestination = destination
        self.references = references.compactMap { $0 }
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    /// Compares the id of the navigation items
    public static func == (lhs: Self, rhs: Self) -> Bool {
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

    func hasSameOriginal(as navigationItem: NavigationItem) -> Bool {
        id == navigationItem.id
    }
}

extension Array where Element == NavigationItem {
    func findIndex(of occurrence: DestinationOccurrence, _ reference: DestinationReference) -> Index? {
        switch occurrence {
        case .first: firstIndex { $0 == reference }
        case .last: lastIndex { $0 == reference }
        }
    }

    func firstIndex(withSameOriginal navigationItem: NavigationItem) -> Index? {
        firstIndex { $0.hasSameOriginal(as: navigationItem) }
    }
}
