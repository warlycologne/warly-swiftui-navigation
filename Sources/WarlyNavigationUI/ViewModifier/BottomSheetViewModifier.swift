import SwiftUI

extension View {
    func bottomSheet(isActive: Bool) -> some View {
        modifier(BottomSheetViewModifier(isActive: isActive))
    }

    func bottomSheetContent(isActive: Bool) -> some View {
        modifier(BottomSheetContentViewModifier(isActive: isActive))
    }
}

/// The view modifier sets the presentation detent based on the content size if active
private struct BottomSheetViewModifier: ViewModifier {
    let isActive: Bool

    @State private var verticalSafeAreaInsets: CGFloat = 0
    @State private var selectedDetent: PresentationDetent = .large

    func body(content: Content) -> some View {
        content
            .presentationDetents([selectedDetent])
            .onPreferenceChange(BottomSheetHeightKey.self) { bottomSheetHeight in
                if isActive, let bottomSheetHeight {
                    selectedDetent = .height(bottomSheetHeight.value(verticalSafeAreaInsets: verticalSafeAreaInsets))
                } else {
                    selectedDetent = .medium
                }
            }
            .onGeometryChange(for: CGFloat.self) {
                $0.safeAreaInsets.top + $0.safeAreaInsets.bottom
            } action: {
                guard isActive else { return }
                verticalSafeAreaInsets = $0
            }
    }
}

/// The view modifier calculates the height of the content.
/// It reads the content size either by its geometry or, if a scroll view is detected, the content size of that scroll view
private struct BottomSheetContentViewModifier: ViewModifier {
    let isActive: Bool

    @State private var defaultContentHeight: CGFloat?
    @State private var scrollContentHeight: CGFloat?

    private var bottomSheetHeight: BottomSheetHeight? {
        guard isActive else { return nil }
        if let scrollContentHeight, scrollContentHeight > 0 {
            return .scrollContent(scrollContentHeight)
        } else if let defaultContentHeight, defaultContentHeight > 0 {
            return .defaultContent(defaultContentHeight)
        } else {
            return nil
        }
    }

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGFloat.self, of: \.size.height) {
                // Do not trigger view updates if not active or a scroll view is detected
                guard isActive, scrollContentHeight == nil else { return }
                defaultContentHeight = $0
            }
            .onScrollGeometryChange(for: CGFloat.self) {
                $0.contentSize.height + $0.contentInsets.top + $0.contentInsets.bottom
            } action: { _, new in
                // Do not trigger view updates if not active
                guard isActive else { return }
                scrollContentHeight = new
            }
            .preference(key: BottomSheetHeightKey.self, value: bottomSheetHeight)
    }
}

private enum BottomSheetHeight: Equatable {
    case defaultContent(CGFloat)
    case scrollContent(CGFloat)

    func value(verticalSafeAreaInsets: CGFloat) -> CGFloat {
        switch self {
        case .defaultContent(let value): value + verticalSafeAreaInsets
        case .scrollContent(let value): value
        }
    }
}

private struct BottomSheetHeightKey: PreferenceKey {
    static let defaultValue: BottomSheetHeight? = nil

    static func reduce(value: inout BottomSheetHeight?, nextValue: () -> BottomSheetHeight?) {
        guard let next = nextValue() else { return }
        value = next
    }
}
