# 1. Record architecture decisions with ADRs

**Status:** Accepted  
**Date:** __TODAY__

## Context

__DISPLAY_NAME__ will span UI, integrations, and persistence concerns. Decisions made only in chat or pull requests are easy to lose; future contributors may repeat debates or unknowingly undermine earlier intent.

## Decision

We document **non-trivial** architectural and product-technical choices as **Architecture Decision Records** in `Docs/adr/`, using the lightweight structure described in `Docs/adr/README.md`.

## Consequences

- **Positive**: shared memory for “why”; easier onboarding; less rehashing of settled tradeoffs.
- **Positive**: ADRs can be superseded explicitly without deleting history.
- **Cost**: small ongoing discipline. When a choice materially affects structure or behavior, add or update an ADR instead of relying only on code comments.
