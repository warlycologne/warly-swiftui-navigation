import SwiftUI

public protocol IncludeDestination {
    // Does nothing
}

@MainActor
public protocol IncludeViewDestination: IncludeDestination {
}

@MainActor
public protocol IncludeViewFactory<IncludeDestination> {
    associatedtype IncludeDestination: IncludeViewDestination
    associatedtype ResultView: View

    /// - Parameter destination: The destination to create the view for
    /// - Parameter navigator: The navigator
    /// - Parameter context: `IncludeContext` containing additional information 
    /// - Returns the final view
    @ViewBuilder
    func view(for destination: IncludeDestination, navigator: any Navigator, context: inout IncludeContext) -> ResultView
}

public struct IncludeContext: CachableViewContext {
    public var cache: [ObjectIdentifier: AnyObject] = [:]
}
