import SwiftUI
import WarlyNavigation

extension View {
    public func include(resolver: any IncludeResolver, navigator: any Navigator) -> some View {
        modifier(IncludeViewModifier(provider: .init(resolver: resolver, navigator: navigator)))
    }
}

private struct IncludeViewModifier: ViewModifier {
    /// Must remain `@StateObject`, otherwise the provider is not cached anymore
    @StateObject var provider: IncludeProvider

    func body(content: Content) -> some View {
        content
            .environment(\.include, provider)
    }
}

extension EnvironmentValues {
    /// Callable function to include `IncludeDestination` views
    @Entry public var include = IncludeProvider()
}
