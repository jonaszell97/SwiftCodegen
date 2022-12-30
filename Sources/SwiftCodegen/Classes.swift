
import AST

struct ClassField {
    /// The field name.
    let name: String
    
    /// The field type.
    let type: String
    
    /// The optional initializer expression.
    var initializerExpression: String?
}

func getClassFields(_ classDecl: ClassDeclaration) -> [ClassField] {
    var fields = [ClassField]()
    for memberDecl in classDecl.members {
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
        
        fields.append(.init(name: identifier.identifier.textDescription, type: type,
                            initializerExpression: initializers.first?.initializerExpression?.textDescription))
    }
    
    return fields
}

func generateMemberwiseInitializer(_ classDecl: ClassDeclaration) -> String {
    let fields = getClassFields(classDecl)
    let addPublic = classDecl.accessLevelModifier == .public
    let publicString = addPublic ? "public " : ""
    
    return """
/// Memberwise initializer.
\(publicString)init(\(fields.map { "\($0.name): \($0.type)\($0.initializerExpression != nil ? " = \($0.initializerExpression!)" : "")" }.joined(separator: ",\n            "))) {
    \(fields.map { "self.\($0.name) = \($0.name)" }.joined(separator: "\n    "))
}
"""
}

func generateCodableConformance(_ classDecl: ClassDeclaration) -> String {
    let fields = getClassFields(classDecl)
    let addPublic = classDecl.accessLevelModifier == .public
    let publicString = addPublic ? "public " : ""
    
    return """
extension \(classDecl.name.textDescription): Codable {
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

func generateHashableConformance(_ classDecl: ClassDeclaration,
                                 generateEquatable: Bool, generateHashable: Bool,
                                 generateStableHashable: Bool) -> String {
    let fields = getClassFields(classDecl)
    var equatable = "", hashable = "", stableHashable = ""
    let addPublic = classDecl.accessLevelModifier == .public
    let publicString = addPublic ? "public " : ""
    
    if generateEquatable || generateHashable || generateStableHashable {
        equatable = """
extension \(classDecl.name.textDescription): Equatable {
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

extension \(classDecl.name.textDescription): Hashable {
    \(publicString)func hash(into hasher: inout Hasher) {
        \(fields.map { "hasher.combine(\($0.name))" }.joined(separator: "\n        "))
    }
}
"""
    }
    
    if generateStableHashable {
        stableHashable = """

extension \(classDecl.name.textDescription): StableHashable {
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
