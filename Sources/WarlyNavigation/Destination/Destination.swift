import SwiftUI

/// The base of all destinations. You may use this type directly if you want to map between destinations
public protocol Destination {
    // Does nothing
}

/// A destination navigating to a url (either deeplink or website link)
public struct URLDestination: Destination {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }
}

extension Destination where Self == URLDestination {
    public static func url(_ url: URL) -> Self {
        .init(url: url)
    }
}

/// A destination navigating to the specified tab id
public struct TabDestination: Destination {
    public let tabID: TabID
    public let popToRoot: Bool

    public init(_ tabID: TabID, popToRoot: Bool = true) {
        self.tabID = tabID
        self.popToRoot = popToRoot
    }
}

extension Destination where Self == TabDestination {
    public static func tab(_ tabID: TabID, popToRoot: Bool = true) -> Self {
        .init(tabID, popToRoot: popToRoot)
    }
}

/// A destination that shows an alert instead of a view
public struct AlertDestination: Destination {
    public let alertViewModel: AlertViewModel

    public init(_ alertViewModel: AlertViewModel) {
        self.alertViewModel = alertViewModel
    }

    public init(
        title: LocalizedStringKey? = nil,
        message: LocalizedStringKey? = nil,
        textFields: [AlertViewModel.TextField] = [],
        actions: [AlertViewModel.Action]
    ) {
        self.init(.init(
            title: title,
            message: message,
            textFields: textFields,
            actions: actions
        ))
    }
}

extension Destination where Self == AlertDestination {
    public static func alert(
        title: LocalizedStringKey? = nil,
        message: LocalizedStringKey? = nil,
        textFields: [AlertViewModel.TextField] = [],
        actions: [AlertViewModel.Action]
    ) -> Self {
        .init(title: title, message: message, textFields: textFields, actions: actions)
    }
}

/// The reference of a destination. You may use this to navigate to a specific destination in the view hierarchy.
/// Extend this struct to add any reference you need. Example:
///
///     extension DestinationReference {
///         static let customReference = Self(rawValue: "customReference")
///     }
@MainActor
public struct DestinationReference: RawRepresentable, Hashable {
    public var rawValue: String

    nonisolated public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct DestinationSearch {
    /// An enum defining which reference to match
    public enum Target {
        /// Matches the reference before a given reference
        case before
        /// Matches exactly a given reference
        case exactly
    }

    /// An enum defining which destination matching a given reference should be matched
    public enum Occurrence {
        /// search for the first occurrence of a given reference in the navigation path
        case first
        /// search for the last occurrence of a given reference in the navigation path
        case last
    }

    /// An enum defining where to search for a destination reference
    public enum Path {
        /// Searches in any path up to the root
        case anyPath
        /// Searches in any previous path
        case previousPath
        /// Searches only in the current path the view is currently on
        case currentPath
    }

    public let target: Target
    public let occurrence: Occurrence
    public let reference: DestinationReference
    public let force: Bool

    public static func first(_ reference: DestinationReference) -> Self {
        .init(target: .exactly, occurrence: .first, reference: reference, force: false)
    }

    public static func last(_ reference: DestinationReference) -> Self {
        .init(target: .exactly, occurrence: .last, reference: reference, force: false)
    }

    func forced() -> Self {
        .init(target: target, occurrence: occurrence, reference: reference, force: true)
    }

    func before() -> Self {
        .init(target: .before, occurrence: occurrence, reference: reference, force: force)
    }
}

@MainActor
public struct TransitionID: Hashable, RawRepresentable {
    public let id = UUID()
    public let rawValue: String

    nonisolated public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

/// An action that defines how a destination should be navigated to
@MainActor
public struct NavigationAction {
    @MainActor
    public enum Action {
        case pushing(transition: Transition = .automatic)
        case presenting(_ presentation: Presentation = .pageSheet, isModal: Bool = false, onDismiss: (@MainActor () -> Void)? = nil)

        // short hand accessors
        public static let pushing: Self = .pushing()
        public static let presenting: Self = .presenting()

        public var isPresenting: Bool {
            switch self {
            case .presenting: true
            default: false
            }
        }

        public var transition: Transition {
            switch self {
            case .pushing(let transition): transition
            case .presenting(let presentation, _, _): presentation.transition
            }
        }
    }

    /// An action that pushes the view onto the navigation stack
    public static let pushing: Self = .init(compact: .pushing)
    /// An action that presents the view on the navigation stack non-modally as a sheet
    public static let presenting: Self = .init(compact: .presenting)
    /// An action that pushes the view on the navigation stack with a custom transition
    /// - Parameter transition: The transition to use when pushing
    /// - Returns the navigation action
    public static func pushing(transition: Transition) -> Self {
        .init(compact: .pushing(transition: transition))
    }
    /// An action that presents the view on the navigation stack with custom configuration
    /// - Parameter presentation: The presentation style, defaults to `.sheet`
    /// - Parameter isModal: Whether the presented view can be dismissed via swipe down, defaults to `false`
    /// - Parameter onDismiss: An optional callback when the view got dismissed
    /// - Returns the navigation action
    public static func presenting(
        _ presentation: Presentation = .pageSheet,
        isModal: Bool = false,
        onDismiss: (@MainActor () -> Void)? = nil
    ) -> Self {
        .init(compact: .presenting(presentation, isModal: isModal, onDismiss: onDismiss))
    }
    /// An action that navigates to the view depending on the horizontal size class
    /// - Parameter compact: The action to use when in compact size class
    /// - Parameter regular: The action to use when in regular size class
    /// - Returns the navigation action
    public static func adaptive(compact: Action, regular: Action) -> Self {
        .init(compact: compact, regular: regular)
    }

    /// Returns the action to be used for the given horizontal size class
    public subscript(horizontalSizeClass: UserInterfaceSizeClass?) -> Action {
        switch horizontalSizeClass ?? .compact {
        case .compact: compact
        case .regular: regular ?? compact
        @unknown default: compact
        }
    }

    private let compact: Action
    private let regular: Action?

    init(compact: Action, regular: Action? = nil) {
        self.compact = compact
        self.regular = regular
    }
}
