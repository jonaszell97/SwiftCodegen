# SwiftCodegen

This tool can be used for automatic code generation in Swift projects. Currently, the following types of code snippets are supported:

- **Hashable** conformance for Enums and Structs
- **Equatable** conformance for Enums and Structs
- **Codable** conformance for Enums and Structs


## Usage

SwiftCodegen can be used via the command line with the following options:

- `-I`: If this flag is set, the input code is read from stdin instead of reading from a file. Otherwise, you have to pass a path to a file containing your code
- `--codable`: If present, a Codable conformance is generated for your struct or enum
- `--equatable`: If present, an Equatable conformance is generated for your struct or enum
- `--hashable`: If present, both an Equatable and a Hashable conformance are generated for your struct or enum

## Example

The following example shows the format of the input and output of SwiftCodegen.

```swift
// Input code (example.swift)
enum MyEnum {
    case first(value: Int)
    case second(value: String)
    case third
}
```

```bash
# Command line invocation
SwiftCodegen example.swift --codable --hashable
```

```swift
// Generated output code
extension MyEnum: Codable {
    enum CodingKeys: String, CodingKey {
        case first, second, third
    }

    var codingKey: CodingKeys {
        switch self {
        case .first: return .first
        case .second: return .second
        case .third: return .third
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .first(let value):
            try container.encode(value, forKey: .first)
        case .second(let value):
            try container.encode(value, forKey: .second)
        case .third:
            try container.encodeNil(forKey: .third)
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch container.allKeys.first {
        case .first:
            let value = try container.decode(Int.self, forKey: .first)
            self = .first(value: value)
        case .second:
            let value = try container.decode(String.self, forKey: .second)
            self = .second(value: value)
        case .third:
            _ = try container.decodeNil(forKey: .third)
            self = .third
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

extension MyEnum: Equatable {
    static func ==(lhs: MyEnum, rhs: MyEnum) -> Bool {
        guard lhs.codingKey == rhs.codingKey else {
            return false
        }

        switch lhs {
        case .first(let value):
            guard case .first(let value_) = rhs else { return false }
            guard value == value_ else { return false } 
        case .second(let value):
            guard case .second(let value_) = rhs else { return false }
            guard value == value_ else { return false } 
        default:
            break
        }

        return true
    }
}

extension MyEnum: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.codingKey.rawValue)
        switch self {
        case .first(let value):
            hasher.combine(value)
        case .second(let value):
            hasher.combine(value)
        default:
            break
        }
    }
}
```