import Foundation
import SwiftUI

/// Completion handler called after a navigation operation completes.
/// - Parameter navigator: The resulting navigator managing the destination after navigation. May be `nil` if navigation failed or no navigator is available.
public typealias NavigationCompletion = ((any Navigator)?) -> Void

@MainActor
public protocol Navigator: AnyObject, DeeplinkHandler, Sendable {
    var id: UUID { get }

    // MARK: - Requirements
    func resolveRequirements(_ requirements: [RequirementIdentifier]) async -> Bool

    // MARK: - Navigation
    /// Navigates to the given destination
    /// - Parameter destination: The destination to navigate to
    /// - Parameter navigationAction: The optional action how the destination is shown to the user. If nil the default action defined by the destination is used
    /// - Returns the navigator the destination is managed by depending on the navigation action. Returns nil when the destination does not support further navigation
    @discardableResult
    func navigate(to destination: Destination, by navigationAction: NavigationAction?) async -> (any Navigator)?
    /// Navigates back to the occurrence of the given reference.
    /// May be blocked by a finish condition, therefore it's async
    /// - Parameter search: Defines to which occurrence of the reference should be navigated to
    /// - Parameter path: The path where the destination should be searched in
    /// - Returns the navigator on which the found destination is. Returns nil when the reference could not be found
    @discardableResult
    func navigateBack(to search: DestinationSearch, whenIn path: DestinationSearch.Path) async -> (any Navigator)?
    /// Navigates to the previous view
    /// If the current view is the root it calls `finish()`
    /// else it navigates back to the previous view
    /// - Returns the navigator holding the previous view. Returns nil if there is no previous view
    @discardableResult
    func navigateBack() async -> (any Navigator)?

    /// Dismisses the current presented view
    /// May be blocked by a finish condition, therefore it's async
    /// - Returns whether the dismissal was successful
    @discardableResult
    func dismiss() async -> Bool

    // MARK: - Alerts
    /// Shows the given alert
    /// - Parameter `_`: The alert to show
    func showAlert(_ alertViewModel: AlertViewModel)
    /// Dismisses the visible alert
    /// - Parameter id: The id of the alert to match. If nil is given any visible alert is dismissed
    func dismissAlert(id: String?)

    // MARK: - Finishing
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
    /// - Returns the parent navigator or nil if finishing did not succeed
    @discardableResult
    func finish() async -> (any Navigator)?

    /// Finishes the given occurence of a reference
    /// - Parameter reference: Defines to which occurrence of the reference should be finished
    /// - Returns the parent navigator or nil if finishing did not succeed
    @discardableResult
    func finish(_ reference: DestinationReference) async -> (any Navigator)?
}

extension Navigator {
    /// Convenience method to not require wrapping navigation in a Task if the resulting navigator is not needed
    public func navigate(
        to destination: Destination,
        by navigationAction: NavigationAction? = nil,
        completion: NavigationCompletion? = nil
    ) {
        Task {
            let navigator = await navigate(to: destination, by: navigationAction)
            completion?(navigator)
        }
    }

    public func navigateBack(completion: NavigationCompletion? = nil) {
        Task {
            let navigator = await navigateBack()
            completion?(navigator)
        }
    }

    /// Convenience method to navigate back to the destination with given search and path
    /// - Parameter search: Defines to which occurrence of the reference should be navigated to
    /// - Parameter path: The path where the destination should be searched in
    @discardableResult
    public func navigateBack(to search: DestinationSearch, whenIn path: DestinationSearch.Path = .anyPath) async -> (any Navigator)? {
        await navigateBack(to: search, whenIn: path)
    }

    /// Convenience method to navigate back to the destination with given search and path.
    /// - Parameter search: Defines to which occurrence of the reference should be navigated to
    /// - Parameter path: The path where the destination should be searched in
    /// - Parameter completion: The closure to balled with the resulting navigator
    public func navigateBack(to search: DestinationSearch, whenIn path: DestinationSearch.Path = .anyPath, completion: NavigationCompletion? = nil) {
        Task {
            let navigator = await navigateBack(to: search, whenIn: path)
            completion?(navigator)
        }
    }

    /// Convenience method to navigate back to the destination with given reference and path
    /// If you want to navigate to the last occurrence or you know there is only one view with given reference you can use this method
    /// - Parameter reference: Defines to which reference should be navigated to
    /// - Parameter path: The path where the destination should be searched in
    @discardableResult
    public func navigateBack(to reference: DestinationReference, whenIn path: DestinationSearch.Path = .anyPath) async -> (any Navigator)? {
        await navigateBack(to: .last(reference), whenIn: path)
    }

    /// Convenience method to navigate back to the destination with given reference and path
    /// If you want to navigate to the last occurrence or you know there is only one view with given reference you can use this method
    /// - Parameter reference: Defines to which reference should be navigated to
    /// - Parameter path: The path where the destination should be searched in
    /// - Parameter completion: The closure to balled with the resulting navigator
    public func navigateBack(to reference: DestinationReference, whenIn path: DestinationSearch.Path = .anyPath, completion: NavigationCompletion? = nil) {
        Task {
            let navigator = await navigateBack(to: reference, whenIn: path)
            completion?(navigator)
        }
    }

    public func showAlert(
        title: LocalizedStringKey? = nil,
        message: LocalizedStringKey? = nil,
        textFields: [AlertViewModel.TextField] = [],
        actions: [AlertViewModel.Action]
    ) {
        self.showAlert(.init(
            title: title,
            message: message,
            textFields: textFields,
            actions: actions
        ))
    }

    /// Dismiss any alert regardless of id
    public func dismissAlert() {
        dismissAlert(id: nil)
    }

    /// Convenience non-async version to finish the coordinator
    public func finish(completion: NavigationCompletion? = nil) {
        Task {
            let navigator = await finish()
            completion?(navigator)
        }
    }

    /// Convenience non-async version to finish the given reference
    /// - Parameter reference: The reference to finish
    /// - Parameter completion: The closure to balled with the resulting navigator
    public func finish(_ reference: DestinationReference, completion: NavigationCompletion? = nil) {
        Task {
            let navigator = await finish(reference)
            completion?(navigator)
        }
    }
}
