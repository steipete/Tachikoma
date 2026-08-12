# Contributing

This repo is a SwiftPM package (Swift 6.x).

## Dev setup

```bash
git clone https://github.com/openclaw/Tachikoma.git
cd Tachikoma

swift build
TACHIKOMA_TEST_MODE=mock TACHIKOMA_DISABLE_API_TESTS=true swift test --parallel
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
            model: .openai(.gpt55),
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
TACHIKOMA_TEST_MODE=mock TACHIKOMA_DISABLE_API_TESTS=true swift test --parallel --enable-code-coverage
```

The repo also contains helper scripts under `scripts/` for more focused coverage reporting.
