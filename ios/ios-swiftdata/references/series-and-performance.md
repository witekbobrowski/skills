# Heavy series data and the performance charter

Applies when the domain has high-frequency per-entity data (GPS tracks,
sensor streams, samples). The floda numbers are kept as sanity anchors —
recompute them for the target domain.

## The series-blob pattern

Never row-per-sample entities. Queryable **summary scalars live as columns**
on the truth entity; full time series live as **versioned packed-binary
blobs** with `@Attribute(.externalStorage)` on a **separate 1→1 entity** —
hot rows stay narrow, and list queries never fault blob data.

Shape: one series row per (entity, channel):

```swift
public enum SeriesChannel: Hashable, Sendable, Codable {
    case route, heartRate, segments
    case unknown(String)   // future channels need no migration
}

public struct WorkoutSeries: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    public let workoutID: UUID
    public let channel: SeriesChannel
    public let formatVersion: Int    // leading format byte of the payload
    public let sampleCount: Int
    public let contentHash: Data     // SHA-256 truncated to 16 bytes
    public let byteCount: Int
    public let updatedAt: Date
}
```

- **Channel is a string** — new channels (power, cadence, …) need no schema
  migration; loading one channel never faults another.
- **Payloads are immutable values** — replaced wholesale, never patched.
  Any edit is decode → transform → re-encode (new contentHash, bumped
  updatedAt and change counter). `contentHash` gives cheap change detection
  and a fingerprint input.
- Structs carry **descriptors only**; payload `Data` crosses the actor
  boundary raw and is decoded by pure value codecs *off* the actor — blobs
  never ride struct mapping.

## Packed binary conventions (v1)

- **Header (6 bytes)**: byte 0 `formatVersion` (u8), byte 1 `flags`
  (channel-specific), bytes 2–5 `sampleCount` (u32 LE).
- **Varints**: unsigned LEB128; signed values ZigZag-then-LEB128. Reject
  over-wide final bytes when decoding.
- **Time**: offsets from the entity's start in milliseconds; first sample
  absolute, subsequent samples delta to the previous. **One time encoding
  across all channels** — split/merge rebases every channel (and structural
  segments) with the same code path.
- **Values**: delta-encoded on a per-channel quantization grid chosen below
  measurement accuracy (floda: 1e-7° for lat/lon ≈ 1.1 cm, 0.1 m altitude,
  0.1 bpm, 0.01 m/s) — practically lossless, ~4× smaller than naive
  Float64 tuples.
- **Presence flags are all-or-nothing per field**: set only when every
  sample carries the field; mixed presence drops that field.
- **Tolerance**: decoders tolerate trailing unknown bytes (minor extensions
  ride flags); unknown `formatVersion` → payload preserved untouched and
  surfaced as undecodable — never dropped, never crashes. Unknown enum
  kinds inside payloads survive a decode→encode cycle.
- Map provider sentinel values (e.g. CLLocation's negative "invalid"
  accuracies) to nil *before* encoding.
- **Self-sufficiency test for field selection**: if a field is not
  re-derivable and the source cache is wipeable, it belongs in truth —
  drop nothing you cannot recompute (floda learned this with GPS
  accuracy/speed/course).

Structural segments (laps, intervals, pauses, markers, multisport legs)
are just another channel — packed `{kind, startOffset, duration, label?,
legType?}` entries sharing the offset encoding. Pause entries ground
moving-time duration (`moving = elapsed − Σ pause`); a multisport session
is one truth entity with typed leg segments.

## Codec API and property tests

Codecs are pure `nonisolated` value types with no SwiftData dependency:

```swift
public struct RoutePayload: Hashable, Sendable {
    public var samples: [RouteSample]
    public init(samples: [RouteSample])
    public init(decoding data: Data) throws   // any known formatVersion
    public func encoded() -> Data             // always current version
}
```

Property tests (seeded generators) are non-negotiable, formats are
versioned from v1:

- **Quantization law**: `decode(encode(x)) == quantize(x)` (snap to the
  channel grid).
- **Idempotence**: `encode(decode(d)) == d` for encoder-produced `d`.
- **Rebase law**: split at offset `t` then re-encode preserves every
  sample/segment shifted by exactly `t`; merge is its inverse.
- **Tolerance**: unknown kinds and trailing bytes survive round-trips;
  corrupt headers throw, never crash.
- If file interop matters (FIT/GPX): fix quantization grids *now* so
  truth → file → truth round-trips are provable later; file codecs
  live in their own module of pure value types, and files are just another
  provider (externalID = content hash → re-import dedupe for free).

## Base units

All stored scalars in fixed base units (meters, seconds, kilocalories,
bpm — pick the domain's set once). Conversion happens only in the
formatting layer, never in storage. This is what makes fingerprints,
rollups, and cross-provider comparison trivial.

## Performance charter

Write it down with the target envelope (floda: ~25k entities = 2/day ×
30+ years). Row count is never the threat; these invariants are:

1. **Hot rows stay narrow** — blobs on the separate series entity; list
   queries never fault blob bytes.
2. **Entities scale O(records), never O(samples)** — features add summary
   columns, blob channels, or derived entities; never sample tables.
3. **Rollups, not scans** — stats read incrementally-maintained rollup
   entities (period × type), updated on ingest/edit via the change
   counter, rebuildable offline, living in the wipeable configuration. No
   feature scans full history on demand.
4. **Migrations are O(1) at launch** — lightweight-only; heavy transforms
   ride the blob format byte.
5. **Every query pattern ships with its `#Index`**; UI reads are windowed,
   never whole-store arrays.
6. **The guarantee is a fixture** — a deterministic (seeded) synthetic
   generator at the envelope size, built through the *public ingest API*
   (so it doubles as a soak test), written once per test process and
   reused. Timing budgets are named tests (feed first page, cold open,
   detail fetch, series decode, rollup read, changes-since, single
   ingest), asserted at ~2× the local median for CI headroom. A red budget
   is a design regression, not a flaky test.
