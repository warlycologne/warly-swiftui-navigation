import Foundation

/// A parameter that can be found in a deeplink
/// The parameter is defined as a named capture group within the regex and can be accessed by name in `DeeplinkParameters` struct (see below)
public protocol DeeplinkParameter: RawRepresentable, CustomStringConvertible where RawValue == String {}
public extension DeeplinkParameter {
    var description: String {
        "(?<\(rawValue)>[^/?&]*?)"
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
