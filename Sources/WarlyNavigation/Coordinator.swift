import Combine
import SwiftUI

@MainActor
public protocol Coordinator: Navigator {
    var horizontalSizeClass: UserInterfaceSizeClass? { get set }

    var root: NavigationItem { get }
    var navigationPath: [NavigationItem] { get set }
    var alertViewModel: AlertViewModel? { get set }
    var fullScreenItem: PresentationItem? { get set }
    var sheetItem: PresentationItem? { get set }

    init(
        root: NavigationItem,
        parent: (any Coordinator)?,
        resolver: any NavigationResolver
    )

    func setUp()
    @discardableResult
    func navigateBack(
        to occurrence: DestinationOccurrence,
        _ reference: DestinationReference,
        whenIn path: DestinationSearchPath,
        force: Bool
    ) async -> (any Navigator)?

    @discardableResult
    func dismiss(force: Bool) async -> Bool
    func isFocused(navigationItem: NavigationItem) -> Bool
    func observesRequirement(_ identifier: RequirementIdentifier) -> Bool

    func view(for navigationItem: NavigationItem, context: inout ViewContext) -> any View
    func decorateNavigationStack<T: View>(_ navigationStack: T, isPresenting: Bool, context: ViewContext) -> any View
}

extension Coordinator {
    public func navigateBack(
        to occurrence: DestinationOccurrence,
        _ reference: DestinationReference,
        whenIn path: DestinationSearchPath
    ) async -> (any Navigator)? {
        await navigateBack(to: occurrence, reference, whenIn: path, force: false)
    }
    
    public func dismiss() async -> Bool {
        await dismiss(force: false)
    }
}

@Observable @MainActor
public final class DefaultCoordinator: Coordinator {
    public let id = UUID()
    public var horizontalSizeClass: UserInterfaceSizeClass?

    public private(set) var root: NavigationItem
    public var navigationPath: [NavigationItem] = []
    public var fullScreenItem: PresentationItem? {
        get { presentationItem?.presentation == .fullScreen ? presentationItem : nil }
        set { presentationItem = newValue }
    }
    public var sheetItem: PresentationItem? {
        get { [.sheet, .bottomSheet].contains(presentationItem?.presentation) ? presentationItem : nil }
        set { presentationItem = newValue }
    }
    public var alertViewModel: AlertViewModel?
    private let resolver: any NavigationResolver
    public private(set) weak var parent: (any Coordinator)?

    private var canFinishCondition: (() async -> Bool)?
    private var presentationItem: PresentationItem?

    private var observedRequirements: Set<RequirementIdentifier> = []
    private var currentUnresolvedRequirement: RequirementIdentifier?
    private var cancellables: Set<AnyCancellable> = []
    @ObservationIgnored private var cachedDestinations: [String: (view: any View, context: ViewContext)] = [:]

    private subscript(navigationItem: NavigationItem) -> NavigationItem {
        get { navigationPath.firstIndex(withSameOriginal: navigationItem).map { navigationPath[$0] } ?? root }
        set {
            if navigationItem.hasSameOriginal(as: root) {
                root = newValue
            } else if let index = navigationPath.firstIndex(withSameOriginal: newValue) {
                navigationPath[index] = newValue
            }
        }
    }

    public init(
        root: NavigationItem,
        parent: (any Coordinator)?,
        resolver: any NavigationResolver
    ) {
        self.root = root
        self.parent = parent
        self.resolver = resolver

        // If there is no parent and the root has requirements, it means they haven't been validated.
        // Set a placeholder until the requirements are evaluated
        if parent == nil, !root.requirements.isEmpty {
            self.root.block(with: StateDestination.placeholder)
        }
    }

    public func setUp() {
        observeRequirements(for: root)
    }

    public func navigate(
        to destination: Destination,
        by navigationAction: NavigationAction?,
        reference: DestinationReference?
    ) {
        Task { @MainActor [weak self] in
            guard let self, let destination = resolver.resolveDestination(destination) else {
                return
            }

            // resolve any requirements
            guard await resolveRequirements(for: destination) else {
                return
            }

            let navigationItem = NavigationItem(destination: destination, reference: reference)
            switch (navigationAction ?? destination.preferredAction)[horizontalSizeClass] {
            case .pushing:
                guard await dismiss() else { return }
                observeRequirements(for: navigationItem)
                navigationPath.append(navigationItem)
            case let .presenting(presentation, isModal, onDismiss):
                presentationItem = PresentationItem(
                    coordinator: resolver.makeCoordinator(root: navigationItem, parent: self),
                    presentation: presentation,
                    isModal: isModal,
                    onDismiss: onDismiss
                )
            }
        }
    }

