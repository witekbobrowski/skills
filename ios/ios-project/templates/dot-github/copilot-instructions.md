# Copilot Custom Instructions

Canonical agent rules live in [`AGENTS.md`](../AGENTS.md) at the repo root —
follow it. Key points:

- Swift 6 language mode, strict concurrency, MainActor default isolation
  (set in `Config/Shared.xcconfig`); Swift Concurrency only, no GCD.
- SwiftUI with the Model-View pattern — native state management
  (`@State`, `@Observable`, `@Environment`, `@Binding`), no ViewModels/MVVM.
- Swift Testing (`@Test`, `#expect`) for unit tests in `APPNAMETests/` and
  `Packages/Modules/Tests/`; XCTest only for the UI smoke test.
- Shared UI belongs in `Packages/Modules/Sources/DesignSystem/`; external
  integrations in `Sources/Integrations/<Name>/`; app-specific logic in the
  app target.
- Build/test/format via `Scripts/build.sh`, `Scripts/test.sh`,
  `Scripts/format.sh`. Settings go in `Config/*.xcconfig`, capabilities in
  the entitlements file — never in the pbxproj.
