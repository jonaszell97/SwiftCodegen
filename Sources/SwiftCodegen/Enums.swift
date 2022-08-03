//
//  File.swift
//  
//
//  Created by Jonas Zell on 18.04.22.
//

import AST

struct EnumCase {
    /// The name of the case.
    let name: String
    
    /// The associated case values.
    var values: [(label: String, type: String)]? = nil
}

extension EnumCase {
    var switchCase: String {
        guard let values = values else {
            return "case .\(name):"
        }
        
        return "case .\(name)(\(values.map { "let \($0.label)" }.joined(separator: ", "))):"
    }
    
    var types: String {
        self.values?.map { $0.type }.joined(separator: ", ") ?? ""
    }
    
    var valueLabels: String {
        self.values?.map { $0.label }.joined(separator: ", ") ?? ""
    }
    
    var valueLabelsWithColon: String {
        self.values?.map { "\($0.label): \($0.label)" }.joined(separator: ", ") ?? ""
    }
    
    var valueLabelsWithLet: String {
        self.values?.map { "let \($0.label)" }.joined(separator: ", ") ?? ""
    }
    
    var valueLabelsWithLetUnderscored: String {
        self.values?.map { "let \($0.label)_" }.joined(separator: ", ") ?? ""
    }
}

func getEnumCases(_ enumDecl: EnumDeclaration) -> [EnumCase] {
    var cases = [EnumCase]()
    var i = 0
    
    for memberDecl in enumDecl.members {
        switch memberDecl {
        case .declaration:
            break
        case .compilerControl:
            break
        case .union(let caseDecls):
            for caseDecl in caseDecls.cases {
                cases.append(.init(name: caseDecl.name.textDescription, values: caseDecl.tuple?.elements.map {
                    (label: $0.name?.textDescription ?? "v\(i)", type: $0.type.textDescription)
                }))
            }
        case .rawValue(let caseDecls):
            for caseDecl in caseDecls.cases {
                cases.append(.init(name: caseDecl.name.textDescription))
            }
        }
        
        i += 1
    }
    
    return cases
}

func generateCodableConformance(_ enumDecl: EnumDeclaration) -> String {
    let cases = getEnumCases(enumDecl)
    
    var codingKeys = ""
    for enumCase in cases {
        if !codingKeys.isEmpty {
            codingKeys += ", "
        }
        
        codingKeys += enumCase.name
    }
    
    var encoding = ""
    for enumCase in cases {
        if !encoding.isEmpty {
            encoding += "\n        "
        }
        
        encoding += "\(enumCase.switchCase)\n            "
        
        if let values = enumCase.values {
            if values.count == 1 {
                encoding += "try container.encode(\(values[0].label), forKey: .\(enumCase.name))"
            }
            else {
                encoding += "try container.encodeValues(\(enumCase.valueLabels), for: .\(enumCase.name))"
            }
        }
        else {
            encoding += "try container.encodeNil(forKey: .\(enumCase.name))"
        }
    }
    
    var decoding = ""
    for enumCase in cases {
        if !decoding.isEmpty {
            decoding += "\n        "
        }
        
        decoding += "case .\(enumCase.name):\n            "
        
        if let values = enumCase.values {
            if values.count == 1 {
                decoding += "let \(values[0].label) = try container.decode(\(values[0].type).self, forKey: .\(enumCase.name))\n            "
                decoding += "self = .\(enumCase.name)(\(values[0].label): \(values[0].label))"
            }
            else {
                decoding += "let (\(enumCase.valueLabels)): (\(enumCase.types)) = try container.decodeValues(for: .\(enumCase.name))\n            "
                decoding += "self = .\(enumCase.name)(\(enumCase.valueLabelsWithColon))"
            }
        }
        else {
            decoding += "_ = try container.decodeNil(forKey: .\(enumCase.name))\n            "
            decoding += "self = .\(enumCase.name)"
        }
    }
    
    return """
extension \(enumDecl.name.textDescription): Codable {
    enum CodingKeys: String, CodingKey {
        case \(codingKeys)
    }

    var codingKey: CodingKeys {
        switch self {
        \(cases.map { "case .\($0.name): return .\($0.name)" }.joined(separator: "\n        "))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        \(encoding)
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch container.allKeys.first {
        \(decoding)
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Unabled to decode enum."
                )
            )
        }
    }
}
"""
}


func generateHashableConformance(_ enumDecl: EnumDeclaration) -> String {
    let cases = getEnumCases(enumDecl)
    
    var hash = ""
    var stableHash = ""
    var equality = ""
    
    for enumCase in cases {
        guard let values = enumCase.values, !values.isEmpty else {
            continue
        }
        
        if !hash.isEmpty {
            hash += "\n        "
            stableHash += "\n        "
            equality += "\n        "
        }
        
        hash += "\(enumCase.switchCase)\n            "
        stableHash += "\(enumCase.switchCase)\n            "
        
        equality += "\(enumCase.switchCase)\n            "
        equality += "guard case .\(enumCase.name)(\(enumCase.valueLabelsWithLetUnderscored)) = rhs else { return false }\n            "
        
        var i = 0
        for value in values {
            if i != 0 {
                hash += "\n            "
                stableHash += "\n            "
                equality += "\n            "
            }
            
            hash += "hasher.combine(\(value.label))"
            stableHash += "combineHashes(&hashValue, \(value.label).stableHash)"
            equality += "guard \(value.label) == \(value.label)_ else { return false } "
            
            i += 1
        }
    }
    
    return """
extension \(enumDecl.name.textDescription): Hashable, StableHashable {
    static func ==(lhs: \(enumDecl.name), rhs: \(enumDecl.name)) -> Bool {
        guard lhs.codingKey == rhs.codingKey else {
            return false
        }

        switch lhs {
        \(equality)
        default:
            break
        }

        return true
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(self.codingKey.rawValue)
        switch self {
        \(hash)
        default:
            break
        }
    }

    var stableHash: Int {
        var hashValue = 0
        combineHashes(&hashValue, self.codingKey.rawValue.stableHash)
        
        switch self {
        \(stableHash)
        default:
            break
        }
        
        return hashValue
    }
}
"""
}
