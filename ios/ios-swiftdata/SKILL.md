---
name: ios-swiftdata
description: Wizard that designs and scaffolds a SwiftData truth-store package (the app-owned source of truth) following Witek's architecture (struct-first domain layer, internal @Model classes, thin ModelActor database, named projections, sync-ready fields, packed series blobs). Use when the user wants to add persistence, a local store, a data model, or SwiftData to an iOS app, or asks how to structure one.
---

# SwiftData Store Wizard

Design and scaffold an app-owned SwiftData truth store the way Witek
builds them.
The pattern is a generalization of the `Store` package in `floda-ios`
(built 2026), informed by production lessons from Stoic's custom
Core Data + CloudKit engine (2019). The three references carry the pattern;
read the relevant ones before writing any code, and read them fully before
deviating from anything:

- `references/store-pattern.md`: the core architecture: struct-first public
  API, internal `@Model` classes, thin `@ModelActor` database, mapping,
  filters, named projections, faulting rules, provider ingestion.
- `references/series-and-performance.md`: heavy time-series data as packed
  binary blobs; base units; the performance charter and fixture pattern.
- `references/sync-readiness.md`: day-one sync-friendly fields, the change
  counter, store location, and CKSyncEngine lessons for when sync ships.

If `~/Developer/floda-ios` is on disk, `Packages/Modules/Sources/Store/` and
`Docs/architecture/store-schema.md` there are the living exemplar; consult
them when a reference here is ambiguous.

The flow: **interview → design docs → scaffold → verify**. The design docs
come before code: the pattern's value is that decisions get recorded where
future agents will re-read them.

## Companion skills

Part of the iOS project skill suite. `ios-project` scaffolds the repo
shape this skill assumes (workspace + local SPM `Packages/Modules`, MV
SwiftUI, `Docs/adr`, `Scripts/*.sh`). Run it first for a brand-new app. This
skill still works in other layouts; adapt paths in Phase 0 rather than
refusing. `ios-app-group` owns App Group wiring (entitlement, shared
defaults, container paths) when the store lands in a group container.

## Phase 0: Preflight

Assumes the `ios-project` blueprint (Swift 6 strict concurrency, workspace
+ local SPM `Packages/Modules`, `Docs/adr`); see that skill's
`references/blueprint.md` when the repo deviates.

1. Confirm the repo shape: is there a `Packages/Modules` SPM package
   (blueprint layout) or another module structure? Where do ADRs and
   architecture docs live? If neither exists, propose creating
   `Docs/adr/` + `Docs/architecture/` and a package target.
2. Check the deployment target: SwiftData needs iOS 17+; `#Unique` /
   `#Index` need iOS 18+. The pattern assumes 18+; flag it if lower.
3. `@ModelActor` boundaries are load-bearing. If the repo is on Swift 5
   mode, warn that the actor-boundary guarantees weaken.

## Phase 1: Interview

Short rounds, not one form. Ask the user one round at a time, presenting
enumerated options (use the harness's structured-question tool if it has
one) for enumerable choices; open items (entity names, domain description)
conversationally. Confirm the collected configuration in one compact table
before writing anything.

### Round 1: Domain (open questions)

- **Primary entity (or entities)**: what is the app-owned record? (Floda:
  `Workout`.) Get the plain name; the pattern names the truth type plainly
  (`Workout`, never a prefixed variant). "Truth" is a role the docs
  describe, never part of a type name.
- **Scale envelope**: realistic row count over a decade-plus of heavy use.
  This number drives the performance charter (Floda: ~25k).

### Round 2: Data shape

- **Heavy per-entity data?** High-frequency samples, large payloads (GPS
  tracks, sensor streams, audio, long documents): yes / no. Yes → the
  series-blob pattern applies (separate 1→1 entity, packed versioned
  payloads, never row-per-sample).
- **External sources feeding the store?** Providers/imports (HealthKit,
  third-party APIs, file imports): yes / no. Yes → the truth-vs-cache split,
  provider links, fingerprint dedupe, and the ingest pipeline apply.
- **User edits over provider truth?** Can users modify records that a
  provider also updates: yes / no. Yes → user-modification freeze +
  triage routing + operation log apply.

### Round 3: Sync posture

- **Sync ambition**: never / probably later (recommended default) / planned
  (CloudKit) / own backend someday. Regardless of the answer, sync-friendly
  fields (UUID, timestamps, revision, tombstones, DTO parity) ship from day
  one: they are cheap now and unretrofittable later. The answer decides
  whether the change counter, App Group placement, and per-field sync
  scoping notes go into the ADR.
- **Extensions/widgets ever?** yes / no / unsure. Yes or unsure → store
  files go in an App Group container from first launch (moving a live
  SQLite file later is a failure-prone migration). The entitlement, the
  shared-defaults access point, and the `make(appGroup:)` factory wiring
  are owned by the companion `ios-app-group` skill; run it alongside
  the scaffold.

