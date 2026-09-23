# Architecture Decision Records (ADRs)

This folder holds **ADRs**: short, dated documents that capture a significant architectural or product-technical choice, **why** we picked a path, not only **what** the code does.

## Filename convention

Add new ADRs as:

`NNNN-short-title.md`

- `NNNN` is a zero-padded four-digit sequence (e.g. `0003-healthkit-observation.md`).
- Pick the **next free number** after the highest existing file in this directory so history stays monotonic.

## Suggested format (Nygard-style)

Each ADR is a small markdown file with:

1. **Title**: `NNNN` plus imperative summary (same as filename stem).
2. **Status**: e.g. Proposed, Accepted, Superseded by `NNNN-other.md`.
3. **Context**: forces at play: constraints, goals, unknowns.
4. **Decision**: what we will do (one clear statement).
5. **Consequences**: tradeoffs, follow-up work, and risks we accept.

Optional: **Alternatives considered** in a short list if future readers would otherwise re-litigate the same debate.

## Index

| ADR | Summary |
|-----|---------|
| [0001-record-architecture-decisions.md](0001-record-architecture-decisions.md) | Use ADRs for meaningful decisions. |
| [0002-local-first-storage.md](0002-local-first-storage.md) | Local store as v1 source of truth for workout map and sync state. |
| [0003-bidirectional-v1-health-strava.md](0003-bidirectional-v1-health-strava.md) | v1 includes bidirectional Apple Health ↔ Strava sync within platform/API limits; tradeoffs on complexity and conflict handling. |

Add new rows to the table when you add ADRs.
