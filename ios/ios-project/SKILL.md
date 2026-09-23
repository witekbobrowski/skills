---
name: ios-project
description: Interactive wizard that scaffolds a new iOS app repository from Witek's personal blueprint (workspace + local SPM package, xcconfig-driven identity, MV SwiftUI, Docs/ADRs, AI rules files). Use when the user wants to start, create, bootstrap, or scaffold a new iOS app, project, or repo.
---

# iOS Project Wizard

Scaffold a new iOS app repo the way Witek builds apps. The blueprint is a
generalization of the `floda-ios` repo. Read `references/blueprint.md` for the
full layout and the rationale behind it before deviating from anything.

The flow: **interview → scaffold → personalize → verify → commit**. Do not
skip the interview and do not scaffold before the interview is complete: the
whole point of this skill is that the questions get asked.

## Companion skills (the iOS project suite)

This wizard scaffolds the repo shell; deeper concerns have their own
wizard skills that assume this blueprint's shape and run as follow-ups:

- **`ios-swiftdata`**: designs and scaffolds an app-owned SwiftData
  truth-store package (struct-first domain layer, internal `@Model` classes,
  thin `@ModelActor`, sync-ready fields). Run when persistence = SwiftData.
- **`ios-app-group`**: App Group adoption: entitlement wiring, the
  shared-defaults access point, store-file placement, late-adoption
  migration. Run when widgets/extensions are plausible or shared storage
  comes up; `references/capabilities.md` covers only the scaffold-time
  entitlement.

