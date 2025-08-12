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
                guard $0 == false else { return }
                viewModel = nil
            }
        )
    }

    func body(content: Content) -> some View {
        content
            .alert(
                viewModel?.title ?? "",
                isPresented: isPresented,
                presenting: viewModel,
                actions: { viewModel in
                    buttonActions(viewModel.actions)
                },
                message: { viewModel in
                    if let message = viewModel.message {
                        Text(message)
                    }
                }
            )
    }

    private func buttonActions(_ actions: [AlertViewModel.Action]) -> some View {
        ForEach(actions) { action in
            Button(action.label, role: action.role) {
                Task {
                    await action.action?(nil)
                }
            }
            .keyboardShortcut(action.isPreferred ? .defaultAction : .none)
        }
    }
}
