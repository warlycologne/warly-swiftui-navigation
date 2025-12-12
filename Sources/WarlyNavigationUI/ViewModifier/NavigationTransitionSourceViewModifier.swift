import SwiftUI
import WarlyNavigation

extension View {
    @ViewBuilder
    public func navigationTransitionSource(id: TransitionID) -> some View {
        if #available(iOS 18.0, *) {
            modifier(NavigationTransitionSourceViewModifier(transitionID: id) { $0 })
        } else {
            self
        }
    }

    @available(iOS 18.0, *)
    public func navigationTransitionSource(
        id: TransitionID,
        configuration: @escaping (EmptyMatchedTransitionSourceConfiguration) -> some MatchedTransitionSourceConfiguration
    ) -> some View {
        modifier(NavigationTransitionSourceViewModifier(transitionID: id, configuration: configuration))
    }
}

@available(iOS 18.0, *)
private struct NavigationTransitionSourceViewModifier<T: MatchedTransitionSourceConfiguration>: ViewModifier {
    let transitionID: TransitionID
    let configuration: (EmptyMatchedTransitionSourceConfiguration) -> T
    @Environment(\.transitionNamespace) private var transitionNamespace
    @Namespace private var fallbackNamespace

    func body(content: Content) -> some View {
        content
            .matchedTransitionSource(id: transitionID, in: transitionNamespace ?? fallbackNamespace) { configuration($0) }
    }
}
