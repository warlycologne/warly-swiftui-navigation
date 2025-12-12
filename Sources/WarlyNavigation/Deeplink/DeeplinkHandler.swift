import Foundation
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "DeeplinkHandler")

/// A protocol to handle deeplinks
@MainActor
public protocol DeeplinkHandler {
    /// Tries to handle given url
    /// - Parameter url: The url to handle
    /// - Returns: `true` if the url could be handled, else `false`
    @discardableResult
    func handleDeeplink(url: URL) -> Bool
}

/// A protocol to provide an action to be executed for a given deeplink url
@MainActor
public protocol DeeplinkResolver {
    /// handles given url and returns a closure to be executed if the url can be handled
    /// otherwise it returns nil
    /// - Parameter url: The url to handle
    func destinationForDeeplink(url: URL) -> Destination?
}

/// A protocol for a concrete module deeplink handler
/// Conforming to this protocol you define app scheme links and universal links as regexes that are supported by this handler
@MainActor
public protocol DeeplinkProvider {
    /// An enum that contains all the cases that your deep links can match
    associatedtype MatchType
    /// An enum that contains all parameters which can occur within the deep links that this handler supports
    associatedtype Parameter: DeeplinkParameter = DeeplinkEmptyParameter

    /// The regex patterns of app scheme urls which this handler supports. You don't have to prepend the app scheme
    /// The links are defined as KeyValuePairs so that the order is kept intact. You should specify the links from specific to generic
    var appSchemeLinks: KeyValuePairs<String, MatchType> { get }
    /// The regex patterns of universal links which this handler supports. You don't have to prepend the scheme and host
    /// The links are defined as KeyValuePairs so that the order is kept intact. You should specify the links from specific to generic
    var universalLinks: KeyValuePairs<String, MatchType> { get }

    /// handles given url and returns a closure to be executed if the url can be handled
    /// otherwise it returns nil
    /// - Parameter url: The url to handle
    /// - Parameter configuration: The configuration for handling deeplinks
    func destinationForDeeplink(url: URL, configuration: DeeplinkConfiguration) -> Destination?

    /// Define this method to perform the navigation for the matched type and parameters
    func destination(for type: MatchType, parameters: DeeplinkParameters<Parameter>) -> (any Destination)?
}

public extension DeeplinkProvider {
    var appSchemeLinks: KeyValuePairs<String, MatchType> { [:] }
    var universalLinks: KeyValuePairs<String, MatchType> { [:] }

    /// tries to find an action that matches the given url
    func destinationForDeeplink(url: URL, configuration: DeeplinkConfiguration) -> Destination? {
        // given url is an app scheme url
        if let appScheme = configuration.appScheme, url.scheme == appScheme {
            return match(url: url, in: appSchemeLinks, prefix: "\(appScheme)://")
        } else if let universalLinkPrefixRegex = configuration.universalLinkPrefixRegex {
            return match(url: url, in: universalLinks, prefix: universalLinkPrefixRegex)
        } else {
            return nil
        }
    }

    private func match(
        url: URL,
        in links: KeyValuePairs<String, MatchType>,
        prefix: String
    ) -> Destination? {
        logger.info("match: \(url.absoluteString, privacy: .public)")
        for (var pattern, matchType) in links {
            var rawParameters: [String: String] = [:]
            // prefix pattern if no scheme is provided
            if !pattern.contains("://") {
                pattern = "\(prefix)\(pattern)"
            }

            // allow any query and fragment after the required pattern
            if !pattern.hasSuffix(".*") {
                // convenience checks to support urls with slash at the end and without
                if pattern.hasSuffix("/") {
                    pattern += "?"
                }
                if !pattern.hasSuffix("/?") {
                    pattern += "/?"
                }

                pattern += "([\\?&#].*)?"
            }

            guard url.absoluteString.dictionaryByMatching(regex: pattern, parameters: &rawParameters) else {
                logger.info("no match with pattern: \(pattern, privacy: .public)")
                continue
            }

            logger.info("match found in pattern: \(pattern, privacy: .public)")
            return destination(
                for: matchType,
                parameters: DeeplinkParameters(values: rawParameters)
            )
        }

        return nil
    }
}

private extension String {
    func dictionaryByMatching(regex regexString: String, parameters: inout [String: String]) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: "^\(regexString)$", options: []),
              let result = regex.firstMatch(in: self, options: [], range: NSRange(location: 0, length: count)) else {
            return false
        }

        guard let nameRegex = try? NSRegularExpression(pattern: "\\(\\?\\<(\\w+)\\>", options: []) else { return false }
        let nameMatches = nameRegex.matches(in: regexString, options: [], range: NSRange(location: 0, length: regexString.count))
        let names = nameMatches.map { textCheckingResult in
            (regexString as NSString).substring(with: textCheckingResult.range(at: 1))
        }

        for name in names {
            let range = result.range(withName: name)
            if range.location != NSNotFound, let swiftRange = Range(range, in: self), !self[swiftRange].isEmpty {
                let string = String(self[swiftRange])
                parameters[name] = string.removingPercentEncoding ?? string
            }
        }

        return true
    }
}
