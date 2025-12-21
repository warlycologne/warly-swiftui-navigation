/// A wrapper that holds coordinators of all currently active navigation stacks
/// The intention of this wrapper is to provide the active coordinators whithout retaining them
public final class CoordinatorStack {
    /// Returns the first coordinator of all active navigation stacks. e.g. the root of a tab
    public var first: (any Coordinator)? {
        coordinatorStack.first?.value as? any Coordinator
    }

    /// Returns thte last coordinator of all active navigation stacks. e.g. a presented navigation stack
    public var last: (any Coordinator)? {
        coordinatorStack.last?.value as? any Coordinator
    }

    private var coordinatorStack: [WeakObject] = []

    /// Creates a new coordinator stack
    public init() {
        // Does nothing
    }

    /// Returns true, if the given coordinator is currently active
    /// - Parameter coordinator: The coordinator in question
    /// - Returns true if the coordinator is currently active
    public func contains(_ coordinator: any Coordinator) -> Bool {
        coordinatorStack.contains { $0.value === coordinator }
    }

    /// Adds a coordinator to the stack
    /// - Parameter coordinator: The coordinator to append
    public func append(_ coordinator: any Coordinator) {
        coordinatorStack.append(.init(value: coordinator))
    }

    /// Removes a coordinator from the stack
    /// - Parameter coordinator: The coordinator to remove
    public func remove(_ coordinator: any Coordinator) {
        coordinatorStack.removeAll { $0.value === coordinator }
    }
}
