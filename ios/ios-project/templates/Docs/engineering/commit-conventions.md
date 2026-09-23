# Commit conventions

This repository uses **[Conventional Commits](https://www.conventionalcommits.org/)** so history stays readable and tooling (changelog generators, release notes) can be added later.

## Format

```
<type>(<optional scope>): <short description>

[optional body]

[optional footer(s)]
```

- Use the **imperative mood** in the subject line (*add*, *fix*, not *added* / *fixes*).
- Keep the **subject around 72 characters** or less.
- **No period** at the end of the subject line unless it is real punctuation inside a phrase.

## Allowed types

| Type | When to use |
|------|----------------|
| `feat` | New user-visible behaviour or API (screen, sync rule type, export path). |
| `fix` | Bug fix or correction to existing behaviour. |
| `docs` | Documentation only (`Docs/`, `README`, comments that explain intent). |
| `style` | Formatting, whitespace, SwiftUI layout tweaks with no logic change. |
| `refactor` | Internal restructuring without changing behaviour. |
| `perf` | Performance improvements. |
| `test` | Adding or changing tests only. |
| `build` | Xcode project, SPM, schemes, CI scripts, dependencies. |
| `ci` | Continuous integration configuration. |
| `chore` | Maintenance that does not fit elsewhere (e.g. `.gitignore`, tooling). |
| `revert` | Reverts a previous commit (subject often references the reverted hash). |

## Scopes (optional, examples)

Use a scope in parentheses when it helps scan history:

- `feat(sync): …`: Health / Strava / bidirectional sync
- `feat(rules): …`: workflow or rule engine
- `feat(triage): …`: triage UI
- `feat(healthkit): …`: Apple Health integration
- `feat(strava): …`: Strava integration
- `docs(adr): …`: architecture decision records
- `build(spm): …`: `Packages/Modules` or local SPM

Omit the scope when the change is broad or obvious from the subject.

## Breaking changes

If a commit introduces a **breaking** API or data migration for contributors or users, add a footer:

```
BREAKING CHANGE: <what changed and what to do instead>
```

or start the type with an exclamation mark: `feat!: remove legacy export format`.

## Examples

```
feat(sync): queue Strava activities for triage when rules conflict
fix(healthkit): handle denied read authorization without crashing
docs: link vision from README
chore: refresh Xcode gitignore patterns
build(spm): add DesignSystem target to Modules package
```

## References

- [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/)
- [Angular commit message guidelines](https://github.com/angular/angular/blob/main/CONTRIBUTING.md#commit) (historical inspiration)
