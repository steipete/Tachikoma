# Contributing

This repo is a SwiftPM package (Swift 6.x).

## Dev setup

```bash
git clone https://github.com/steipete/Tachikoma.git
cd Tachikoma

swift build
swift test
```

## Writing tests

Tachikoma uses Swift Testing:

```swift
import Testing
@testable import Tachikoma

@Suite("My Feature Tests")
struct MyFeatureTests {
    @Test("Generates text")
    func generatesText() async throws {
        let result = try await generateText(
            model: .openai(.gpt4o),
            messages: [.user("Hello")]
        )
        #expect(!result.text.isEmpty)
    }
}
```

Notes:
- Networked provider E2E tests may be skipped in CI depending on secrets and environment.

## Coverage (optional)

Coverage isn’t a release gate; keep it in docs, not the README.

Example commands:

```bash
swift test --enable-code-coverage
```

The repo also contains helper scripts under `scripts/` for more focused coverage reporting.
