
import AST
import Parser
import Source

if CommandLine.arguments.count < 2 {
    fatalError("no input provided")
}

let codePath = CommandLine.arguments[1]
let sourceFile = try SourceReader.read(at: codePath)
let parser = Parser(source: sourceFile)
let topLevelDecl = try parser.parse()

for statement in topLevelDecl.statements {
    if let enumDecl = statement as? EnumDeclaration {
        print(generateCodableConformance(enumDecl))
        print(generateHashableConformance(enumDecl))
    }
    else if let structDecl = statement as? StructDeclaration {
        print(generateCodableConformance(structDecl))
        print(generateHashableConformance(structDecl))
    }
}
