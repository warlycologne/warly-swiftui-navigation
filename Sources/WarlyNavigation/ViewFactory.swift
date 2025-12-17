import SwiftUI

@MainActor
public protocol ViewFactory<Destination> {
    associatedtype Destination: ViewDestination
    associatedtype ResultView: View
    associatedtype DecoratedNavigationStack: View

    /// - Parameter destination: The destination to create the view for
    /// - Parameter navigator: The navigator
    /// - Parameter context: `ViewContext` object containing additional information
    /// - Returns the final view
    @ViewBuilder
    func view(for destination: Destination, navigator: any Navigator, context: inout ViewContext) -> ResultView

    /// - Parameter navigationStack: The navigation stack to decorate
    /// - Parameter destination: The destination this container is created for
    /// - Parameter navigator: The navigator
    /// - Parameter context: `ViewContext` containing additional information
    /// - Returns the decorated container. Return the container if you don't need to decorate it
    @ViewBuilder
    func decorateNavigationStack(_ navigationStack: AnyView, for destination: Destination, navigator: any Navigator, context: ViewContext) -> DecoratedNavigationStack
}

extension ViewFactory {
    public func decorateNavigationStack(_ navigationStack: AnyView, for destination: Destination, navigator: any Navigator, context: ViewContext) -> some View {
        navigationStack
    }
}

extension Dictionary where Key == ObjectIdentifier, Value == any ViewFactory {
    subscript<D: Destination>(destination: D.Type) -> (any ViewFactory<D>)? {
        self[key(for: D.self)] as? any ViewFactory<D>
    }
}

public struct ViewContext: CachableViewContext {
    /// Whether this view is the root of a navigation stack
    public let isRoot: Bool
    /// The reference to this view in the navigation stack, can be used to navigate back to it
    public let reference: DestinationReference
    /// The presentation if this view is presented
    public let presentation: Presentation?

    /// Custom data. See `cache()` and `extract()`
    public var cache: [ObjectIdentifier: AnyObject]
    /// Whether the view shows a close button. Used for internal use only
    let showCloseButton: Bool

    public init(
        isRoot: Bool,
        reference: DestinationReference,
        presentation: Presentation?,
        showCloseButton: Bool,
        cache: [ObjectIdentifier: AnyObject] = [:]
    ) {
        self.isRoot = isRoot
        self.reference = reference
        self.presentation = presentation
        self.showCloseButton = showCloseButton
        self.cache = cache
    }
}
