import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

struct IncludeMacro: DeclarationMacro {
    static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let destinationName = node.arguments.firstToken(viewMode: .all)?.text else { return [] }
        return [
            """
            @MainActor
            func callAsFunction(_ destination: \(raw: destinationName)) -> some View {
                view(for: destination)
            }
            """,
        ]
    }
}
