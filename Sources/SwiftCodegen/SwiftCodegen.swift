
import ArgumentParser
import AST
import Parser
import Source

@main
struct SwiftCodegen: ParsableCommand {
    /// Either the file name or text contents.
    @Argument() var content: String
    
    /// Whether or not to parse the content directly.
    @Flag(name: .customShort("I")) var parseDirectly: Bool = false
    
    /// Whether to emit a Codable conformance.
    @Flag(name: .customLong("codable")) var emitCodableConformance: Bool = false
    
    /// Whether to emit a Hashable conformance.
    @Flag(name: .customLong("hashable")) var emitHashableConformance: Bool = false
    
    /// Whether to emit a StableHashable conformance.
    @Flag(name: .customLong("stable-hashable")) var emitStableHashableConformance: Bool = false
    
    /// Whether to emit an Equatable conformance.
    @Flag(name: .customLong("equatable")) var emitEquatableConformance: Bool = false
    
    mutating func run() throws {
        let sourceFile: SourceFile
        if parseDirectly {
            sourceFile = SourceFile(content: content)
        }
        else {
            do {
                sourceFile = try SourceReader.read(at: content)
            }
            catch {
                fatalError("could not parse source file: \(error.localizedDescription)")
            }
        }
        
        let parser = Parser(source: sourceFile)
        let topLevelDecl: TopLevelDeclaration
        
        do {
            topLevelDecl = try parser.parse()
        }
        catch {
            fatalError("could not parse source file: \(error.localizedDescription)")
        }
        
        for statement in topLevelDecl.statements {
            if let enumDecl = statement as? EnumDeclaration {
                if emitCodableConformance {
                    print(generateCodableConformance(enumDecl))
                }
                
                if emitEquatableConformance || emitHashableConformance || emitStableHashableConformance {
                    print(generateHashableConformance(enumDecl, generateEquatable: emitEquatableConformance,
                                                      generateHashable: emitHashableConformance,
                                                      generateStableHashable: emitStableHashableConformance))
                }
            }
            else if let structDecl = statement as? StructDeclaration {
                if emitCodableConformance {
                    print(generateCodableConformance(structDecl))
                }
                
                if emitEquatableConformance || emitHashableConformance || emitStableHashableConformance {
                    print(generateHashableConformance(structDecl, generateEquatable: emitEquatableConformance,
                                                      generateHashable: emitHashableConformance,
                                                      generateStableHashable: emitStableHashableConformance))
                }
            }
        }
    }
}
