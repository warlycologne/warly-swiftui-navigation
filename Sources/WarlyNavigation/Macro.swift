@freestanding(declaration, names: named(navigate(to:by:completion:)))
public macro NavigateTo(_: Destination.Type) = #externalMacro(module: "WarlyNavigationMacro", type: "NavigateToMacro")

@freestanding(declaration, names: named(callAsFunction(_:)))
public macro Include(_: IncludeDestination.Type) = #externalMacro(module: "WarlyNavigationMacro", type: "IncludeMacro")
