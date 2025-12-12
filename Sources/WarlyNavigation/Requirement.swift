import Combine
import Foundation

/// An identifier for a requirement to support auto completion
/// Extend this struct in any package to add new requirement identifiers. Example:
///
///     extension RequirementIdentifier {
///         public static let login = Self(name: "login")
///     }
public struct RequirementIdentifier: Hashable, Sendable {
    private let id = UUID()
    private let name: String

    public init(name: String) {
        self.name = name
    }
}

public enum BlockingReason {
    case navigation
    case invalidation
}

/// A publisher that emits whenever a requirement needs to be resolved again
public typealias RequirementUpdatePublisher = AnyPublisher<Void, Never>

/// Indicates a prerequisite for navigating
/// e.g. whether a user should be logged in before proceeding
@MainActor
public protocol Requirement {
    var identifier: RequirementIdentifier { get }

    /// A publisher that should fire whenever the requirement needs to be resolved again
    var updatePublisher: RequirementUpdatePublisher { get }

    /// A destination that is displayed instead of the view to which this requirement is configured for if this requirement is not fulfilled
    /// - Parameter reason: The reason why blocking destination is requested. You may use this to display a different ui.
    ///   - `navigation` The original destination is the root of a tab and cannot be displayed until the requirement is resolved
    ///   - `invalidation` A previously resolved requirement got invalidated
    /// - Parameter onResolve: A closure that can be used to resolve this requirement.
    func blockingDestination(reason: BlockingReason, onResolve: @escaping () -> Void) -> ViewDestination

    /// Validates if the requirement is already resolved.
    /// - Returns whether the requirement is already resolved
    func isResolved() async -> Bool

    /// Tries to resolve the requirement
    /// - Parameter navigator: The navigator to present a destination
    /// - Returns whether the requirement could be resolved
    func resolve(navigator: any Navigator) async -> Bool
}
