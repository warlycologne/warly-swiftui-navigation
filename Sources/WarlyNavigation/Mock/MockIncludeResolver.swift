import SwiftUI

final class MockIncludeViewResolver: IncludeResolver {
    func registerMapper<D: IncludeDestination>(for destination: D.Type, mapper: @escaping (D) -> IncludeDestination?) {
        // Does nothing
    }

    func registerViewFactory<T: IncludeViewFactory>(_ viewFactory: T) {
        // Does nothing
    }

    func view<D: IncludeViewDestination>(for destination: D, navigator: any Navigator, context: inout IncludeContext) -> (any View)? {
        nil
    }

    func resolve<D: IncludeDestination>(_ destination: D) -> (any IncludeViewDestination)? {
        nil
    }
}
