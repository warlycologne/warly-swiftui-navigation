/// The configuration for handling deeplinks
public struct DeeplinkConfiguration {
    public let appScheme: String?
    public let universalLinkPrefixRegex: String?

    ///
    /// - Parameter appScheme: The app scheme of app deeplinks  without `://`. e.g. `appscheme`
    /// - Parameter universalLinkPrefixRegex: A regex to detect universal links that should be handled as a deeplink. e.g `"https?://(.*\\.)?website\\.de/"`
    public init(appScheme: String? = nil, universalLinkPrefixRegex: String? = nil) {
        self.appScheme = appScheme
        self.universalLinkPrefixRegex = universalLinkPrefixRegex
    }
}
