import SwiftUI

// MARK: ViewModel

/// ViewModel for use with the new ```alert(viewModel:)``` modifier
/// For single-button alerts set secondaryButton to nil
public struct AlertViewModel {
    public struct Action: Identifiable {
        public var id: String { String("\(label)") }
        public let label: LocalizedStringKey
        public let action: (([UITextField]?) async -> Void)?
        public let role: ButtonRole?
        public let isPreferred: Bool

        public static func submit(_ label: LocalizedStringKey, role: ButtonRole? = nil, action: @escaping ([UITextField]?) async -> Void) -> Self {
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
