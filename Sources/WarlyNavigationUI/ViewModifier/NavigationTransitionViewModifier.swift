import SwiftUI
import WarlyNavigation

extension View {
    func navigationTransition(_ transition: WarlyNavigation.Transition) -> some View {
        modifier(NavigationTransitionViewModifier(transition: transition))
    }
}

private struct NavigationTransitionViewModifier: ViewModifier {
    let transition: WarlyNavigation.Transition
    @Environment(\.transitionNamespace) private var transitionNamespace
    @Namespace private var fallbackNamespace

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *), case .zoom(let transitionID) = transition {
            content
                .navigationTransition(.zoom(sourceID: transitionID, in: transitionNamespace ?? fallbackNamespace))
        } else {
            content
        }
    }
}
