//
//  File.swift
//  
//
//  Created by Jonas Zell on 18.04.22.
//

import AST

struct StructField {
    /// The field name.
    let name: String
    
    /// The field type.
    let type: String
}

func getStructFields(_ structDecl: StructDeclaration) -> [StructField] {
    var fields = [StructField]()
    for memberDecl in structDecl.members {
        guard case .declaration(let decl) = memberDecl else {
            continue
        }
        
        let initializers: [PatternInitializer]
        
        if let variableDecl = decl as? VariableDeclaration {
            switch variableDecl.body {
            case .initializerList(let initializers_):
                initializers = initializers_
            case .codeBlock(_, _, _):
                continue
            case .getterSetterBlock(_, _, _):
                continue
            case .getterSetterKeywordBlock(_, _, _):
                continue
            case .willSetDidSetBlock(_, _, _, _):
                continue
            }
        }
        else if let constantDecl = decl as? ConstantDeclaration {
            initializers = constantDecl.initializerList
        }
        else {
            continue
        }
        
        guard let first = initializers.first else {
            continue
        }
        guard let identifier = first.pattern as? IdentifierPattern else {
            continue
        }
        
        let type: String
        if let annotation = identifier.typeAnnotation?.type.textDescription {
            type = annotation
        }
        else {
            type = "<unknown>"
        }
        
        fields.append(.init(name: identifier.identifier.textDescription, type: type))
    }
    
    return fields
}


func generateCodableConformance(_ structDecl: StructDeclaration) -> String {
    let fields = getStructFields(structDecl)
    let addPublic = structDecl.accessLevelModifier == .public
    let publicString = addPublic ? "public " : ""
    
    return """
extension \(structDecl.name.textDescription): Codable {
    enum CodingKeys: String, CodingKey {
        case \(fields.map { $0.name }.joined(separator: ", "))
    }
    
    \(publicString)func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        \(fields.map { "try container.encode(\($0.name), forKey: .\($0.name))" }.joined(separator: "\n        "))
    }
    
    \(publicString)init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            \(fields.map { "\($0.name): try container.decode(\($0.type).self, forKey: .\($0.name))" }.joined(separator: ",\n            "))
        )
    }
}
"""
}

func generateHashableConformance(_ structDecl: StructDeclaration,
                                 generateEquatable: Bool, generateHashable: Bool,
                                 generateStableHashable: Bool) -> String {
    let fields = getStructFields(structDecl)
    var equatable = "", hashable = "", stableHashable = ""
    let addPublic = structDecl.accessLevelModifier == .public
    let publicString = addPublic ? "public " : ""
    
    if generateEquatable || generateHashable || generateStableHashable {
        equatable = """
extension \(structDecl.name.textDescription): Equatable {
    \(publicString)static func ==(lhs: Self, rhs: Self) -> Bool {
        return (
            \(fields.map { "lhs.\($0.name) == rhs.\($0.name)" }.joined(separator: "\n            && ") )
        )
    }
}
"""
    }
    
    if generateHashable {
        hashable = """

extension \(structDecl.name.textDescription): Hashable {
    \(publicString)func hash(into hasher: inout Hasher) {
        \(fields.map { "hasher.combine(\($0.name))" }.joined(separator: "\n        "))
    }
}
"""
    }
    
    if generateStableHashable {
        stableHashable = """

extension \(structDecl.name.textDescription): StableHashable {
    \(publicString)var stableHash: Int {
        var hashValue = 0
        \(fields.map { "combineHashes(&hashValue, \($0.name).stableHash)" }.joined(separator: "\n        "))

        return hashValue
    }
}
"""
    }
    
    return """
\(equatable)
\(hashable)
\(stableHashable)
"""
}
