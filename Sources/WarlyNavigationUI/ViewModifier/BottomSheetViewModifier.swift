import SwiftUI

extension View {
    func bottomSheet(isActive: Bool) -> some View {
        modifier(BottomSheetViewModifier(isActive: isActive))
    }
}

private struct BottomSheetViewModifier: ViewModifier {
    let isActive: Bool
    @State private var defaultBottomSheetHeight: CGFloat = 0
    @State private var customBottomSheetHeight: CGFloat?

    private var bottomSheetHeight: CGFloat {
        customBottomSheetHeight ?? defaultBottomSheetHeight
    }

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGFloat.self, of: \.size.height) {
                // Do not trigger view updates if not active or custom height is set
                guard isActive, customBottomSheetHeight != nil else { return }
                defaultBottomSheetHeight = $0
            }
            .presentationDetents([isActive && bottomSheetHeight > 0 ? .height(bottomSheetHeight) : .large])
            .environment(\.customBottomSheetHeight, $customBottomSheetHeight)
    }
}

extension EnvironmentValues {
    /// A custom value for the height of the active bottom sheet. You may use it if you have a scroll view inside your bottom sheet
    @Entry public var customBottomSheetHeight: Binding<CGFloat?> = .constant(nil)
}