### Round 4: Naming and placement

- **Module name**: default `Store`, as a sibling target in
  `Packages/Modules`. Confirm or adapt to the repo's structure.

Non-negotiables (state them, don't ask): SwiftData, never Core Data
directly; local-first unconstrained schema (`#Unique`/`#Index` used freely,
no CloudKit automatic mirror; CKSyncEngine later if sync ships); `@Model`
classes internal to the package; `VersionedSchema` + `MigrationPlan` from
the first release; all scalars stored in base units.

## Phase 2: Design docs before code

Write these into the target repo, scaled to the interview answers:

1. **ADR** (`Docs/adr/000X-swiftdata-truth-store.md`): the stack
   decision, mirroring floda's ADR 0005: SwiftData, local-first
   unconstrained schema, sync posture, truth-vs-cache split. Record
   what was *decided against* (Core Data, automatic CloudKit mirror) and
   why.
2. **Data model doc** (`Docs/architecture/data-model.md`): entities,
   which pattern components apply (from the interview), naming, base
   units, the performance envelope.

Component applicability, driven by the interview:

| Component | When |
|---|---|
| Struct-first API, internal `…Model` classes, mapping + round-trip tests, thin `@ModelActor`, filters, named projections, `VersionedSchema` | Always |
| Sync-friendly fields (UUID, createdAt/updatedAt, revision, tombstones, Codable DTO parity) | Always |
| Store-wide change counter | Sync "probably later" or better; also whenever rollups/derived data need "what changed since X" |
| Truth-vs-cache split, `ProviderLink`, fingerprint dedupe, ingest pipeline, echo suppression | External sources = yes |
| Operation log (audit, not event sourcing) | External sources or user-edits = yes |
| Series-blob entity + packed codecs + property tests | Heavy per-entity data = yes |
| User-modification freeze + triage | User edits over provider truth = yes |
| App Group placement | Extensions = yes or unsure |
| Performance fixture + timing budgets | Scale envelope ≥ ~10k rows |

## Phase 3: Scaffold

There are no file templates: the code is domain-specific. Generate it from
the references, substituting the interview's entity names for `Workout`.
Implementation order (each step compiles and its tests pass before the
next):

1. **Package target**: add the library + test target to `Package.swift`;
   create the source layout from `references/store-pattern.md` § Layout.
2. **Public structs + enums**: Sendable value types; string-raw enums
   decode unknown values to `.unknown(raw)`, never crash.
3. **Internal `@Model` classes** (`…Model` suffix) + `VersionedSchema` V1 +
   empty `MigrationPlan` + configurations/container factory.
4. **Mapping**: symmetric `init(model:)` / `apply(to:)` per entity, with
   mechanical round-trip tests written *with* the mapping, not after.
5. **Database actor**: thin executor + the protocols and facades the app
   consumes; resolve-then-apply mutations.
6. **Projections + filters**: `Summary`/`Detail` shapes with their fetch
   paths and `propertiesToFetch`.
7. If applicable: **series codecs** (with property tests), **ingest
   pipeline**, **operation log**, **fixture + timing budgets**.

Wire-up in the app target follows the repo's MV pattern: `@Observable`
stores hold struct pages; no `@Query` and no models in app code.

## Phase 4: Verify

- Run the repo's standard scripts (`Scripts/build.sh`, `Scripts/test.sh`
  or equivalents). All green before declaring done.
- The load-bearing code is the mapping, codecs, and
  fingerprint/ingest logic: tested first, not last.
- If the performance fixture applies, budgets are asserted tests, not
  documentation.

## Guardrails

- `@Model` classes are never public and never cross the package or actor
  boundary; no exceptions for feature code. Custom query needs are served
  by parameterized filters or a new named projection *inside* the package.
- Never row-per-sample entities for high-frequency data.
- Never CloudKit automatic mirroring (it taxes the schema: no uniques,
  all-optional). If the user asks for it, flag the conflict with the
  unconstrained-schema decision and confirm before deviating.
- The database actor never grows: new features add a facade + service file
  + projection, never methods on the actor's core.
- Storage is base units only; conversion lives at the formatting edge.
- With any sync ambition: truth is one store across build environments,
  but sync bookkeeping is scoped by (account, environment): one value
  resolved at launch that later also selects the CKContainer, so dev
  change tokens never replay against production; and the store metadata
  reserves an account-identity stamp so an iCloud account switch is a
  user ceremony, never a silent cross-account upload or wipe
  (`references/sync-readiness.md` §§ Account identity, Environments).
- Every schema change from release one goes through a new `VersionedSchema`
  + lightweight migration stage; heavy transforms ride payload format
  versions (migrate-on-read), keeping launch O(1).
