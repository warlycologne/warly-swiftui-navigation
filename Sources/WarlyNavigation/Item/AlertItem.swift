import SwiftUI

// MARK: ViewModel

/// ViewModel for use with the new ```alert(viewModel:)``` modifier
/// For single-button alerts set secondaryButton to nil
public struct AlertViewModel {
    public struct Action: Identifiable {
        public var id: String { label }
        public let label: String
        public let action: (([UITextField]?) async -> Void)?
        public let role: ButtonRole?
        public let isPreferred: Bool

        public static func submit(_ label: String, role: ButtonRole? = nil, action: @escaping ([UITextField]?) async -> Void) -> Self {
            Self(label: label, action: action, role: nil, isPreferred: false)
        }
        public static func `default`(_ label: String, isPreferred: Bool = false, action: (() async -> Void)? = {}) -> Self {
            Self(label: label, action: { _ in await action?() }, role: nil, isPreferred: isPreferred)
        }
        public static func destructive(_ label: String, action: (() async -> Void)? = {}) -> Self {
            Self(label: label, action: { _ in await action?() }, role: .destructive, isPreferred: false)
        }
        public static func cancel(_ label: String = "Abbrechen", action: (() async -> Void)? = {}) -> Self {
            Self(label: label, action: { _ in await action?() }, role: .cancel, isPreferred: false)
        }
    }

    @MainActor
    public struct TextField {
        let configurationHandler: ((UITextField) -> Void)?

        public static func `default`(text: String? = nil, placeholder: String? = nil, configurationHandler: ((UITextField) -> Void)? = nil) -> Self {
            Self(configurationHandler: { textField in
                textField.text = text
                textField.placeholder = placeholder
                configurationHandler?(textField)
            })
        }
        public static func secure(text: String? = nil, placeholder: String? = nil, configurationHandler: ((UITextField) -> Void)? = nil) -> Self {
            Self(configurationHandler: { textField in
                textField.isSecureTextEntry = true
                textField.text = text
                textField.placeholder = placeholder
                configurationHandler?(textField)
            })
        }
    }

    public let id: String

    public let title: String?
    public let message: String?

    public let textFields: [TextField]
    public let actions: [Action]

    public init(
        id: String = UUID().uuidString,
        title: String? = nil,
        message: String? = nil,
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
