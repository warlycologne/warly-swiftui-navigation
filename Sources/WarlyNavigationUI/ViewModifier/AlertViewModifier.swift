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
    @State private var textFieldValues: [AlertTextFieldIdentifier: String] = [:]
    private var isPresented: Binding<Bool> {
        Binding(
            get: { viewModel != nil },
            set: {
                guard $0 == false else { return }
                viewModel = nil
            }
        )
    }

    init(viewModel: Binding<AlertViewModel?>) {
        _viewModel = viewModel
        _textFieldValues = .init(initialValue: viewModel.wrappedValue?.textFields.reduce(into: [:], { result, textField in
            result[textField.id] = textField.text
        }) ?? [:])
    }

    func body(content: Content) -> some View {
        content
            .alert(
                viewModel?.title ?? "",
                isPresented: isPresented,
                presenting: viewModel,
                actions: { viewModel in
                    textFields(viewModel.textFields)
                    buttonActions(viewModel.actions)
                },
                message: { viewModel in
                    if let message = viewModel.message {
                        Text(message)
                    }
                }
            )
    }

    private func textFields(_ textFields: [AlertViewModel.TextField]) -> some View {
        ForEach(textFields) { textField in
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

    private func buttonActions(_ actions: [AlertViewModel.Action]) -> some View {
        ForEach(actions) { action in
            Button(action.label, role: action.role) {
                Task {
                    await action.action?(textFieldValues)
                }
            }
            .keyboardShortcut(action.isPreferred ? .defaultAction : .none)
        }
    }
}
