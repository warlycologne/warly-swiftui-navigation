import Foundation

@MainActor
public protocol URLHandler {
    func handleIncomingURL(_ url: URL, navigator: (any Navigator)?)

    @discardableResult
    func handleOutgoingURL(_ url: URL, navigator: (any Navigator)?) -> Bool
}

public struct DefaultURLHandler: URLHandler {
    public init() {
        // Does nothing
    }

    public func handleIncomingURL(_ url: URL, navigator: (any Navigator)?) {
        navigator?.handleDeeplink(url: url)
    }

    public func handleOutgoingURL(_ url: URL, navigator: (any Navigator)?) -> Bool {
        guard navigator?.handleDeeplink(url: url) ?? false else { return false }
        return true
    }
}