    public func navigateBack(
        to occurrence: DestinationOccurrence,
        _ reference: DestinationReference,
        whenIn path: DestinationSearchPath,
        force: Bool
    ) async -> (any Navigator)? {
        guard let index = (root == reference)
            ? navigationPath.startIndex - 1
            : navigationPath.findIndex(of: occurrence, reference)
        else {
            guard path != .currentPath else { return nil }
            return await parent?.navigateBack(to: occurrence, reference, whenIn: .anyPath)
        }

        switch occurrence {
        case .first:
            if path != .currentPath, let handledCoordinator = await parent?.navigateBack(
                to: occurrence,
                reference,
                whenIn: .anyPath,
                force: force
            ) {
                return handledCoordinator
            }

        case .last: break
        }

        if path != .previousPath {
            navigationPath.removeSubrange(index.advanced(by: 1)...)
        }

        guard await dismiss(force: force) else { return nil }
        return self
    }

    public func navigateBack() async -> (any Navigator)? {
        if navigationPath.isEmpty {
            await finish()
            return parent
        } else {
            pop()
            return self
        }
    }

    public func pop() {
        navigationPath.removeLast()
    }

    public func popToRoot() {
        navigationPath.removeAll()
    }

    public func dismiss(force: Bool) async -> Bool {
        guard !force else {
            presentationItem = nil
            return true
        }

        guard let presentationItem else { return true }
        guard await presentationItem.coordinator.canFinish() else { return false }
        self.presentationItem = nil
        return true
    }

    public func canFinish() async -> Bool {
        guard await presentationItem?.coordinator.canFinish() ?? true else { return false }
        return await canFinishCondition?() ?? true
    }

    @discardableResult
    public func finish() async -> Bool {
        // Not calling `canFinish` here. it is validated in parent's `dismiss` method
        // This is to ensure it is always validated when someone tries to finish this coordinator
        await parent?.dismiss() ?? false
    }

    public func showAlert(_ alertViewModel: AlertViewModel) {
        // Always show alert on top most coordinator
        if let presentationItem {
            presentationItem.coordinator.showAlert(alertViewModel)
        } else {
            self.alertViewModel = alertViewModel
        }
    }

    public func dismissAlert(id: String?) {
        // The alert may be presented on a presented coordinator
        presentationItem?.coordinator.dismissAlert(id: id)

        guard id == nil || alertViewModel?.id == id else { return }
        alertViewModel = nil
    }

    public func setFinishCondition(_ condition: @escaping () async -> Bool) {
        canFinishCondition = condition
    }

    public func removeFinishCondition() {
        canFinishCondition = nil
    }

    public func observesRequirement(_ identifier: RequirementIdentifier) -> Bool {
        observedRequirements.contains(identifier) || (parent?.observesRequirement(identifier) ?? false)
    }

    public func isFocused(navigationItem: NavigationItem) -> Bool {
        guard presentationItem == nil else { return false }
        let focusedDestination = navigationPath.last?.id ?? root.id
        return navigationItem.id == focusedDestination
    }

    public func view(for navigationItem: NavigationItem, context: inout ViewContext) -> any View {
        let view: any View
        if let cachedDestination = cachedDestinations[navigationItem.viewID] {
            view = cachedDestination.view
            context = cachedDestination.context
        } else {
            view = resolver.view(
                for: navigationItem.visibleDestination,
                navigator: self,
                context: &context
            )
        }

        let stateView: StateView
        if context.presentation == .bottomSheet {
            stateView = .bottomSheet(AnyView(view), showCloseButton: context.showCloseButton)
        } else {
            stateView = .navigationStackContent(AnyView(view), context.isRoot ? .root(showCloseButton: context.showCloseButton) : .path)
        }

        return resolver.decorateStateView(stateView, navigator: self, context: context)
            .onAppear { [weak self, context] in
                guard let self, navigationItem.visibleDestination.cacheView else { return }
                cachedDestinations[navigationItem.viewID] = (view, context)
            }
            .onDisappear { [weak self] in
                self?.cachedDestinations.removeValue(forKey: navigationItem.viewID)
            }
    }

