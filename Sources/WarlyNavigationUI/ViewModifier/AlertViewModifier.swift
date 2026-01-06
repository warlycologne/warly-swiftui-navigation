import SwiftUI
import WarlyNavigation

public extension View {
    func alert(viewModel: Binding<AlertViewModel?>) -> some View {
        modifier(AlertViewModifier(viewModel: viewModel))
    }
}

/// ViewModifier that creates alerts based on the AlertViewModel
/// Works analog to the ```alert(item:...)``` view modifier
private struct AlertViewModifier: ViewModifier {
    @Binding var viewModel: AlertViewModel?
    private var isPresented: Binding<Bool> {
        Binding(
            get: { viewModel != nil },
            set: {
                guard !$0 else { return }
                viewModel = nil
            }
        )
    }

    init(viewModel: Binding<AlertViewModel?>) {
        _viewModel = viewModel
    }

    func body(content: Content) -> some View {
        content
            .alert(
                viewModel?.title ?? "",
                isPresented: isPresented,
                presenting: viewModel,
                actions: { viewModel in
                    AlertActionsView(viewModel: viewModel)
                },
                message: { viewModel in
                    if let message = viewModel.message {
                        Text(message)
                    }
                }
            )
    }
}

private struct AlertActionsView: View {
    let viewModel: AlertViewModel
    @State private var textFieldValues: [AlertTextFieldIdentifier: String] = [:]

    init(viewModel: AlertViewModel) {
        self.viewModel = viewModel
        _textFieldValues = .init(initialValue: viewModel.textFields.reduce(into: [:], { result, textField in
            result[textField.id] = textField.text
        }))
    }

    var body: some View {
        textFields
        buttonActions
    }

    private var textFields: some View {
        ForEach(viewModel.textFields) { textField in
            let textBinding = Binding(
                get: { textFieldValues[textField.id] ?? "" },
                set: { textFieldValues[textField.id] = $0 }
            )
            if textField.isSecure {
                SecureField(textField.placeholder, text: textBinding)
            } else {
                TextField(textField.placeholder, text: textBinding)
            }
        }
    }

    private var buttonActions: some View {
        ForEach(viewModel.actions) { action in
            Button(action.label, role: action.role) {
                Task {
                    await action.action?(textFieldValues)
                }
            }
            .keyboardShortcut(action.isPreferred ? .defaultAction : .none)
        }
    }
}
