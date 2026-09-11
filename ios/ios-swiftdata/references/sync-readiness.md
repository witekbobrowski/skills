# Sync readiness — day-one fields and CKSyncEngine lessons

Two sources: the floda ADR 0005 posture (local-first now, CKSyncEngine
later) and a deep read plus production war stories of Stoic's custom
Core Data + CloudKit engine (2019, ~2,950 lines). The engine code is gone;
the lessons are the asset.

## The posture

- **Local-first, unconstrained schema.** Use `#Unique`, `#Index`, and
  required relationships freely. Never shape the schema for CloudKit's
  automatic-mirror rules (no uniques, all-optional) — that tax buys an
  engine you don't control. `cloudKitDatabase: .none` everywhere.
- When sync ships it is built on **CKSyncEngine**: the engine owns
  scheduling, batching, retry, push, account transitions, change tokens.
  The app owns record⇄model mapping, conflict policy, durable change
  tracking, dedupe, forward compatibility, and — critically — **which
  fields sync at all**.
- **Backend-agnostic by construction**: the same day-one fields drive a
  future first-party backend without re-architecture.

## Day-one fields on every synced entity

Cheap now, unretrofittable later — ship them even if sync is "probably
never":

- Stable `UUID` identity.
- `createdAt` / `updatedAt`.
- Monotonic per-row `revision` (doubles as the stale-write guard).
- Soft-delete tombstone (`deletedAt`) — a durable deletion record; rows
  whose local copy is gone before the delete uploads are lost forever.
- Codable DTO parity (the public struct *is* the DTO).

## Store-wide change counter

`StoreMetadata.lastChangeCounter` allocated inside the single write actor:
increment and stamp mutated rows **in the same `context.save()`** — either
both commit or neither. Every mutation (insert, edit, tombstone, series
replacement, link change, log append) stamps a fresh counter; tombstoned
rows keep a fresh counter so deletions are visible. One indexed query
(`changeCounter > X`) then serves rollup maintenance today and the sync
adapter's pending-change source later.

## Store location

If widgets/extensions are ever plausible, both store files live in the
**App Group container from first launch**. Moving a live SQLite store
between containers later is a failure-prone migration; placing it right on
day one means that migration never exists.

## Per-field sync scoping

Assume sync scope is **per-field policy**, and don't preclude it: metadata
and user edits sync freely; regulated or provider-derived data may be
forbidden from leaving the device (App Store Guideline 2.5.1 bans HealthKit
data in iCloud — other domains have analogues). This is a first-class
reason automatic mirroring is unusable.

## Keep (proven in production)

1. Per-entity `FieldKey: String, CaseIterable` enums with symmetric
   `configure(record:)` / `update(with:)` and `desiredKeys` from
   `allCases` — translates almost verbatim to a CKSyncEngine delegate.
2. Archived CKRecord system fields stored per row, so rehydrated records
   carry valid change tags.
3. **Parked changes**: records/fields from newer app versions persist as
   opaque blobs and replay after update — never dropped. Apply field-level
   too: absent fields never erase local values.
4. Durable dirty-flag/pending-change table as the upload source of truth;
   event-driven push is only a latency optimization. Crash-recoverable by
   scan.
5. Assets out of the hot sync path (separate record type, lazy throttled
   fetch).
6. Post-merge structural dedupe driven by merge events, not timers
   (CloudKit record identity ≠ domain uniqueness across devices).
7. Exhaustive mechanical tests of the mapping layer.

## Never rebuild (bugs found in the old engine)

- **Token-before-apply**: persisting the change token before applying
  fetched changes silently loses data on failure. Report success only
  after the local save commits; CKSyncEngine re-delivers until handled.
- No durable deletion queue (tombstones from day one — see above).
- Whole-record client-wins clobber + LWW comparing server time to
  device-clock time (clock-skew sensitive). Write explicit per-field merge
  policy; never compare server time to device time.
- God-object engine with callback pyramids — the new adapter is an `actor`
  with structured concurrency.
- Unsynchronized shared mutable state; unbounded recursive retries;
  force-unwraps on inbound data (treat every inbound record as hostile —
  one foreign record can poison sync forever).
- A single shared context for UI and sync (full resyncs froze the app) —
  sync I/O gets its own `ModelActor` context and bounded batches.
- Runtime type discovery (`Bundle.main.classNamed`) — use a compile-time
  synced-type registry asserted in tests.
- Global (not per-account) sync bookkeeping — namespace by account, wipe on
  switch.
- **Testing only the easy layer**: mapping was tested; the
  conflict/retry/LWW policy — where every production incident lived — had
  zero tests. Invert: policy first, with synthesized engine events.

## Production war stories (operating it, not reading it)

- **Durability ≠ sync as products.** Sync was paywalled, so free users
  experienced device changes as *data loss*. Local durability and some
  restore/export path must exist for everyone; only multi-device sync is
  gateable.
