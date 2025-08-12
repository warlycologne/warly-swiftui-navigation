import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct NavigateToMacro: DeclarationMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let destinationName = node.argumentList.firstToken(viewMode: .all)?.text else { return [] }
        return [
            """
            func navigate(to destination: \(raw: destinationName), by navigationAction: NavigationAction? = nil, reference: DestinationReference? = nil) {
                navigate(to: destination as any WarlyNavigation.Destination, by: navigationAction, reference: reference)
            }
            """
        ]
    }
}
