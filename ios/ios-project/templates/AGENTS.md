# APPNAME: agent notes

**This file is the canonical agent documentation for this repo.** Other rules
files (`CLAUDE.md`, `.cursor/rules/`, `.github/copilot-instructions.md`) defer
to it.

## Commands

Use the canonical scripts instead of hand-rolling xcodebuild invocations:

| Command | What it does |
|---|---|
| `Scripts/build.sh` | Debug build for iOS Simulator |
| `Scripts/test.sh` | Full test plan: package tests + app unit tests + UI smoke test |
| `Scripts/test.sh --skip-ui` | Same, minus the UI bundle (fast lane; what CI runs) |
| `Scripts/format.sh` | swift-format all sources in place (`--check` to lint only) |

Prefer XcodeBuildMCP tools when that MCP server is connected (simulator
install/launch, screenshots, UI automation). Open **`APPNAME.xcworkspace`**
in Xcode, scheme **APPNAME**. CI (`.github/workflows/ci.yml`) runs
format-check, build, and non-UI tests on every PR.

## Hard rules

- **Swift 6 language mode, strict concurrency.** `SWIFT_VERSION = 6.0`,
  `SWIFT_APPROACHABLE_CONCURRENCY = YES`, and
  `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` are set in
  `Config/Shared.xcconfig`. Never lower them; fix the code instead.
- **SwiftUI + Model-View.** No ViewModels/MVVM. Views are state expressions
  using `@State` / `@Observable` / `@Environment` / `@Binding`; business logic
  lives in services. Use `.task {}` for view-lifecycle async work, never
  `Task {}` in `onAppear`.
- **Swift Concurrency only.** No GCD, no completion handlers.
- **Swift Testing** (`@Test`, `#expect`, `#require`) for all unit tests.
  XCTest exists only in `APPNAMEUITests`, which stays a minimal smoke test.
- **Settings live in `Config/*.xcconfig`, capabilities in
  `Config/APPNAME.entitlements`.** Never edit the pbxproj for anything an
  xcconfig or the entitlements plist can own.
- **Style is enforced by swift-format** (`.swift-format`), not by prose.
  Run `Scripts/format.sh` before finishing a change.
- **Conventional Commits** (`Docs/engineering/commit-conventions.md`);
  significant decisions get an ADR (`Docs/adr/README.md`).

## Identity

- Bundle ID **`__BUNDLE_ID__`**, team **`__TEAM_ID__`** (both in
  `Config/Shared.xcconfig`).
- App unit tests: `__BUNDLE_ID__Tests` (`Config/UnitTests.xcconfig`);
  UI tests: `Config/Tests.xcconfig`.

## Layout: what goes where

- **`APPNAME/`** (app target): screens, app-specific stores/orchestration,
  dependency wiring in `APPNAMEApp.swift`. Keep it a thin shell.
- **`APPNAMETests/`**: Swift Testing unit tests for app-target code, hosted
  in the app. If logic is getting hard to test here, that's a sign it belongs
  in the package.
- **`Packages/Modules` → `Sources/DesignSystem`**: shared SwiftUI primitives.
  No app-specific business logic.
- **`Packages/Modules` → `Sources/Integrations/<Name>`**: one target per
  external system: only external I/O and `Sendable` mirrors. App rules stay
  in the app target. Tests in `Packages/Modules/Tests/<Name>Tests`.
- **`APPNAME/Resources/`**: asset catalog, `PrivacyInfo.xcprivacy` (update it
  when adopting required-reasons APIs or adding data collection),
  `Localizable.xcstrings` (string catalog, user-facing strings go here).
- The project uses Xcode 16 synchronized folder groups: **adding a file on
  disk adds it to the target**, no pbxproj edit needed.

## Documentation

Read before large changes in the matching area:

- [`Docs/product/vision.md`](Docs/product/vision.md): product north star and tone.
- [`Docs/architecture/overview.md`](Docs/architecture/overview.md): layers, state story.
- [`Docs/adr/`](Docs/adr/): decisions; add `NNNN-title.md` when you settle one.

## Device caveats

Some capabilities only work on a physical device (HealthKit background
delivery, push notifications). Simulator-only verification is incomplete for
those paths; say so when reporting results.
