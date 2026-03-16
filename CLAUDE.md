# Quick Input — Claude Code Instructions

A lightweight macOS menu bar app for quick-capturing notes to Notion with markdown support.

## Tech Stack

- **Language**: Swift 6.0 with strict concurrency (`SWIFT_STRICT_CONCURRENCY: complete`)
- **UI**: SwiftUI + AppKit (NSPanel, NSTextView, CGEventTap)
- **Persistence**: SwiftData (local), Notion API (remote sync)
- **Build**: XcodeGen (`project.yml` → `.xcodeproj`), no third-party dependencies
- **Deployment Target**: macOS 14.0+

## Build & Test

```bash
# Generate Xcode project (required after project.yml changes)
cd QuickInput && xcodegen generate

# Build
xcodebuild build -project QuickInput/QuickInput.xcodeproj -scheme QuickInput -configuration Debug

# Run tests
xcodebuild test -project QuickInput/QuickInput.xcodeproj -scheme QuickInputTests -configuration Debug

# Build DMG for distribution
./scripts/build-dmg.sh
```

## Architecture

- **Menu bar app** — `LSUIElement: true`, no Dock icon
- **Floating panel** — `NSPanel` at `.floating` level, triggered by global hotkey (CGEventTap)
- **Offline-first** — Notes stored locally via SwiftData, synced to Notion when online
- **Sync flow**: `pending → syncing → synced (deleted locally) | failed (retained for retry)`
- **Network monitoring** — `NWPathMonitor` triggers auto-retry on reconnect
- **Settings storage** — `UserDefaults` for Notion token, database ID, and hotkey binding

## Project Structure

```
QuickInput/
├── QuickInput/          # Main app source
│   ├── Models/          # SwiftData models (Note, HotkeyBinding)
│   ├── Views/           # SwiftUI views + AppKit wrappers
│   ├── Services/        # NotionService, NoteStore, GlobalHotkeyManager
│   └── Utilities/       # Markdown highlighting
├── QuickInputTests/     # Swift Testing (@Suite, @Test)
└── project.yml          # XcodeGen configuration
```

## Conventions

- All concurrency uses structured concurrency (`@MainActor`, `async/await`, `Sendable`)
- UI state management through `@Observable` classes
- AppKit integration via `NSViewRepresentable` / `NSViewControllerRepresentable`
- Testing uses Swift Testing framework (not XCTest)
- Icon assets generated via Python scripts in `scripts/`

## Key Constraints

- No third-party dependencies — use only Apple frameworks
- Accessibility permission required for global hotkey; must gracefully degrade without it
- Bundle ID: `me.xupeng.QuickInput`
