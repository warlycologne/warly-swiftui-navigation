import Combine
import SwiftUI

@MainActor
public protocol Coordinator: Navigator {
    var appHorizontalSizeClass: UserInterfaceSizeClass? { get set }

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
    func sendAction(_ action: DestinationAction)

    @discardableResult
    func dismiss(force: Bool) async -> Bool
    func isFocused(navigationItem: NavigationItem) -> Bool
    func observesRequirement(_ identifier: RequirementIdentifier) -> Bool

    func view(for navigationItem: NavigationItem, context: inout ViewContext) -> any View
    func decorateNavigationStack<T: View>(_ navigationStack: T, isPresenting: Bool, context: ViewContext) -> any View

    func itemDidAppear()
    func itemDidDisappear()
}

extension Coordinator {
    public func dismiss() async -> Bool {
        await dismiss(force: false)
    }
}

extension Coordinator where Self == DefaultCoordinator {
    public static func makeTabCoordinator(destination: ViewDestination, resolver: any NavigationResolver) -> Self {
        .init(root: .init(destination: destination, references: [.tabRoot]), parent: nil, resolver: resolver)
    }
}

@Observable @MainActor
public final class DefaultCoordinator: Coordinator {
    public let id = UUID()
    /// Used for unit tests as the coordinator is not hooked up to a view
    internal var disableLifecycleObservation = false
    @ObservationIgnored public var appHorizontalSizeClass: UserInterfaceSizeClass?

    public private(set) var root: NavigationItem
    public var navigationPath: [NavigationItem] = [] {
        didSet {
            // Remove caches for removed navigation items
            Set(oldValue.map(\.viewID)).subtracting(navigationPath.map(\.viewID)).forEach {
                cleanUp(for: $0)
            }
        }
    }
    public var fullScreenItem: PresentationItem? {
        get { presentationItem?.fullScreenItem }
        set { presentationItem = newValue }
    }
    public var sheetItem: PresentationItem? {
        get { presentationItem?.sheetItem }
        set { presentationItem = newValue }
    }
    public var alertViewModel: AlertViewModel?
    private let resolver: any NavigationResolver
    @ObservationIgnored public private(set) weak var parent: (any Coordinator)?

    @ObservationIgnored private var canFinishCondition: (() async -> Bool)?
    private var presentationItem: PresentationItem? {
        didSet {
            if presentationItem == nil, let viewID = oldValue?.coordinator.root.viewID {
                cleanUp(for: viewID)
            }
        }
    }

    private var currentUnresolvedRequirement: RequirementIdentifier?
    @ObservationIgnored private var observedRequirements: Set<RequirementIdentifier> = []
    @ObservationIgnored private var requirementCancellables: [ViewID: AnyCancellable] = [:]
    /// Cached objects per view id.
    @ObservationIgnored private var cachedObjects: [ViewID: [ObjectIdentifier: Weak<AnyObject>]] = [:]
    @ObservationIgnored private var appearContinuation: CheckedContinuation<Void, Never>?
    @ObservationIgnored private var disappearContinuation: CheckedContinuation<Void, Never>?

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

    public static func makeTabCoordinator(
        destination: any ViewDestination,
        resolver: any NavigationResolver
    ) -> Self {
        .init(root: .init(destination: destination, references: [.tabRoot]), parent: nil, resolver: resolver)
    }

    public func setUp() {
        observeRequirements(for: root)
    }

    public func resolveRequirements(_ requirements: [RequirementIdentifier]) async -> Bool {
        do throws(NavigationResolverError) {
            try await resolver.resolveRequirements(requirements, navigator: self)
        } catch {
            return false
        }

        return true
    }

    public func navigate(to destination: Destination, by navigationAction: NavigationAction?) async -> (any Navigator)? {
        guard let (destination, action) = resolver.resolveDestination(destination) else {
            return nil
        }

        let result = await Task {
            if let handledDestination = destination as? HandledDestination {
                return await handledDestination.execute()
            }

            // resolve any requirements
            guard await resolveRequirements(destination.requirements) else {
                return nil
            }

            let navigationAction = (navigationAction ?? destination.preferredAction)[appHorizontalSizeClass]
            let navigationItem = NavigationItem(destination: destination, transition: navigationAction.transition)
            switch navigationAction {
            case .pushing:
                guard await dismiss() else { return self }
                observeRequirements(for: navigationItem)
                navigationPath.append(navigationItem)
                await itemDidCompleteAppearing()
                return self
            case let .presenting(presentation, isModal, onDismiss):
                let coordinator = Self(root: navigationItem, parent: self, resolver: resolver)
                presentationItem = PresentationItem(
                    coordinator: coordinator,
                    presentation: presentation,
                    isModal: isModal,
                    onDismiss: onDismiss
                )
                await itemDidCompleteAppearing()
                return coordinator
            }
        }.value

        action.map { result?.sendAction($0) }
        return result
    }

    public func navigateBack(to search: DestinationSearch, whenIn path: DestinationSearch.Path) async -> (any Navigator)? {
        guard let index = (root == search.reference)
            ? navigationPath.startIndex - 1
            : navigationPath.findIndex(of: search.occurrence, search.reference)
        else {
            guard path != .currentPath else { return nil }
            let result = await parent?.navigateBack(to: search, whenIn: .anyPath)
            return result
        }

        switch search.occurrence {
        case .first:
            if path != .currentPath, let handledCoordinator = await parent?.navigateBack(to: search, whenIn: .anyPath) {
                return handledCoordinator
            }

        case .last: break
        }

        if path != .previousPath {
            if root == search.reference {
                navigationPath.removeAll()
                if search.target == .before {
                    return await finish()
                }
            } else {
                let lowerBound = search.target == .before ? index : navigationPath.index(after: index)
                navigationPath.removeSubrange(lowerBound...)
            }
        }

        guard await dismiss(force: search.force) else { return nil }
        return self
    }

