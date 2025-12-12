import SwiftUI

/// Destinations that are used by the navigation package itself
public enum StateDestination: ViewDestination {
    case notResolvable(Destination)
    case missingViewFactory(any ViewDestination)
    case placeholder

    var isPlaceholder: Bool {
        switch self {
        case .placeholder: true
        default: false
        }
    }
}

/// State views represent essential parts of the app navigation
public enum StateView {
    /// A navigation stack. `isPresenting` is true, when a view is currently presented on top of the navigation stack
    case navigationStack(AnyView, isPresenting: Bool)
    /// A view as the root of a navigation stack. Add a close button (e.g. to the toolbar) when `showCloseButton` is `true`
    case navigationStackContent(AnyView, NavigationStackContentType)
    /// A bottom sheet presented view. Add a close button when `showCloseButton` is `true`
    case bottomSheet(AnyView, showCloseButton: Bool)
}

public enum NavigationStackContentType {
    /// The root
    case root(showCloseButton: Bool)
    /// A view as part of the navigation path
    case path

    public var showCloseButton: Bool {
        switch self {
        case .root(let showCloseButton): showCloseButton
        case .path: false
        }
    }
}

public protocol StateDestinationViewFactory: ViewFactory<StateDestination> {
    associatedtype DecoratedStateView: View

    /// Decorate the given state view with anything you need to match your apps design
    @ViewBuilder
    func decorate(_ view: StateView, navigator: any Navigator, context: ViewContext) -> DecoratedStateView
}
