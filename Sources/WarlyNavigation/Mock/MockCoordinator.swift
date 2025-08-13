import SwiftUI

public typealias MockNavigator = MockCoordinator
public class MockCoordinator: Coordinator {
    public let id = UUID()

    public var horizontalSizeClass: UserInterfaceSizeClass?
    public var root: NavigationItem
    public var navigationPath: [NavigationItem] = []

    public var alertViewModel: AlertViewModel?
    public var fullScreenItem: PresentationItem? {
        get { presentationItem?.presentation == .fullScreen ? presentationItem : nil }
        set { presentationItem = newValue }
    }
    public var sheetItem: PresentationItem? {
        get { presentationItem?.presentation == .sheet ? presentationItem : nil }
        set { presentationItem = newValue }
    }

    public var presentationItem: PresentationItem?

    /// Required by protocol, does only set root
    required public init(root: NavigationItem, parent: (any Coordinator)?, resolver: any NavigationResolver) {
        self.root = root
    }

    public init() {
        root = .init(destination: MockViewDestination())
    }

    public func setUp() {
        // Does nothing
    }

    public func navigate(
        to destination: Destination,
        by navigationAction: NavigationAction?,
        reference: DestinationReference?
    ) {
        // Does nothing
    }

    public func navigateBack(
        to occurrence: DestinationOccurrence,
        _ reference: DestinationReference,
        whenIn path: DestinationSearchPath,
        force: Bool
    ) async -> (any Navigator)? {
        nil
    }

    public func navigateBack() async -> (any Navigator)? {
        nil
    }

    public func pop() {
        // Does nothing
    }

    public func popToRoot() {
        // Does nothing
    }

    public func dismiss(force: Bool) async -> Bool {
        true
    }

    public func canFinish() async -> Bool {
        true
    }

    public func finish() async -> Bool {
        true
    }

    public func showAlert(_ alertViewModel: AlertViewModel) {
        self.alertViewModel = alertViewModel
    }

    public func dismissAlert(id: String?) {
        guard id == nil || alertViewModel?.id == id else { return }
        alertViewModel = nil
    }

    public func setFinishCondition(_ condition: @escaping () async -> Bool) {
        // Does nothing
    }

    public func removeFinishCondition() {
        // Does nothing
    }

    public func handleDeeplink(url: URL) -> Bool {
        false
    }

    public func observesRequirement(_ identifier: RequirementIdentifier) -> Bool {
        false
    }

    public func isFocused(navigationItem: NavigationItem) -> Bool {
        true
    }

    public func view(for navigationItem: NavigationItem, context: inout ViewContext) -> any View {
        EmptyView()
    }

    public func decorateNavigationStack<T: View>(_ navigationStack: T, isPresenting: Bool, context: ViewContext) -> any View {
        navigationStack
    }
}
