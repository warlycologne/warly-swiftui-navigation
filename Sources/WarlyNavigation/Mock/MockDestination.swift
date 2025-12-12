public struct MockViewDestination: ViewDestination {
    public var identifier: String
    public var parameters: [String: Any]
    public var preferredAction: NavigationAction
    public var requirements: [RequirementIdentifier]

    public init(
        identifier: String = "mock",
        parameters: [String: Any] = [:],
        preferredAction: NavigationAction = .pushing,
        requirements: [RequirementIdentifier] = []
    ) {
        self.identifier = identifier
        self.parameters = parameters
        self.preferredAction = preferredAction
        self.requirements = requirements
    }
}
