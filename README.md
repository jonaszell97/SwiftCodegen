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

#

## Pastebot Integration

SwiftCodegen is especially useful when integrated with a clipboard manager like Pastebot, since you can just copy your code and paste the generated conformances automatically.

Pastebot can only execute scripts located in `/usr/bin` or `/bin`, but this restriction can be circumvented by running a local server that forwards commands to `SwiftCodegen`, which can then be reached using `curl` from your Pastebot filter.

A simple node server might look like this:

```javascript
const express = require('express')
const app = express()
const port = 8082
const bodyParser = require('body-parser');
const { exec } = require("child_process");
const tmp = require('tmp');
const fs = require('fs');

app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

app.post('/swift-codegen', (req, res) => {
    const text = req.body['text'];

    tmp.file(function (err, path, fd, cleanupCallback) {
        if (err) {
            console.log(`error: ${error}`);
            res.send(error);
            return;
        }

        fs.writeFileSync(path, text);

        exec(`/usr/local/bin/SwiftCodegen ${path} --hashable --codable`,
            (error, stdout, stderr) => {
            if (error) {
                console.log(`error: ${error.message}`);
                res.send(error.message);
                return;
            }
            if (stderr) {
                console.log(`stderr: ${stderr}`);
                res.send(stderr);
                return;
            }
            console.log(`stdout: ${stdout}`);
            res.send(stdout);
        });
    });    
})

app.listen(port, () => {
  console.log(`Pastebot Server listening on port ${port}`)
})
```

And the Pastebot filter communicating with the server:

```bash
# get the text from stdin
input=$(cat -)

# send request
curl -X POST --data-urlencode "text=${input}" localhost:8082/swift-codegen
```

Optionally, launchd can be configured to start this server automatically on startup.