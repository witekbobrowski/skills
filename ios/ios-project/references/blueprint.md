# The blueprint

Generalized from `floda-ios` (June 2026). This is how Witek structures an iOS
app; the templates in `../templates/` are the executable form of this document.

## Layout

```
<AppName>/
├── <AppName>.xcworkspace/          # What you open. References Docs, the
│                                   #   package, and the project (in that order).
├── <AppName>.xcodeproj/            # App shell. Xcode 16 format (objectVersion
│                                   #   77), PBXFileSystemSynchronizedRootGroup —
│                                   #   folders on disk ARE the project structure,
│                                   #   so agents can add files without pbxproj edits.
├── <AppName>/                      # App target: entry point, RootView, Screens/,
│   │                               #   Dependencies/ (app-specific stores), Model/
│   ├── <AppName>.xctestplan        # Test plan: package tests + UI tests
│   └── Resources/Assets.xcassets   # AppIcon (single 1024 + dark/tinted), AccentColor
├── <AppName>Tests/                 # App-target unit tests (Swift Testing,
│                                   #   TEST_HOST = the app)
├── <AppName>UITests/               # XCTest UI automation — one launch smoke
│                                   #   test only
├── Scripts/                        # build.sh / test.sh / format.sh — the
│                                   #   canonical command surface for agents+CI
├── Config/                         # THE place for identity & capabilities:
│   ├── Shared.xcconfig             #   team, bundle id, versions, deployment
│   │                               #   target, device family, Swift 6 strict-
│   │                               #   concurrency pins, Info.plist keys,
│   │                               #   entitlements pointer
│   ├── Debug/Release.xcconfig      #   thin includes of Shared
│   ├── Tests.xcconfig              #   UI-test bundle settings
│   ├── UnitTests.xcconfig          #   app unit-test bundle settings
│   └── <AppName>.entitlements      #   declarative capabilities (starts empty)
├── Packages/Modules/               # ONE local SPM package, many targets:
│   ├── Sources/DesignSystem/       #   shared SwiftUI primitives, zero app logic
│   ├── Sources/Integrations/<X>/   #   one target per external system; only I/O
│   │                               #   and Sendable mirrors — app rules stay in
│   │                               #   the app target
│   └── Tests/<Target>Tests/        #   Swift Testing (@Test/#expect)
├── Docs/
│   ├── product/                    # vision.md (problem/thesis/pillars/non-goals/
│   │                               #   tone), design.md (design-source links)
│   ├── architecture/overview.md    # layers, state story, where logic runs
│   ├── engineering/                # commit-conventions.md (Conventional Commits)
│   └── adr/                        # Nygard-style ADRs, NNNN-title.md, 0001 ships
├── AGENTS.md                       # CANONICAL agent rules: commands, hard
│                                   #   rules, layout, docs reading order
├── CLAUDE.md                       # Thin Claude-specific layer over AGENTS.md
├── README.md                       # Human intro + AI-rules-files explainer
├── .claude/                        # settings.json (command allowlist) +
│                                   #   skills/verify project skill
├── .cursor/rules/ios-swift.mdc     # Cursor pointer to AGENTS.md (optional)
├── .github/copilot-instructions.md # Copilot pointer to AGENTS.md (optional)
├── .github/workflows/ci.yml        # format-check + build + non-UI tests
├── .swift-format                   # style is enforced, not prose
└── .gitignore
```

## Invariants (don't ask, don't change)

- **MV, not MVVM.** Views are state expressions; `@State`/`@Observable`/
  `@Environment`/`@Binding`; business logic in services.
- **Swift 6 language mode from day one**: `SWIFT_VERSION = 6.0`,
  `SWIFT_APPROACHABLE_CONCURRENCY = YES`,
  `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — all in `Shared.xcconfig`,
  never in the pbxproj, never lowered.
- **Swift Concurrency only**; MainActor default isolation covers UI.
- **Swift Testing** for unit tests (app `<AppName>Tests` bundle + package
  test targets); XCTest only for the UI-test bundle, which stays one launch
  smoke test asserting the `root-view` accessibility identifier.
- **swift-format owns style** (`.swift-format`, `Scripts/format.sh`); prose
  style rules were deleted on purpose — don't reintroduce them.
- **`AGENTS.md` is the canonical rules file**; `CLAUDE.md`, Cursor, and
  Copilot files are thin pointers. Update AGENTS.md, not four files.
- **Canonical commands in `Scripts/`** (`build.sh`, `test.sh [--skip-ui]`,
  `format.sh [--check]`); CI (`.github/workflows/ci.yml`) runs format-check +
  build + non-UI tests. `.claude/settings.json` pre-allows these commands.
- **Identity lives in xcconfig**, capabilities in the entitlements plist.
  Nobody edits buildSettings in the pbxproj for things xcconfig can own.
- **App-specific orchestration in the app target**, shared UI in
  `DesignSystem`, external-system I/O in `Integrations/<Name>`.
- **Conventional Commits**; decisions recorded as ADRs.
- The workspace file-refs order: `Docs`, `Packages/Modules`, project — keeps
  docs and package browsable in Xcode.

## Deliberate quirks worth knowing

- `SWIFT_VERSION` is deliberately absent from the pbxproj so
  `Shared.xcconfig` owns it (target-level pbxproj settings would override
  xcconfig). floda-ios itself started at Swift 5 language mode in the pbxproj;
  the blueprint fixed that for new apps.
- `Tests.xcconfig` (UI tests) reuses the app bundle id and fixes the
  duplicate-module problem via `PRODUCT_MODULE_NAME = $(PRODUCT_NAME)UITests`;
  `UnitTests.xcconfig` gives the unit bundle `<bundle-id>Tests` and
  `PRODUCT_NAME = $(TARGET_NAME)`.
- The app unit-test bundle (`<AppName>Tests`, hosted via `TEST_HOST`) exists
  so app-target stores are testable; if logic is hard to test there, move it
  into the package.
- `Resources/` also carries `PrivacyInfo.xcprivacy` (UserDefaults/CA92.1
  declared — effectively every app needs it) and `Localizable.xcstrings`.
- The template pbxproj keeps floda's original object IDs (`8B41F6…`). That is
  harmless — IDs only need to be unique within one project file.
- Xcode may add `<AppName>.xcworkspace/xcshareddata/swiftpm` state on first
  open; it's gitignored territory, leave it alone.

## Why workspace + local package

- Package targets build & test fast in isolation (`Modules-Package` scheme).
- Strict concurrency and API discipline are enforced at module boundaries.
- The app project stays a thin shell, so pbxproj churn (the classic merge
  nightmare) is near zero — synchronized groups + xcconfig do the rest.
