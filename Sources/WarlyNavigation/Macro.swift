
@freestanding(declaration, names: named(navigate(to:by:reference:)))
public macro NavigateTo(_: Destination.Type) = #externalMacro(module: "WarlyNavigationMacro", type: "NavigateToMacro")
