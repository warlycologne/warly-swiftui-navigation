import SwiftUI

/// A protocol to declare destinations that will show a view that the navigator can navigate to
/// You may have any number of `ViewDestination` types per package.
@MainActor
public protocol ViewDestination: Destination, Sendable {
    var preferredAction: NavigationAction { get }
    /// The references associated with the destination
    var references: [DestinationReference] { get }
    /// The requirements to be resolved before navigating to the destination
    var requirements: [RequirementIdentifier] { get }
}

extension ViewDestination {
    public var preferredAction: NavigationAction {
        .pushing
    }

    public var references: [DestinationReference] {
        []
    }

    public var requirements: [RequirementIdentifier] {
        []
    }
}

/// A destination that handles navigation itself
public struct HandledDestination: ViewDestination {
    public let execute: () async -> (any Coordinator)?
    public init(execute: @escaping () async -> (any Coordinator)?) {
        self.execute = execute
    }
}
