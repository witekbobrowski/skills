---
name: adr
description: Write an Architecture Decision Record into the repo's `Docs/adr/` (or `docs/adr/`) following its numbering and template. Use when the user decides something architectural, says 'record this decision', 'write an ADR', or asks what was decided.
allowed-tools: Bash(find:*), Bash(ls:*), Bash(cat:*), Bash(git:*), Read, Write, Glob, Grep
---

# ADR: Record an Architecture Decision

## Step 1: Locate the ADR directory

Check, in order: `Docs/adr/`, then `docs/adr/`. If neither exists, ask the
user before creating one. Don't assume the repo wants ADRs. If they confirm,
create `Docs/adr/` and use the shape at
the `ios-project` skill's `templates/Docs/adr/` as the starting point. Read
that template directory first: its `README.md` and `0001-*.md` show the exact
files to seed.

## Step 2: Match the repo's existing convention

If `README.md` exists in the ADR directory, read it: it usually states the
filename convention and section headings explicitly.

Then read the latest existing record (highest `NNNN` prefix) and match:

- **Numbering**: zero-padded four digits (`0001`, `0002`, ...). Pick the
  next free number after the highest one present.
- **Filename slug**: lowercase, hyphenated, imperative or noun-phrase
  summary matching the style already in use (e.g.
  `0004-adopt-cloudkit-sync.md`).
- **Section headings**: use whatever this repo's records actually use. If
  there's no prior record to copy, mirror
  the `ios-project` skill's `templates/Docs/adr/0001-record-architecture-decisions.md`
  exactly (Status, Context, Decision, Consequences).

## Step 3: Write the record

- **Title**: the ADR number plus an imperative or declarative summary,
  matching the filename stem.
- **Status**: starts `Accepted` unless the user says otherwise (e.g.
  `Proposed` if they're still deciding).
- **Context**: the forces at play: constraints, goals, unknowns. Keep it to
  what motivated the decision, not implementation detail.
- **Decision**: one clear statement of what was decided.
- **Consequences**: tradeoffs, follow-up work, risks accepted.

Stay at the level of the decision itself: how it gets built belongs in code,
comments, and PRs, not the ADR.

## Step 4: Handle supersession

If the user says this decision replaces an earlier one, update that older
ADR's status line to `Superseded by NNNN` (the new ADR's number) and nothing
else in that file. Don't touch its Context, Decision, or Consequences.

## Step 5: Update the index

If the ADR directory has an index file (commonly its `README.md`, listing
existing ADRs in a table), add a row linking the new file with a one-line
summary. Leave other rows untouched.

## Step 6: Report

Print the path of the file you wrote.
