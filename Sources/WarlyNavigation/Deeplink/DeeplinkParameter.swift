import Foundation

/// A parameter that can be found in a deeplink
/// The parameter is defined as a non-greedy named capture group within the regex and can be accessed by name in `DeeplinkParameters` struct (see below)
/// Usage:
/// ```
/// // Define your parameters inside a `DeeplinkProvider`
/// enum Parameter: String, DeeplinkParameter {
///     case categoryID
/// }
///
/// // Use the parameter inside a string interpolation
/// "categories/\(Parameter.categoryID)"
///
/// // The parameter will be accessible inside `DeeplinkProvider.destination(for:parameters:)`
/// parameters[.categoryID]
/// ```
public protocol DeeplinkParameter: RawRepresentable, CustomStringConvertible where RawValue == String {}
public extension DeeplinkParameter {
    var description: String {
        "(?<\(rawValue)>[^/?&]*?)"
    }
}

public enum DeeplinkQueryParameterOption: Equatable {
    /// Sets that the query parameter may be omitted
    case optional
    /// Sets the given name as the parameter name, otherwise `rawValue` is used
    case name(String)
}

/// With this extension you may set `DeeplinkQueryParameterOption` on a query parameter
/// ```
/// "categories/\(queryParameter: Parameter.categoryID, .name("categoryId"), .optional)"
/// ```
extension String.StringInterpolation {
    /// Convert the parameter to a query parameter with options
    public mutating func appendInterpolation(
        queryParameter: any DeeplinkParameter,
        _ options: DeeplinkQueryParameterOption...
    ) {
        let name = options.compactMap {
            switch $0 {
            case .name(let name): name
            default: nil
            }
        }.first ?? queryParameter.rawValue
        appendLiteral("(?:&?\(name)=\(queryParameter))\(options.contains(.optional) ? "?" : "")")
    }
}

/// If a module deeplink handler does not support any urls that have parameters this empty shell is used
/// see `ModuleDeeplinkHandler.performNavigation(for:parameters:)`
public enum DeeplinkEmptyParameter: RawRepresentable, DeeplinkParameter {
    public init?(rawValue: String) {
        nil
    }

    public var rawValue: String { "" }
}

/// A dictionary type of parameters that can be found in a deeplink
/// access the values via subscripting
public struct DeeplinkParameters<T: DeeplinkParameter> {
    private var values: [String: String] = [:]

    init(values: [String: String]) {
        self.values = values
    }

    public subscript(key: T) -> String? {
        values[key.rawValue]
    }

    public subscript(key: T) -> Int? {
        guard let value: String = self[key] else {
            return nil
        }

        return Int(value)
    }
}
