---
name: ios-app-group
description: Sets up an App Group in an iOS app: entitlement wiring, a shared-defaults access point, store-file placement in the group container, and the migration path when adopting late. Use when the user wants to add an App Group, share data with a widget or extension, move UserDefaults or store files to a shared container, or asks where app data should live.
---

# App Group Wizard

Adopt an App Group the way Witek's apps do it: extracted from `floda-ios`
(2026-08-21: `AppGroup.swift`, the entitlements change, and the
preferences sweep). The governing idea:

> **Anything a future widget or extension might read lives in the group
> from first launch, so the migration never exists.** Moving a live SQLite
> file or scattered defaults between containers later is a failure-prone
> one-time migration; placing them right on day one deletes that work
> entirely. (Stoic precedent: its App Group store is what made
> share-extension writes possible.)

Adopt on day one whenever widgets/extensions are *plausible*, not only
when they're planned. The cost of adopting early is near zero; the cost of
adopting late is a migration.

## Companion skills

Part of the iOS project skill suite. `ios-project` applies the
entitlement at scaffold time when App Groups is a selected capability
(its `references/capabilities.md`); `ios-swiftdata` decides that store
files belong in the group container. This skill owns the wiring both of
them assume.

## Phase 1: Interview (short)

- **Identifier**: `group.<bundle-id>` by convention (floda:
  `group.dev.bobrowski.Floda`). iOS group IDs must start with `group.`.
  Confirm rather than invent.
- **What moves into the group**: usually both user-visible preferences
  (shared `UserDefaults`) and store files. Secrets do not: those are
  Keychain access groups, a separate capability.
- **Which targets**: today usually just the app; every future
  widget/extension target adds the same group to its own entitlements
  file.
- **Has the app shipped?**: decides the migration path in Phase 3.

## Phase 2: Wiring

1. **Entitlement**: in xcconfig-driven repos this goes in
   `Config/<App>.entitlements`, never the pbxproj:

   ```xml
   <key>com.apple.security.application-groups</key>
   <array><string>group.<bundle.id></string></array>
   ```

   With automatic signing, Xcode registers the group ID on the developer
   portal on next build. Extension targets repeat the key in their own
   entitlements file.

2. **One access point**: a small enum, not scattered
   `UserDefaults(suiteName:)` calls (floda:
   `Floda/Dependencies/AppGroup.swift`):

   ```swift
   /// The App Group shared by the app and future widgets/extensions.
   enum AppGroup {
       static let identifier = "group.<bundle.id>"

       /// `suiteName:` only returns nil for invalid names — a
       /// build-configuration error, not a runtime state.
       static let defaults: UserDefaults = {
           guard let defaults = UserDefaults(suiteName: identifier) else {
               preconditionFailure("App Group \(identifier) is misconfigured")
           }
           return defaults
       }()
   }
   ```

   `preconditionFailure`, not graceful fallback: silently falling back to
   `.standard` would fork user data into two containers.

3. **Sweep every consumer**: replace all `UserDefaults.standard` reads
   *and* writes with `AppGroup.defaults` in the same change; a partial
   sweep forks the data. Types that take defaults keep injecting them for
   testability (`init(defaults: UserDefaults = AppGroup.defaults)`), and
   `@AppStorage` needs the explicit store:
   `@AppStorage("key", store: AppGroup.defaults)`.

4. **Store files**: resolve the container and give the database factory
   a production entry point so call sites can't get the path wrong:

   ```swift
   let container = FileManager.default
       .containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier)!
       // nil here means the entitlement is missing/mismatched — crash loudly.
   let storeDirectory = container.appending(path: "Store/")
   ```

   Use a subdirectory (floda: `Store/`), not the container root; the OS
   also writes into the container. Keep **one store across build
   environments**: debug dogfood data carrying into a TestFlight install
   is a feature; environment isolation belongs in sync bookkeeping, not
   in truth (see ios-swiftdata's `references/sync-readiness.md`
   § Environments; partition per environment only if debug builds
   fabricate synthetic records into the real store). Expose
   `Database.make(appGroup:)` (or equivalent) as the production
   constructor; the plain `make(directory:)` stays for tests.

## Phase 3: Migration path

- **Not shipped yet (the good case):** no migration. Existing dev-device
  settings reset once; say so in the commit message (floda: "Pre-ship,
  existing device settings simply reset once.") and move on.
- **Already shipped:** one-time, crash-safe migration at launch, before
  anything opens the store:
  1. Defaults: if a `migratedToAppGroup` flag is unset in the group
     defaults, copy the known keys from `.standard`, then set the flag.
     Copy specific keys, never the whole dictionary (system keys ride
     along).
  2. Store files: if the old store exists and the new one does not,
     **move** (never copy-and-leave-both: two live copies is the worst
     outcome) the store and its `-wal`/`-shm` siblings together, before
     the first container open. A crash mid-migration must resolve on next
     launch by re-checking existence, not by a half-set flag.

## Gotchas

- `containerURL(...)` returning nil, or extensions seeing empty data:
  entitlement missing on that target, or identifier typo. It works in the
  simulator; on device the provisioning profile must carry the group.
- Shared defaults are shared *storage*, not a message bus: KVO/
  `didChangeNotification` does not fire across processes. Widgets reload
  via `WidgetCenter.shared.reloadTimelines`; real cross-process signaling
  is Darwin notifications.
- Two processes and one SwiftData/SQLite store: safe at the file level
  (WAL), but keep one writer: the app writes, extensions read (widgets
  best read pre-computed snapshots). Never assume an extension sees
  in-memory state.
- Extensions are separate bundles: each needs its own
  `PrivacyInfo.xcprivacy`; UserDefaults use (CA92.1) must be declared
  there too.
- File protection: background writes while the device is locked need
  `CompleteUntilFirstUserAuthentication` on the store files, a
  deliberate, documented trade.
- macOS App Groups use a team-ID prefix instead of `group.`. This skill
  is iOS-scoped; flag it if a Mac target appears.

## Verification

- Build + run; assert the wiring, don't eyeball it: a unit test that
  round-trips a value through `AppGroup.defaults` and (if store files
  moved) asserts the store directory resolves inside the group container.
- On the repo's scripts: `Scripts/build.sh` + the relevant slice of
  `Scripts/test.sh` (or equivalents) green before declaring done.
