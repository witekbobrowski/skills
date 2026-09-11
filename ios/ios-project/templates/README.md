# __DISPLAY_NAME__ - iOS App

__ONE_LINE_PITCH__

A modern iOS application using a **workspace + SPM package** architecture for clean separation between app shell and feature code.

**Product and architecture documentation** lives under [`Docs/`](Docs/): start with [`Docs/product/vision.md`](Docs/product/vision.md); decisions are recorded in [`Docs/adr/`](Docs/adr/).

**Commit messages** follow Conventional Commits; see [`Docs/engineering/commit-conventions.md`](Docs/engineering/commit-conventions.md).

## AI Assistant Rules Files

This repo includes **opinionated rules files** for AI coding assistants:

- **Claude Code**: `CLAUDE.md`
- **Cursor**: `.cursor/rules/*.mdc`
- **GitHub Copilot**: `.github/copilot-instructions.md`

What makes them opinionated: no ViewModels (pure SwiftUI state management), Swift 6+ concurrency, Swift Testing over XCTest, @Observable over @Published.

**Note for AI assistants**: read the relevant rules files before making changes.

## Project Architecture

```
APPNAME/
├── APPNAME.xcworkspace/            # Open this file in Xcode
├── APPNAME.xcodeproj/              # App shell project
├── APPNAME/                        # App target (feature UI, stores, screens)
│   ├── Resources/Assets.xcassets/  # App-level assets (icon, accent color)
│   ├── APPNAMEApp.swift            # App entry point
│   ├── RootView.swift              # Root SwiftUI view
│   └── APPNAME.xctestplan          # Test configuration
├── Packages/Modules/               # Local Swift package (shared + integrations)
│   ├── Package.swift               # Products: DesignSystem, ...
│   ├── Sources/DesignSystem/       # Shared UI components
│   └── Tests/DesignSystemTests/    # Swift Testing tests
├── Config/                         # XCConfig build settings + entitlements
├── Docs/                           # Vision, architecture, ADRs, conventions
└── APPNAMEUITests/                 # UI automation tests
```

## Getting Started

1. Open `APPNAME.xcworkspace` in Xcode
2. Select the `APPNAME` scheme
3. Build and run (⌘R)

Identity (bundle ID, team, deployment target) lives in `Config/Shared.xcconfig`; capabilities in `Config/APPNAME.entitlements`.
