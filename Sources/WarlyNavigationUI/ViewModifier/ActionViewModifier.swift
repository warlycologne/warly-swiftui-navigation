import Combine
import SwiftUI
import WarlyNavigation

extension View {
    public func onAction<T: DestinationAction>(_ action: T.Type, when condition: Bool = true, handler: @escaping (T) -> Void) -> some View {
        modifier(ActionViewModifier(action: action, condition: condition, handler: handler))
    }
}

private struct ActionViewModifier<T: DestinationAction>: ViewModifier {
    let action: T.Type
    let condition: Bool
    let handler: (T) -> Void
    @Environment(\.actionCenter) private var actionCenter
    @Environment(\.destinationReference) private var destinationReference
    @State private var subscriptionID: UUID?
    @State private var conditionSubject: CurrentValueSubject<Bool, Never> = .init(false)

    func body(content: Content) -> some View {
        content
            .onAppear {
                conditionSubject.send(condition)
                subscriptionID = actionCenter?.subscribe(
                    target: destinationReference,
                    to: T.self,
                    condition: conditionSubject.eraseToAnyPublisher(),
                    handler: handler
                )
            }
            .onDisappear {
                if let subscriptionID {
                    actionCenter?.unsubscribe(subscriptionID)
                }
            }
            .onChange(of: condition) {
                conditionSubject.send(condition)
            }
    }
}

extension EnvironmentValues {
    /// The center handling destination actions.
    @Entry var actionCenter: (any DestinationActionCenter)?
}
