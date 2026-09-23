# APPNAME: Claude Code rules

**Read [`AGENTS.md`](AGENTS.md) first: it is the canonical agent
documentation** (commands, hard rules, layout, docs reading order). This file
only adds detail that Claude Code specifically needs. When the two disagree,
`AGENTS.md` wins; fix the discrepancy.

## Quick facts

- **iOS __DEPLOYMENT_TARGET__+**, Swift 6 language mode, strict concurrency,
  MainActor default isolation (all pinned in `Config/Shared.xcconfig`).
- **Architecture:** Model-View SwiftUI. No ViewModels. Workspace + local SPM
  package (`Packages/Modules`).
- **Canonical commands:** `Scripts/build.sh`, `Scripts/test.sh [--skip-ui]`,
  `Scripts/format.sh [--check]`. Style questions are settled by swift-format,
  not by prose or reviewer taste.

## State management (MV pattern)

```swift
@Observable
final class ItemStore {
    var items: [Item] = []
    func load() async throws { items = try await fetchItems() }
}

struct ItemListView: View {
    @Environment(ItemStore.self) private var store   // app-wide service
    @State private var selection: Item.ID?           // view-local state

    var body: some View {
        List(store.items, selection: $selection) { Text($0.name) }
            .task { try? await store.load() }         // lifecycle-bound async
    }
}
```

- App-wide services: inject with `.environment(_:)` from `APPNAMEApp`,
  consume via `@Environment(Type.self)`.
- Feature-local services: plain `let` properties of an `@Observable` type.
- Bindings into `@Observable` objects: `@Bindable`.
- View states: model as an `enum` (`.loading` / `.loaded` / `.error`).
- When a view grows: split into subviews and compose, never add a ViewModel.

## Concurrency

`MainActor` is the default isolation (Swift 6 approachable-concurrency
defaults), so UI code needs no annotations. Push heavy work into `actor`
types or `nonisolated` async functions in the package. `.task {}` /
`.task(id:)` for view-lifecycle async; structured concurrency everywhere;
never GCD.

## Testing

Swift Testing (`@Test`, `#expect`, `#require`, parameterized tests) in
`APPNAMETests` (app-target logic) and `Packages/Modules/Tests` (module
logic). The UI bundle is one launch smoke test; keep it that way. Test
services directly; verify views with previews and the running app, not
view-inspection tests.

## Changing the project

- New source files: create them on disk; synchronized folder groups
  pick them up. No pbxproj edits.
- Identity/build settings → `Config/*.xcconfig`. Capabilities →
  `Config/APPNAME.entitlements` (+ usage-description keys in
  `Shared.xcconfig`). The pbxproj is only touched to add whole targets.
- New shared/integration code → new target in `Packages/Modules/Package.swift`
  (pattern is commented in the manifest) + entry in the app's xctestplan.
- Persistence: prefer none; if needed, SwiftData (never CoreData),
  UserDefaults for simple preferences, and update
  `Resources/PrivacyInfo.xcprivacy` if new required-reasons APIs come in.

## Verification bar

Before declaring a change done: `Scripts/format.sh --check`,
`Scripts/build.sh`, and the relevant slice of `Scripts/test.sh` must pass.
Use XcodeBuildMCP (build/run/screenshot/describe_ui) to see UI
changes on a simulator instead of reasoning about them.
