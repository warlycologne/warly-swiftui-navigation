import SwiftUI

extension View {
    /// Called whenever the current view is focused and the user can interact with it (no presented view on top)
    public func onFocus(perform action: (() -> Void)? = nil) -> some View {
        modifier(FocusViewModifier {
            $0 ? action?() : nil
        })
    }

    /// Called whenever the view loses its focus, e.g. a view is presented on top or the user navigated away
    public func onBlur(perform action: (() -> Void)? = nil) -> some View {
        modifier(FocusViewModifier {
            !$0 ? action?() : nil
        })
    }
}

private struct FocusViewModifier: ViewModifier {
    @Environment(\.isViewFocused) private var isFocused
    let action: ((Bool) -> Void)?

    func body(content: Content) -> some View {
        content
            .onChange(of: isFocused) {
                action?(isFocused)
            }
    }
}
