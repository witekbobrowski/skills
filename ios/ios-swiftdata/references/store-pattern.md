# The truth-store pattern

Generalized from floda-ios's `Store` package. `Workout` is the worked
example throughout — substitute the target app's entity. The pattern's two
load-bearing ideas, learned the hard way in Stoic:

1. **The flexible layer** — named projections make the struct layer bend
   (adding a shape is easier than bypassing the layer).
2. **The closed back door** — internal models make bypassing a *compile
   error*, not a policy.

Either alone fails: a rigid layer justifies bypassing, and an open back
door removes the pressure to fix the layer.

## Layout

The store is one SPM library target depending only on Foundation, SwiftData,
and (if hashing) CryptoKit — never on UI, never on provider SDKs
(HealthKit etc. stay behind mirror types at the app boundary).

```
Sources/Store/
  Models/            // public structs + typed enums
  Projections/       // Entity.Summary, Entity.Detail, fetch strategies
  Filters/           // EntityFilter, EntitySort, EntityCursor, Page
  Schema/            // internal @Model classes, SchemaV1, MigrationPlan,
                     // ModelConfigurations, StoreMetadataModel
  Mapping/           // init(model:) / apply(to:) per entity (internal)
  Store/             // Database (@ModelActor) + public protocols
  Series/            // packed codecs (pure value types, no SwiftData)  [if applicable]
  Fingerprint/       // dedupe (pure function + policy)                 [if applicable]
  Ingest/            // ProviderRecord, IngestOutcome, ingest pipeline  [if applicable]
Tests/StoreTests/    // mapping round-trips, codec property tests,
                     // fingerprint, filter compilation
```

App-target tests own the big fixture, orchestration against the public API,
and timing budgets; package tests own mechanics needing `@testable`.

## Public struct API

All public types are `Sendable` value types. Snapshot structs use
`public let` everywhere with a memberwise `public init` (for mapping and
tests) — mutation happens only through command types. Enums persisting as
raw strings are non-failable and decode unknown raw values to
`.unknown(raw)` — never crash, never drop (forward tolerance for rows
written by newer app versions):

```swift
public enum Provider: Hashable, Sendable, Codable {
    case appleHealth, strava, file
    case unknown(String)
    public var rawValue: String { … }          // .unknown(let raw): raw
    public init(rawValue: String) { … }        // default: .unknown(rawValue)
}
```

`.other` (a real classified case) and `.unknown(raw)` (this binary doesn't
know the value) are different things; only `.other` is ever produced by the
app's own mapping.

The truth entity struct carries:

- **Identity + sync fields**: `id: UUID`, `createdAt`, `updatedAt`,
  `revision: Int` (monotonic per-row edit counter), `deletedAt: Date?`
  (soft-delete tombstone). See `sync-readiness.md`.
