import SwiftUI

// MARK: ViewModel
public struct AlertTextFieldIdentifier: Hashable, Sendable {
    /// The default identifier when using the `default` text field
    public static let `default` = Self("default")
    /// The default identifier when using the `secure` text field
    public static let secure = Self("secure")

    private let identifier: String
    public init(_ identifier: String) {
        self.identifier = identifier
    }
}

/// ViewModel for use with in ``Navigator/showAlert(_:)``
/// You may also use the convenience method ``Navigator/showAlert(title:message:textFields:actions:)`` that creates the view model for you
public struct AlertViewModel {
    public struct Action: Identifiable {
        public var id: String { String("\(label)") }
        public let label: LocalizedStringKey
        public let action: (([AlertTextFieldIdentifier: String]) async -> Void)?
        public let role: ButtonRole?
        public let isPreferred: Bool

        public static func submit(_ label: LocalizedStringKey, role: ButtonRole? = nil, action: @escaping ([AlertTextFieldIdentifier: String]) async -> Void) -> Self {
            Self(label: label, action: action, role: nil, isPreferred: false)
        }
        public static func `default`(_ label: LocalizedStringKey, isPreferred: Bool = false, action: (() async -> Void)? = {}) -> Self {
            Self(label: label, action: { _ in await action?() }, role: nil, isPreferred: isPreferred)
        }
        public static func destructive(_ label: LocalizedStringKey, action: (() async -> Void)? = {}) -> Self {
            Self(label: label, action: { _ in await action?() }, role: .destructive, isPreferred: false)
        }
        public static func cancel(_ label: LocalizedStringKey = "Abbrechen", action: (() async -> Void)? = {}) -> Self {
            Self(label: label, action: { _ in await action?() }, role: .cancel, isPreferred: false)
        }
    }

    @MainActor
    public struct TextField: Identifiable {
        public let id: AlertTextFieldIdentifier
        public let text: String
        public let placeholder: String
        public let isSecure: Bool

        public static func `default`(identifier: AlertTextFieldIdentifier = .default, text: String? = nil, placeholder: String = "") -> Self {
            Self(id: identifier, text: text ?? "", placeholder: placeholder, isSecure: false)
        }

        public static func secure(identifier: AlertTextFieldIdentifier = .secure, text: String? = nil, placeholder: String = "") -> Self {
            Self(id: identifier, text: text ?? "", placeholder: placeholder, isSecure: true)
        }
    }

    public let id: String

    public let title: LocalizedStringKey?
    public let message: LocalizedStringKey?

    public let textFields: [TextField]
    public let actions: [Action]

    public init(
        id: String = UUID().uuidString,
        title: LocalizedStringKey? = nil,
        message: LocalizedStringKey? = nil,
        textFields: [TextField] = [],
        actions: [Action]
    ) {
        self.id = id
        self.title = title
        self.message = message
        self.textFields = textFields
        self.actions = actions
    }
}

extension AlertViewModel: Identifiable {}
extension AlertViewModel: Equatable {
    public static func == (lhs: AlertViewModel, rhs: AlertViewModel) -> Bool {
        lhs.id == rhs.id
    }
}
