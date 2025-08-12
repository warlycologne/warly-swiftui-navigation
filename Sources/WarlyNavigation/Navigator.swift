import Foundation

@MainActor
public protocol Navigator: AnyObject, DeeplinkHandler, Sendable {
    var id: UUID { get }

    /// Navigates to the given destination
    /// - Parameter destination: The destination to navigate to
    /// - Parameter navigationAction: The optional action how the destination is shown to the user. If nil the default action defined by the destination is used
    /// - Parameter reference: An optional reference identifying the destination. Can be used to navigate back to it
    func navigate(
        to destination: Destination,
        by navigationAction: NavigationAction?,
        reference: DestinationReference?
    )
    /// Navigates back to the given reference. When there are multiple destinations of the same reference the occurrence defined which one to navigate to
    /// May be blocked by a finish condition, therefore it's async
    /// - Parameter occurrence: Defines to which occurrence of the reference should be navigated to
    /// - Parameter reference: The reference to navigate back to
    /// - Parameter path: The path where the destination should be searched in
    /// - Returns the navigator on which the found destination is. Returns nil when the reference could not be found
    @discardableResult
    func navigateBack(
        to occurrence: DestinationOccurrence,
        _ reference: DestinationReference,
        whenIn path: DestinationSearchPath
    ) async -> (any Navigator)?

    /// Navigates to the previous view
    /// If the current view is the root it calls `finish()`
    /// else it `pop()` to the previous view
    /// - Returns the navigator holding the previous view. Returns nil if there is no previous view
    @discardableResult
    func navigateBack() async -> (any Navigator)?

    /// Pops the current destination of the navigation stack
    func pop()
    /// Pops to the root of the navigation stack
    func popToRoot()

    /// Dismisses the current presented view
    /// May be blocked by a finish condition, therefore it's async
    /// - Returns whether the dismissal was successful
    @discardableResult
    func dismiss() async -> Bool

    /// Shows the given alert
    /// - Parameter `_`: The alert to show
    func showAlert(_ alertViewModel: AlertViewModel)
    /// Dismisses the visible alert
    /// - Parameter id: The id of the alert to match. If nil is given any visible alert is dismissed
    func dismissAlert(id: String?)

    /// Validates if the can be finished. Tries to resolve any finish condition
    /// - Returns whether the navigation stack can be dismissed.
    func canFinish() async -> Bool
    /// Sets a condition that is executed when the navigation stack is getting dismissed
    /// - Parameter `_`: The condition to meet, before the navigation stack can be dismissed
    func setFinishCondition(_ condition: @escaping () async -> Bool)
    /// Removes previously set finish condition
    func removeFinishCondition()

    /// Finishes this navigator and dismisses it's navigation stack
    /// Any finish condition is resolved
    /// - Returns whether the navigation stack could be dismissed
    @discardableResult
    func finish() async -> Bool
}

extension Navigator {
    /// Convenience method to have auto completion show `navigate(to:)` and `navigate(to:by:)` suggestions
    public func navigate(to destination: Destination, by navigationAction: NavigationAction? = nil) {
        navigate(to: destination, by: navigationAction, reference: nil)
    }

    /// Convenience method to navigate back to the destination with given reference in any path
    /// If you want to navigate to the last occurrence or you know there is only one view with given reference you can use this method
    /// - Parameter occurrence: Defines to which occurrence of the reference should be navigated to
    /// - Parameter reference: The reference to navigate back to
    /// - Returns the navigator on which the found destination is. Returns nil when the reference could not be found
    @discardableResult
    public func navigateBack(to occurrence: DestinationOccurrence, _ reference: DestinationReference) async -> (any Navigator)? {
        await navigateBack(to: occurrence, reference, whenIn: .anyPath)
    }

    /// Convenience method to navigate back to the last occurrence of given reference
    /// If you want to navigate to the last occurrence or you know there is only one view with given reference you can use this method
    /// - Parameter reference: The reference to navigate back to
    /// - Returns the navigator on which the found destination is. Returns nil when the reference could not be found
    @discardableResult
    public func navigateBack(to reference: DestinationReference) async -> (any Navigator)? {
        await navigateBack(to: .last, reference)
    }

    /// Dismiss any alert regardless of id
    public func dismissAlert() {
        dismissAlert(id: nil)
    }
}
