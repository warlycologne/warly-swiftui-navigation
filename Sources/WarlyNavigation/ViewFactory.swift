import SwiftUI

@MainActor
public protocol ViewFactory<D> {
    associatedtype D: ViewDestination
    associatedtype V: View
    associatedtype N: View

    /// - Parameter destination: The destination to create the view for
    /// - Parameter navigator: The navigator
    /// - Parameter context: `ViewContext` object containing additional information
    /// - Returns the final view
    @ViewBuilder
    func view(for destination: D, navigator: any Navigator, context: inout ViewContext) -> V

    /// - Parameter container: The container to decorate
    /// - Parameter destination: The destination this container is created for
    /// - Parameter navigator: The navigator
    /// - Parameter context: `ViewContext` object containing additional information
    /// - Returns the decorated container. Return the container if you don't need to decorate it
    @ViewBuilder
    func decorateNavigationStack(_ navigationStack: AnyView, for destination: D, navigator: any Navigator, context: ViewContext) -> N
}

extension ViewFactory {
    public func decorateNavigationStack(_ navigationStack: AnyView, for destination: D, navigator: any Navigator, context: ViewContext) -> some View {
        navigationStack
    }

    /// Use this method to store any userInfo in the context for the `decorate()` method and create the view with given user info
    /// - Parameter userInfo: The user info to store in context
    /// - Parameter context: The context to create the view for
    /// - Parameter builder: The view builder to create the view
    /// - Returns the final view
    public func insert<U, V: View>(_ userInfo: U, into context: inout ViewContext, @ViewBuilder builder: (U) -> V) -> some View {
        context.userInfo = userInfo
        return builder(userInfo)
    }

    /// Use this method inside the `decorate()` method to extract any userInfo from the context and create the view with given user info
    /// - Parameter type: The type of the user info to extract from the context
    /// - Parameter context: The context to create the view for
    /// - Parameter builder: The view builder to create the view
    /// - Returns the final view
    @ViewBuilder
    public func extract<U, V: View>(_ type: U.Type, from context: ViewContext, @ViewBuilder builder: (U) -> V) -> some View {
        if let userInfo = context.userInfo as? U {
            builder(userInfo)
        } else {
            let _ = assertionFailure("Context did not contain userInfo of type \(U.self)")
        }
    }
}

public struct ViewContext {
    /// Whether this view is the root of a navigation stack
    public let isRoot: Bool
    /// The reference to this view in the navigation stack, can be used to navigate back to it
    public let reference: DestinationReference
    /// The horizontal class of the view. Can be used to return different views
    public let horizontalSizeClass: UserInterfaceSizeClass?
    /// The presentation if this view is presented
    public let presentation: Presentation?
    /// Custom data. See `ViewFactory.insert()` and `ViewFactory.extract()`
    public var userInfo: Any?

    /// Whether the view shows a close button. Used for internal use only
    let showCloseButton: Bool

    public init(
        isRoot: Bool,
        reference: DestinationReference,
        horizontalSizeClass: UserInterfaceSizeClass?,
        presentation: Presentation?,
        showCloseButton: Bool,
        userInfo: Any? = nil
    ) {
        self.isRoot = isRoot
        self.reference = reference
        self.horizontalSizeClass = horizontalSizeClass
        self.presentation = presentation
        self.showCloseButton = showCloseButton
        self.userInfo = userInfo
    }
}
