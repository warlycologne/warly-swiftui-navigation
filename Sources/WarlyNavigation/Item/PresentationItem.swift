import Foundation
import SwiftUI

public enum Presentation: Sendable {
    case bottomSheet(transition: Transition)
    case fullScreen(transition: Transition)
    case formSheet(transition: Transition)
    case pageSheet(transition: Transition)

    // short hand accessors
    public static let bottomSheet: Self = .bottomSheet(transition: .automatic)
    public static let fullScreen: Self = .fullScreen(transition: .automatic)
    public static let formSheet: Self = .formSheet(transition: .automatic)
    public static let pageSheet: Self = .pageSheet(transition: .automatic)

    public var transition: Transition {
        switch self {
        case .bottomSheet(let transition),
            .fullScreen(let transition),
            .formSheet(let transition),
            .pageSheet(let transition):
            transition
        }
    }
}

/// Defines the style how to transition to a view
public enum Transition: Sendable {
    /// The default behavior depending on the navigation action
    case automatic
    /// A zoom transition 
    case zoom(TransitionID)
}

public struct PresentationItem: Hashable, Identifiable {
    public let id = UUID()
    public let coordinator: any Coordinator
    public let presentation: Presentation
    public let isModal: Bool
    public let onDismiss: (() -> Void)?

    /// Returns itself if it is presented full screen
    public var fullScreenItem: Self? {
        switch presentation {
        case .fullScreen: self
        default: nil
        }
    }

    /// Returns itself if it is presented as a sheet
    public var sheetItem: Self? {
        switch presentation {
        case .bottomSheet, .formSheet, .pageSheet: self
        default: nil
        }
    }

    public var isBottomSheet: Bool {
        guard case .bottomSheet = presentation else { return false }
        return true
    }

    @MainActor
    public var transition: Transition {
        coordinator.root.transition
    }

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
