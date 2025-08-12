import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct WarlyNavigationMacro: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        NavigateToMacro.self,
    ]
}
