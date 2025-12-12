import SwiftUI
import WarlyNavigation

extension View {
    /// Sets the `presentationSizing` on the view depending on given presention
    /// This is only available from iOS 18.0 and so it is wrapped here
    /// - Parameter presentation: The presentation how the view is displayed
    func sheetSizing(presentation: Presentation) -> some View {
        modifier(SheetSizingViewModifier(presentation: presentation))
    }
}

private struct SheetSizingViewModifier: ViewModifier {
    let presentation: Presentation

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            if case .formSheet = presentation {
                content.presentationSizing(.form)
            } else if case .pageSheet = presentation {
                content.presentationSizing(.page)
            } else {
                content
            }
        } else {
            content
        }
    }
}
