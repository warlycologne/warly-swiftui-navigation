import Combine
import Foundation

/// A protocol defining an action that can be send to a destination
public protocol DestinationAction {
    // Does nothing
}

/// An action with a target. Used for internal forwarding
struct TargetedDestinationAction {
    /// The target the notification is meant for
    let target: DestinationReference
    /// The action to delivery
    let action: DestinationAction
}

/// A destination with an action to be executed after navigating to it
public struct ActionableDestination: Destination {
    let destination: Destination
    let action: DestinationAction?
}

extension Destination {
    /// Convenience method to attach an action to a destination
    /// - Parameter action: The action to be executed after navigating to the destination
    /// - Returns an `ActionableDestination`
    public func withAction(_ action: DestinationAction?) -> ActionableDestination {
        .init(destination: self, action: action)
    }
}

@MainActor
public protocol DestinationActionCenter {
    func sendAction<T: DestinationAction>(_ action: T, to target: DestinationReference)
    func subscribe<T: DestinationAction>(
        target: DestinationReference,
        to action: T.Type,
        condition: AnyPublisher<Bool, Never>,
        handler: @escaping (T) -> Void
    ) -> UUID
    func unsubscribe(_ subscriptionID: UUID)
}