- **Passive push-driven sync feels lossy** even when nothing is lost. Add
  demand-driven fetch hooks (foreground, screen-appear, pull-to-refresh —
  `fetchChanges()` supports it) and honest per-entity sync-state UI.
- **Data in iCloud is unprocessable** — no server-side compute; every
  migration is client-side, lazy, and eternal. So: every synced payload is
  self-describing and versioned; migrate-on-read, rewrite-on-next-edit;
  never design a change that needs bulk-rewriting CloudKit records.
- **`desiredKeys` has no inverse** — any heavy field on a hot record type
  is poisonous. Heavy payloads go in a separate record type / CKAsset
  referenced by ID.
- **Custom zone from the first record** — change tokens, atomic batches,
  and sharing all require it; the default zone is a trap.
- **Environments are un-testable by default** (Debug = sandbox, App Store =
  prod, no programmatic switch): declare a dev-only container in Debug
  entitlements, select the identifier at runtime; policy tests never touch
  a live container.
- **E2E encryption is effectively free** with this design:
  `CKRecord.encryptedValues` for every scalar/data field (references stay
  plain — they only leak graph shape; assets are E2E automatically).
  Encrypted fields' only real cost is server-side queries, which the
  zone-fetch design never uses. Caveat: recovery depends on the user's
  iCloud Keychain; local-first keeps the device copy primary.

## Account identity — the cross-account leak

An iCloud account switch is surfaced by CKSyncEngine (sign-in, sign-out,
switch). The naive handlings are both wrong for a local-first app:
auto-wiping local data treats truth as a cache (it isn't — the device copy
is primary), and carrying on syncing uploads the previous account's rows
into the new account's private database — a data leak. Policy:

- **Sync bookkeeping is per-account** (tokens, pending changes, anchors —
  see the never-rebuild list): namespaced by account, reset on switch.
- **The store stamps the account it first synced under** — one
  `syncedAccountID` in store metadata (from the engine's account event /
  `CKContainer` user identity), written on first successful sync. The
  slot is another day-one metadata field; the value only matters when
  sync ships.
- **Mismatch is a ceremony, never a default**: current account ≠ stamped
  account → sync pauses and the user chooses — keep this device's data
  local-only, adopt it into the new account (re-uploads everything,
  explicit consent), or clear it and pull the new account's data. Same
  spirit as the provider replacement ceremony: destructive or
  cross-boundary moves are user-confirmed only.
- Signed out / no account: local-first continues untouched; sync is
  simply idle. Nothing about durability may depend on an account
  existing.

## Environments — isolate sync state, not truth

CloudKit's environment follows provisioning (Xcode builds → development,
TestFlight/App Store → production), but the on-device data container is
the *same* across those installs — a TestFlight build lands on top of the
debug build's data. The hazard is precisely scoped: **truth is not
environment-specific** (a record ingested from a provider in a debug
build is the same real record a production build would ingest — dogfood
data carrying into a TestFlight install is a feature), but **sync state
is** — change tokens, pending-change queues, archived CKRecord system
fields, and the server-side records all belong to one environment, and
reusing them across environments corrupts sync. Default policy:

- **One truth store across build environments; sync bookkeeping scoped
  by (account, environment).** The bookkeeping already lives in the
  wipeable local configuration and is already namespaced per account —
  extending the key with a stamped environment is nearly free. An
  environment transition then looks like a fresh sync setup over full
  local data: the first production sync is an initial upload of local
  truth (correct — it was never there), and no dev change token or
  record metadata is ever replayed against production.
- **One `DeploymentEnvironment` value resolved at launch** (`#if DEBUG`
  ⇒ development, otherwise production; TestFlight uses production
  CloudKit; launch-argument override for tests) selects the bookkeeping
  scope *and* the CKContainer — debug builds talk to the dev-only
  container from the Debug entitlements (see war stories), so even an
  accidental debug upload never touches the production container.
- What makes this safe is **synthetic-data discipline**, not file
  isolation: fixtures and generated data live in tests (in-memory/temp
  stores) and the simulator (which never shares a store with a device).
  An on-device debug build holds real data worth keeping.
- **Escalations, in order of weight**, only if debug builds genuinely
  fabricate records into the real on-device store: partition the store
  files per environment (`Store/<environment>/` — full isolation, but
  dogfood data no longer carries across installs), or a separate Debug
  bundle ID (also forks provisioning, HealthKit grants, and App Group
  identity — rarely worth it).

## Adapter shape (when sync ships)

An `actor SyncAdapter` owning a dedicated `ModelActor` context. Durable
pending-change table + tombstones feed `nextRecordZoneChangeBatch` after
relaunch. Fetched batches apply transactionally per event. Per-field merge
on `.serverRecordChanged`, keyed by `FieldKey`. Parked-changes buffer for
unknown types/fields. Compile-time registry asserted in tests. Unit tests
target the policy layer with synthesized CKSyncEngine events — no live
container.
