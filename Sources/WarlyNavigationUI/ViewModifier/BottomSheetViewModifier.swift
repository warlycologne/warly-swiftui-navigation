import SwiftUI

extension View {
    func bottomSheet(isActive: Bool) -> some View {
        modifier(BottomSheetViewModifier(isActive: isActive))
    }
}

private struct BottomSheetViewModifier: ViewModifier {
    let isActive: Bool
    @State private var bottomSheetHeight: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGFloat.self, of: \.size.height) {
                bottomSheetHeight = $0
            }
            .presentationDetents([isActive && bottomSheetHeight > 0 ? .height(bottomSheetHeight) : .large])
    }
}
