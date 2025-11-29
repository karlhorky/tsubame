# Testing Guide

## Why CI/CD?

Unit tests with CI/CD catch bugs early:

- **Without tests**: Code compiles → App runs → Bug discovered days later → Hard to find which change caused it
- **With tests**: Code pushed → CI runs → Immediate failure notification → Fix right away

For example, if someone accidentally breaks the window matching logic, the `test_firefox_distinguishesByTitle` test will fail immediately—even though the code compiles and the app launches normally.

## What We're Testing

Tsubame restores window positions when external displays reconnect. The challenge is identifying the correct window when multiple similar windows exist (e.g., multiple Firefox windows, multiple Terminal windows).

The matching logic uses this priority:

1. CGWindowID (exact match within session)
2. Title hash (e.g., "GitHub - Mozilla Firefox")
3. Window size (±20px tolerance)
4. App name only (fallback)

Tests verify this logic works correctly without launching the app.

## Running Tests

### Local (Xcode)

```
⌘U
```

### CI/CD (GitHub Actions)

Automatically triggered on push/PR to `main` branch.

Results: https://github.com/zembutsu/tsubame/actions

## Test Cases

| Test | Purpose |
|------|---------|
| `test_canRunTest` | Verify test infrastructure works |
| `test_canAccessMainCode` | Verify test target can access main code |
| `test_firefox_distinguishesByTitle` | Multiple windows distinguished by title |
| `test_terminal_distinguishesByPosition` | Same-title windows distinguished by position |

## Adding New Tests

Add to `TsubameTests/TsubameTests.swift`:

```swift
func test_newTestName() {
    // Arrange
    let saved = makeSavedInfo(appName: "AppName", title: "Title")
    let candidates = [...]
    
    // Act
    let result = matcher.findMatch(for: saved, in: candidates)
    
    // Assert
    XCTAssertEqual(result?.candidate.cgWindowID, expectedID)
}
```

## File Structure

```
TsubameTests/
└── TsubameTests.swift    # Test code

.github/workflows/
└── test.yml              # GitHub Actions config
```

## Troubleshooting

### Tests not found

- Verify method name starts with `test`
- Verify Target Membership includes `TsubameTests`

### CI/CD fails

- Verify Deployment Target is macOS 14.0 or lower
- Code signing is disabled for CI (configured in test.yml)
