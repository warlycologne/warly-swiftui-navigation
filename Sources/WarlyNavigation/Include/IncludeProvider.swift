import SwiftUI

public class IncludeProvider: ObservableObject {
    private let resolver: any IncludeResolver
    private let navigator: (any Navigator)?
    /// Cached user info per view id.
    private var cachedObjects: [ObjectIdentifier: [ObjectIdentifier: WeakObject]] = [:]

    package init(resolver: any IncludeResolver, navigator: any Navigator) {
        self.resolver = resolver
        self.navigator = navigator
    }

    /// Used for default value
    package init() {
        resolver = MockIncludeViewResolver()
        navigator = nil
    }

    @ViewBuilder @MainActor
    public func view<D: IncludeDestination>(for destination: D) -> some View {
        if let navigator, let view = view(for: destination, navigator: navigator) {
            AnyView(view)
        }
    }

    @MainActor
    private func view<D: IncludeDestination>(for destination: D, navigator: any Navigator) -> (any View)? {
        guard let viewDestination = resolver.resolve(destination) else { return nil }

        let identifier = ObjectIdentifier(D.self)
        var context = IncludeContext(cache: cachedObjects[identifier]?.compactMapValues(\.value) ?? [:])
        let view = resolver.view(for: viewDestination, navigator: navigator, context: &context)

        if !context.cache.isEmpty {
            cachedObjects[identifier] = context.cache.mapValues { .init(value: $0) }
        }

        return view
    }
}