When a new cross-cutting concern gets extracted from `floda-ios` (the
blueprint's source), add it as a sibling skill and list it here.

## Phase 0: Preflight

1. Decide the destination directory. If the user invoked this inside an
   existing non-empty repo, ask where the new project should live (sibling
   directory named after the app, e.g. `~/Developer/<appname>-ios`, is the
   default convention).
2. Check `xcodebuild -version`: the blueprint needs Xcode 16+ (objectVersion
   77, synchronized folder groups). If missing or older, stop and say so.

## Phase 1: Interview

Run this as several short rounds, not one giant form. Ask the user one round
at a time, presenting enumerated options (use the harness's
structured-question tool if it has one) for enumerable choices; ask
open-ended items (names, pitch, links) as plain conversational questions.
Confirm the collected configuration back to the user at the end in one
compact table before scaffolding.

### Round 1: Identity (open questions)

- **App name**: product/target name. Must be UpperCamelCase letters/digits
  (it becomes target, scheme, folder, and type prefix). If the user gives a
  name with spaces, derive the identifier and confirm (e.g. "Trail Log" →
  `TrailLog`).
- **Display name**: human-facing name, spaces allowed. Default: app name.
- **One-line pitch**: one sentence for README and the vision doc.

### Round 2: Developer account

- **Team ID**: default `U82NM6NPZS` (Witek's personal team; bundle prefix
  `dev.bobrowski`). Offer: personal team (recommended) / other team ID /
  set up later (leaves `DEVELOPMENT_TEAM` empty; Xcode will prompt).
- **Bundle ID**: default `dev.bobrowski.<AppName>`. Confirm or take a custom
  reverse-DNS id.

### Round 3: Swift stack

- **Minimum deployment target**: `18.0` (blueprint default, broad reach) vs
  `26.0` (Liquid Glass and newest APIs without availability checks) vs custom.
- **Device family**: iPhone + iPad (`1,2`, default) vs iPhone only (`1`).
- **Persistence expectation**: none/in-memory (default), SwiftData, or
  UserDefaults-only. This does not change the scaffold. It is recorded in
  `Docs/architecture/overview.md` and, if SwiftData, noted as a planned ADR.
  If SwiftData: the **`ios-swiftdata`** skill designs and scaffolds the
  store package as a follow-up (its own interview + ADR); mention it here
  and offer it at wrap-up rather than designing persistence mid-scaffold.

Non-negotiables (state them, don't ask): Swift 6 language mode with strict
concurrency and MainActor default isolation, SwiftUI, MV pattern (no
ViewModels), Swift Concurrency only, Swift Testing for unit tests, swift-format
enforced style, workspace + local SPM `Packages/Modules` split.

### Round 4: Product inputs (mixed)

- **Does a product vision exist?** (yes: I'll provide it /
  no: draft it together / skip for now.)
  - *Provided*: take the text/file/URL and adapt it into
    `Docs/product/vision.md`, keeping the template's section structure
    (problem, thesis, pillars, non-goals, tone).
  - *Draft together*: ask 3–4 follow-ups (who is it for, what breaks today,
    what won't the app do) and write the vision from the answers.
  - *Skip*: leave the template with its placeholder comments.
- **Does a design source exist?**: a Claude design project, Figma file, or
  neither. If one exists, collect the link(s) and fill
  `Docs/product/design.md`; if Figma tooling is connected, offer to pull
  tokens into `DesignSystem` as a follow-up task. If neither, delete
  `Docs/product/design.md`.
- **Capabilities** (multiple answers allowed): HealthKit, CloudKit, Push
  notifications, App Groups, Keychain sharing, Background modes, none.
  Applied in Phase 3 via `references/capabilities.md`.

### Round 5: Repo & extras

- **Git**: init + first commit (default yes).
- **GitHub**: create a private repo with `gh` (default: ask; skip if `gh`
  is not authenticated). CI (`.github/workflows/ci.yml`) ships either way.
- **AI assistants** (multiSelect): Claude Code (always kept: `CLAUDE.md`,
  `.claude/`), Cursor (`.cursor/`), GitHub Copilot
  (`.github/copilot-instructions.md`). Delete the rules files for tools the
  user doesn't use. `AGENTS.md` is canonical and always stays.
- **Integration modules**: any known external systems to pre-create as empty
  `Sources/Integrations/<Name>` targets now (default: none; add when real).

## Phase 2: Scaffold (mechanical)

Run the bundled script. Do not hand-copy templates. `SKILL_DIR` below is
the directory containing this `SKILL.md` (it resolves through
`~/.claude/skills/` or `~/.agents/skills/`, whichever your harness uses):

```bash
"$SKILL_DIR/scripts/scaffold.sh" \
  --name <AppName> \
  --display-name "<Display Name>" \
  --bundle-id <bundle.id> \
  --team <TEAMID> \
  --target <18.0> \
  --device-family "1,2" \
  --pitch "<one-line pitch>" \
  --dest <destination>
```

It copies `templates/`, renames every `APPNAME` path, substitutes all tokens,
and refuses non-empty destinations. It prints any files with tokens left for
you to fill (normally only `Docs/product/design.md`).

## Phase 3: Personalize

Work in the scaffolded repo:

1. **Vision**: write `Docs/product/vision.md` per the Round 4 answer.
2. **Design**: fill or delete `Docs/product/design.md`.
3. **Capabilities**: for each selected capability, follow
   `references/capabilities.md`: entitlement keys into
   `Config/<AppName>.entitlements`, usage descriptions / `OTHER_LDFLAGS` into
   `Config/Shared.xcconfig`. Never touch the pbxproj for this.
4. **Integration modules**: for each requested integration, add a target +
   product + test target to `Packages/Modules/Package.swift` under
   `Sources/Integrations/<Name>` (pattern is commented in the manifest), a
   stub source file, and an entry in the app's xctestplan.
5. **Tailor the docs**: sweep `AGENTS.md` (canonical), `CLAUDE.md`, and
   `README.md` for anything that contradicts the interview answers
   (deployment target prose, persistence notes, capability caveats). Delete
   rules files for assistants the user doesn't use (Round 5). If the target
   is 26.0, note Liquid Glass / Icon Composer as available.
5b. **Privacy manifest**: `Resources/PrivacyInfo.xcprivacy` ships declaring
   UserDefaults (CA92.1). Extend it if chosen capabilities collect data or
   use other required-reasons APIs.
6. **ADR 0001** ships with today's date already substituted. If persistence or
   another interview answer settled a real decision, write `0002-*.md` now.

## Phase 4: Verify

All three must pass before committing; fix failures rather than reporting
them (run from the scaffolded repo root):

```bash
Scripts/format.sh --check   # swift-format lint
Scripts/build.sh            # Debug build for iOS Simulator
Scripts/test.sh             # full test plan: package + app unit + UI smoke
```

Prefer XcodeBuildMCP tools when that MCP server is connected.

## Phase 5: Commit & wrap up

1. `git init -b main`, add all, commit following
   `Docs/engineering/commit-conventions.md`:
   `chore: scaffold <AppName> from ios-project blueprint`.
2. If requested, `gh repo create <name> --private --source . --push`.
3. Summarize: the chosen configuration, what was verified, and the natural
   next steps (app icon into `AppIcon.appiconset`, first real screen replacing
   `RootView`'s placeholder, first integration module; if persistence =
   SwiftData, running the `ios-swiftdata` skill to design and scaffold
   the store package).

## Guardrails

- Never scaffold over a non-empty directory; the script enforces this. Do
  not work around it.
- Identity changes go in `Config/*.xcconfig`, capability changes in the
  entitlements file. The pbxproj is only edited to add targets, never for
  settings the xcconfig can own.
- If the user asks for MVVM, UIKit, CocoaPods, or XCTest-first testing,
  flag that it contradicts the blueprint and confirm before deviating.