    public func navigateBack() async -> (any Navigator)? {
        if navigationPath.isEmpty {
            await finish()
            return parent
        } else {
            navigationPath.removeLast()
            await itemDidCompleteDisappearing()
            return self
        }
    }

    public func dismiss(force: Bool) async -> Bool {
        guard let presentationItem else { return true }
        if !force {
            guard await presentationItem.coordinator.canFinish() else { return false }
        }

        self.presentationItem = nil
        await itemDidCompleteDisappearing()
        return true
    }

    public func canFinish() async -> Bool {
        guard await presentationItem?.coordinator.canFinish() ?? true else { return false }
        return await canFinishCondition?() ?? true
    }

    @discardableResult
    public func finish() async -> (any Navigator)? {
        // Not calling `canFinish` here. it is validated in parent's `dismiss` method
        // This is to ensure it is always validated when someone tries to finish this coordinator
        await parent?.dismiss() ?? false ? parent : nil
    }

    public func finish(_ reference: DestinationReference) async -> (any Navigator)? {
        await navigateBack(to: .first(reference).before(), whenIn: .anyPath)
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

    public func sendAction(_ action: DestinationAction) {
        if let presentationItem {
            presentationItem.coordinator.sendAction(action)
        } else {
            resolver.sendAction(action, to: navigationPath.last?.id ?? root.id)
        }
    }

    public func observesRequirement(_ identifier: RequirementIdentifier) -> Bool {
        observedRequirements.contains(identifier) || (parent?.observesRequirement(identifier) ?? false)
    }

    public func isFocused(navigationItem: NavigationItem) -> Bool {
        guard presentationItem == nil else { return false }
        return navigationItem == navigationPath.last ?? root
    }

    public func view(for navigationItem: NavigationItem, context: inout ViewContext) -> any View {
        context.cache = cachedObjects[navigationItem.viewID]?.compactMapValues(\.value) ?? [:]
        let view = resolver.view(
            for: navigationItem.visibleDestination,
            navigator: self,
            context: &context
        )
        if !context.cache.isEmpty {
            cachedObjects[navigationItem.viewID] = context.cache.mapValues { .init(value: $0) }
        }

        return view
    }

    public func decorateNavigationStack<T: View>(_ navigationStack: T, isPresenting: Bool, context: ViewContext) -> any View {
        resolver.decorateNavigationStack(
            navigationStack,
            for: root.visibleDestination,
            isPresenting: isPresenting,
            navigator: self,
            context: context
        )
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

        requirementCancellables[navigationItem.viewID] = Publishers.MergeMany(publishers)
            .receive(on: RunLoop.main)
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
    }

    private func evaluateRequirements(for navigationItem: NavigationItem) async {
        let isPlaceholder = (self[navigationItem].visibleDestination as? StateDestination)?.isPlaceholder ?? false

        // Nothing to resolve
        guard let unresolvedRequirement = try? await resolver.nextUnresolvedRequirement(of: navigationItem.originalDestination.requirements) else {
            if self[navigationItem].isBlocked {
                self[navigationItem].unblock()
                // If it's the placeholder it means we're on the root and no requirement needed to be resolved.
                // To get the view updated we reset the navigation path which triggers the unblocking
                if isPlaceholder {
                    navigationPath.removeAll()
                } else {
                    await navigateBack(to: navigationItem.id)
                }
            }

            currentUnresolvedRequirement = nil
            return
        }

        // Set actual unresolved requirement
        currentUnresolvedRequirement = unresolvedRequirement.identifier

        let reason: BlockingReason = isPlaceholder ? .navigation : .invalidation
        // Navigate back to before the navigation item in question (or to root)
        guard await navigateBack(to: .last(navigationItem.id).forced(), whenIn: .anyPath) != nil else { return }
        self[navigationItem].block(with: unresolvedRequirement.blockingDestination(reason: reason, onResolve: { [weak self] in
            Task { [weak self] in
                guard let self else { return }
                _ = await unresolvedRequirement.resolve(navigator: self)
            }
        }))
    }

    private func cleanUp(for viewID: ViewID) {
        cachedObjects.removeValue(forKey: viewID)
        requirementCancellables.removeValue(forKey: viewID)
    }
}

extension DefaultCoordinator {
    public func itemDidAppear() {
        appearContinuation?.resume()
        appearContinuation = nil
    }

    public func itemDidDisappear() {
        disappearContinuation?.resume()
        disappearContinuation = nil
    }

    private func itemDidCompleteAppearing() async {
        guard !disableLifecycleObservation else { return }
        await withCheckedContinuation {
            appearContinuation = $0
        }
    }

    private func itemDidCompleteDisappearing() async {
        guard !disableLifecycleObservation else { return }
        await withCheckedContinuation {
            disappearContinuation = $0
        }
    }
}

// MARK: - Deeplinks
extension DefaultCoordinator {
    @discardableResult
    public func handleDeeplink(url: URL) -> Bool {
        guard let destination = resolver.destinationForDeeplink(url: url) else {
            return false
        }

        guard let (destination, action) = resolver.resolveDestination(destination) else {
            return true
        }

        // if the preferred action is presenting we use that configuration otherwise we use the normal presentation
        let navigationAction = destination.preferredAction[appHorizontalSizeClass].isPresenting
            ? destination.preferredAction
            : .presenting

        navigate(to: destination.withAction(action), by: navigationAction)
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