- **Summary scalars in base units** (meters, seconds, kilocalories, bpm —
  whatever the domain's SI-ish bases are). Conversion only at the
  formatting edge.
- **Denormalized row flags** (e.g. `hasRoute`) so list queries never touch
  relationships.
- **Series descriptors, never payloads** — heavy blob `Data` is fetched on
  demand via the store, it never rides struct mapping.

## Internal models and mapping

The `@Model` classes are `internal`, suffixed `…Model`
(`Workout`/`WorkoutModel`), and never cross the package or actor boundary.
Making models public would make SwiftData public API (ends swappability),
scatter faulting discipline, and turn the schema into a compatibility
surface.

Mapping is symmetric — `init(model:)` / `apply(to:)` per entity — with
mechanical round-trip tests per entity (`struct → model → struct` equals
identity). Mapping cost rules:

- Structs map only in **windowed pages**, never the whole store (rollups
  exist for aggregates).
- Page-scale mapping loops never traverse relationships per element.

## The database actor never grows

One `@ModelActor` owns all store I/O. It stays a **thin executor**:
container, transaction, change-counter allocation, and a generic
`perform<T: Sendable>((Session) throws -> T)` primitive (`Session` =
context + counter allocator + log appender; the `Sendable` return keeps
models from escaping the actor). Domain operations live in internal
per-feature service files that write their own `FetchDescriptor`s and run
inside `perform`; consumers hold small Sendable facades
(`database.feed`, `database.ingesting`, …) backed by per-feature
protocols:

```swift
public typealias WorkoutStoring =
    WorkoutReading & WorkoutWriting & SeriesProviding
    & WorkoutIngesting & OperationLogging

@ModelActor
public final actor Database: WorkoutStoring {
    public static func make(directory: URL) throws -> Database { … }
}
```

Adding a feature = facade + service file + projection. `Database.swift` is
never edited.

## Reading: filters, cursors, pages

Custom query needs are served two ways, and only two:

1. **Parameterized domain specs** — a filter value compiled internally to
   a `FetchDescriptor` (predicate + sort + `fetchLimit` +
   `propertiesToFetch`).
2. **Named projections** added deliberately inside the package (below).

```swift
public struct WorkoutFilter: Hashable, Sendable {
    public var activityTypes: Set<ActivityType>?
    public var dateInterval: DateInterval?
    public var isUserModified: Bool?
    public var hasRoute: Bool?
    public var includesDeleted: Bool     // default false
    public init()                        // empty filter = everything live
}

public struct Page<Element: Sendable>: Sendable {
    public var items: [Element]
    public var nextCursor: WorkoutCursor?
}
```

Pagination is **keyset** (opaque cursor of the last row's sort key + id);
offset pagination is banned at scale. New sort orders land together with
their `#Index` — never without.

## Named projections and faulting rules

The store serves a small, curated, **closed** set of purpose-built shapes —
GraphQL-style flexibility without the open query surface. Every projection
is total for its type (no half-populated fields), has one documented
consumer surface, and its own optimized fetch path. Resist ad-hoc per-view
shapes: extend a projection or add one deliberately.

SwiftData faults like Core Data, so:

- Scalars materialize per object (cheap): a projection's shape and its
  `propertiesToFetch` list are the **same list** — no secondary faults.
- Every relationship access is its own fault — the N+1 trap. Page-scale
  projections (`Summary`) touch **no relationships** (denormalize what
  rows need, e.g. `hasRoute`); relationship-bearing projections (`Detail`)
  are single-object or use `relationshipKeyPathsForPrefetching`.

Typical set: `Entity.Summary` (list rows, `propertiesToFetch`-backed —
slim projections do *less* I/O than faulted classes), `Entity.Detail`
(single object composing stats, series descriptors, links, log slice),
plus internal-facing shapes (e.g. `FingerprintCandidate`).

## Mutations: resolve-then-apply

Commands in, structs out. The actor resolves id → model, verifies
`expectedRevision` (stale-write guard), applies, saves, bumps counters,
appends the matching log row — one transaction:

```swift
public struct WorkoutEdit: Hashable, Sendable {
    public var id: UUID
    public var expectedRevision: Int
    public var title: String??        // double-optional: .some(nil) clears
    public var notes: String??
    public var trigger: Trigger       // .user | .workflow(id) | .system
}
```

Commands keep `var` (they are builders). Field-clearing uses
double-optionals. Every mutation carries a `trigger` for the audit trail
("why did the app do that?" UX).

## Truth vs cache (when external sources apply)

Two `ModelConfiguration`s in one container:

- **Truth** — the durable, app-owned record of what happened.
  Self-sufficient: once a record is absorbed into truth, it survives cache
  purges and provider-history loss.
- **Local-only cache** — one generic `CachedProviderRecord` model
  (provider, externalID, revision token, mirror payload blob) that is
  **safe to wipe at any time**. `#Unique` on (provider, externalID) —
  one row per external record.

Cross-configuration references are **UUIDs, never relationships** —
SwiftData cannot relate across configurations, and that structural
constraint is the point. Rollups and sync anchors also live in the wipeable
configuration: losing an anchor costs one re-scan, never data.

The durable link entity (`ProviderLink`) lives on the truth side:
provider, externalID, raw provider type (kept here, not only in the cache,
so classification stays recomputable after a wipe), a **role**
(`imported`, `exported`, `splitFrom`, `mergedFrom`, `replacedBy`) and a
per-link sync state (`pending`/`inFlight`/`synced`/`skipped`/`error`/
`needsReview`). Direction lives in the role field, never in a type name —
providers are targets as well as sources. Several truth rows may share
one external record (user merge/split), which is why strict uniqueness
lives on the cache, not the links.

### Ingest algorithm (one transaction; order matters)

Providers feed one entry point: an app-boundary mapper turns the provider's
mirror type into a `ProviderRecord` (externalID, revision token, raw type,
stamped identity if present, mirror payload, and a candidate already in
base units). The store never imports provider SDKs.

1. **Echo check first — a model invariant, not a heuristic.** If the
   record carries our stamped identity, or an `exported` link exists for
   (provider, externalID), it is our own write echoing back → update link
   state, upsert cache, return `.echoSuppressed`. Fingerprinting never
   runs for stamped records.
2. **Known-record check.** An import-role link exists: revision unchanged →
   `.unchanged`; changed and not user-modified → apply candidate,
   `.updated`; changed and user-modified → link `state = .needsReview`,
   cache holds the proposal, `.routedToTriage` — no truth field moves.
3. **Fingerprint dedupe (unstamped only).** Normalized start/end, type,
   duration bucket, content hash → link to the existing truth row
   (`.linkedToExisting`); ambiguous (≥2 candidates) → create anyway with
   `needsReview` (honesty over silent merging).
4. **Create** — new truth row + series rows + `imported` link + cache
   upsert + log row.

**Echo suppression via identity stamping**: every write *to* a provider
stamps the truth row's identity (HealthKit
`HKMetadataKeySyncIdentifier`/`SyncVersion`; API-side idempotency keys)
and records the resulting externalID on the link *before* observer events
can fire. Fingerprinting is only the fallback for unstamped records.

**User manipulation is first-class**: a user-modification marker freezes
provider auto-apply (updates route to triage); edits are non-destructive
value operations on immutable payloads; retained source payloads make
revert-to-original a fresh ingest of the original. Replacement writes back to a
provider (propagating a split/merge) are delete+create with lineage,
user-confirmed only.

## Operation log (audit, not event sourcing)

Append-only immutable rows: timestamp, kind, optional subjectID +
relatedIDs as **plain UUIDs, no relationships** (history must survive
deletions), optional provider, `trigger`, small Codable detail, optional
`batchID`. Three scopes with field validity asserted in tests:
subject-scoped, provider-scoped (connect/disconnect, auth revoked, token
expired — the classic silent sync killer, logged and surfaced), and batch
summaries (appended exactly once at batch end; UI collapses by batchID).

Explicitly an **audit log, not event sourcing** — nothing ever derives
state from it. Live progress is store state, never log rows. Append-only
rows are conflict-free by construction, so the log can sync E2E later.

## Schema discipline

- `VersionedSchema` + `SchemaMigrationPlan` from the first release; every
  future change is a new schema version + a **lightweight** stage. Heavy
  transforms ride payload format versions (migrate-on-read,
  rewrite-on-write) so launch stays O(1).
- `cloudKitDatabase: .none` on every configuration — no automatic mirror,
  ever (see `sync-readiness.md`).
- Every query pattern ships with its `#Index`.
- Rare provider fields stay in the cache's mirror payload rather than
  becoming truth columns.

## App wiring (MV pattern)

`@Observable` stores in the app target hold struct pages and talk to the
facades; **no `@Query` and no models in app code**. File protection
`CompleteUntilFirstUserAuthentication` when background processing must
write while the device is locked (deliberate trade — record it).