    public func decorateNavigationStack<T: View>(_ navigationStack: T, isPresenting: Bool, context: ViewContext) -> any View {
        let view = resolver.decorateNavigationStack(
            AnyView(navigationStack),
            for: root.visibleDestination,
            navigator: self,
            context: context
        )
        return resolver.decorateStateView(.navigationStack(AnyView(view), isPresenting: isPresenting), navigator: self, context: context)
    }

    private func resolveRequirements(for destination: ViewDestination) async -> Bool {
        do throws(NavigationResolverError) {
            try await resolver.resolveRequirements(for: destination, navigator: self)
        } catch {
            return false
        }

        return true
    }

    private func observeRequirements(for navigationItem: NavigationItem) {
        // Get update publishers for all requirements that are not yet observed
        let requirements = navigationItem.requirements
            .filter { !observesRequirement($0) }
            .compactMap { identifier in
                (try? resolver.updatePublisher(for: identifier)).map {
                    (identifier: identifier, publisher: $0.map { identifier })
                }
            }
        guard !requirements.isEmpty else { return }

        observedRequirements.formUnion(requirements.map(\.identifier))
        let publishers = requirements.map(\.publisher)
        guard !publishers.isEmpty else { return }

        Publishers.MergeMany(publishers)
            .receive(on: DispatchQueue.main)
            .dropFirst(navigationItem == root ? 0 : 1)
            .filter { [weak self] in
                [nil, $0].contains(self?.currentUnresolvedRequirement)
            }
            .sink { [weak self] _ in
                guard let self else { return }
                // Block publishers from emitting new values
                currentUnresolvedRequirement = .pending
                Task { @MainActor [weak self] in
                    await self?.evaluateRequirements(for: navigationItem)
                }
            }
            .store(in: &cancellables)
    }

    private func evaluateRequirements(for navigationItem: NavigationItem) async {
        // Nothing to resolve
        guard let unresolvedRequirement = try? await resolver.nextUnresolvedRequirement(for: navigationItem.originalDestination) else {
            if self[navigationItem].isBlocked {
                self[navigationItem].unblock()
                await navigateBack(to: navigationItem.id)
            }

            currentUnresolvedRequirement = nil
            return
        }

        // Set actual unresolved requirement
        currentUnresolvedRequirement = unresolvedRequirement.identifier

        let isPlaceholder = (self[navigationItem].visibleDestination as? StateDestination)?.isPlaceholder ?? false
        let reason: BlockingReason = isPlaceholder ? .navigation : .invalidation
        // Navigate back to before the navigation item in question (or to root)
        guard await navigateBack(to: .first, navigationItem.id, whenIn: .anyPath, force: true) != nil else { return }
        self[navigationItem].block(with: unresolvedRequirement.blockingDestination(reason: reason, onResolve: { [weak self] in
            Task { [weak self] in
                guard let self else { return }
                _ = await unresolvedRequirement.resolve(navigator: self)
            }
        }))
    }
}

// MARK: - Deeplinks
extension DefaultCoordinator {
    @discardableResult
    public func handleDeeplink(url: URL) -> Bool {
        guard let destination = resolver.destinationForDeeplink(url: url) else {
            return false
        }

        guard let viewDestination = resolver.resolveDestination(destination) else {
            return true
        }

        // if the preferred action is presenting we use that configuration otherwise we use the normal presentation
        let navigationAction = viewDestination.preferredAction[horizontalSizeClass].isPresenting
            ? viewDestination.preferredAction
            : .presenting

        navigate(to: destination, by: navigationAction, reference: nil)
        return true
    }
}

extension RequirementIdentifier {
    fileprivate static let pending = Self(name: "pending")
}

@MainActor
extension Array where Element == any Coordinator {
    public func contains(_ coordinator: any Coordinator) -> Bool {
        contains { $0.id == coordinator.id }
    }

    public mutating func remove(_ coordinator: any Coordinator) {
        removeAll { $0.id == coordinator.id }
    }
}
