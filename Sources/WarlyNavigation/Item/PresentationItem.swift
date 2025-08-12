import Foundation
import SwiftUI

public enum Presentation: Sendable {
    case bottomSheet
    case fullScreen
    case sheet
}

public struct PresentationItem: Hashable, Identifiable {
    public let id = UUID()
    public let coordinator: any Coordinator
    public let presentation: Presentation
    public let isModal: Bool
    public let onDismiss: (() -> Void)?

    init(
        coordinator: any Coordinator,
        presentation: Presentation,
        isModal: Bool,
        onDismiss: (() -> Void)?
    ) {
        self.coordinator = coordinator
        self.presentation = presentation
        self.isModal = isModal
        self.onDismiss = onDismiss
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}
