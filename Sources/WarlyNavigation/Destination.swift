import SwiftUI

// MARK: - Destination Types
/// A protocol to declare destinations that will show a view that the navigator can navigate to
/// You may have any number of `ViewDestination` types per package.
@MainActor
public protocol ViewDestination: Destination, Sendable {
    var preferredAction: NavigationAction { get }
    var requirements: [RequirementIdentifier] { get }
    /// Specifies whether the created view should be cached. Set this to `true` if you create observable objects (e.g. view model) per view
    /// Setting this value to `true` mimics the behavior of views in uikit that are only created once
    /// The default is `false`
    var cacheView: Bool { get }
}

extension ViewDestination {
    public var preferredAction: NavigationAction {
        .pushing
    }

    public var requirements: [RequirementIdentifier] {
        []
    }

    public var cacheView: Bool {
        false
    }
}

/// A destination navigating to a url (either deeplink or website link)
public struct URLDestination: Destination {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }
}

/// A destination navigating to the specified tab id
public struct TabDestination: Destination {
    public let tabID: TabID

    public init(_ tabID: TabID) {
        self.tabID = tabID
    }
}

/// A destination that shows an alert instead of a view
public struct AlertDestination: Destination {
    public let alertViewModel: AlertViewModel
    
    public init(_ alertViewModel: AlertViewModel) {
        self.alertViewModel = alertViewModel
    }
}

/// A destination that is used if the system could not find a `ViewDestination` for the requested destination
/// You can register a view factory to show a custom error view
public struct UnknownDestination: ViewDestination {
    let originalDestination: Destination
}

// MARK: - Related Types
/// The base of all destinations. You may use this type directly if you want to map between destinations
public protocol Destination {
    // Does nothing
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

/// An enum defining which destination matching a given reference should be matched
public enum DestinationOccurrence {
    /// search for the first occurrence of a given reference in the navigation path
    case first
    /// search for the last occurrence of a given reference in the navigation path
    case last
}

/// An enum defining where to search for a destination reference
public enum DestinationSearchPath {
    /// Searches in any path up to the root
    case anyPath
    /// Searches in any previous path
    case previousPath
    /// Searches only in the current path the view is currently on
    case currentPath
}

/// An action that defines how a destination should be navigated to
@MainActor
public struct NavigationAction {
    @MainActor
    public enum Action {
        case pushing
        case presenting(_ presentation: Presentation = .sheet, isModal: Bool = false, onDismiss: (() -> Void)? = nil)

        public static let presenting: Self = .presenting()

        public var isPresenting: Bool {
            switch self {
            case .presenting: true
            default: false
            }
        }
    }

    /// An action that pushes the view onto the navigation stack
    public static let pushing: Self = .init(compact: .pushing)
    /// An action that presents the view on the navigation stack non-modally as a sheet
    public static let presenting: Self = .init(compact: .presenting())
    /// An action that presents the view on the navigation stack with custom configuration
    /// - Parameter presentation: The presentation style, defaults to `.sheet`
    /// - Parameter isModal: Whether the presented view can be dismissed via swipe down, defaults to `false`
    /// - Parameter onDismiss: An optional callback when the view got dismissed
    /// - Returns the navigation action
    public static func presenting(
        _ presentation: Presentation = .sheet,
        isModal: Bool = false,
        onDismiss: (() -> Void)? = nil
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
