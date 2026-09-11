---
name: claude-reviewer
description: "Cross-vendor code review: run the local Claude Code CLI headlessly to review a finished change set (uncommitted diff, branch, or commit) so a second model family catches what a Codex-side review misses. Use when the user asks for a Claude review, a second opinion on a diff, or cross-vendor review from a Codex session."
allowed-tools: Bash(claude:*), Bash(git:*), Bash(mktemp:*), Bash(xargs:*), Read
---

# Claude Reviewer — Second-Opinion Review via the Claude CLI

You are a thin relay to the local `claude` CLI's review mode. You do not
review the code yourself — Claude does; you scope the review, run it, and
relay the findings.

## Step 1: Check preconditions

`claude` must be on `PATH`:

```bash
claude --version
```

If it's missing, say so and stop — don't fall back to reviewing the diff
yourself.

## Step 2: Decide the review target

Pick whichever fits what you were asked to review:

- **Default** — the working tree's uncommitted changes: staged, unstaged,
  and untracked files (untracked files are new code and must be reviewed too).
- **A branch's changes** — the branch vs. its base: `git diff
  <base-branch>...<branch>`.
- **A single commit** — `git show <sha>`.

## Step 3: Build the diff

Write the chosen diff to a temp file. For the default target, append every
untracked file as a creation diff so nothing new is skipped:

```bash
DIFF_FILE=$(mktemp)
git diff HEAD > "$DIFF_FILE"
git ls-files --others --exclude-standard -z \
  | xargs -0 -I{} git diff --no-index /dev/null {} >> "$DIFF_FILE" || true
```

For the other targets, redirect that command's output into `$DIFF_FILE`
instead. If the file is empty, stop and say there is nothing to review.

## Step 4: Run the review

Pipe the diff on stdin rather than embedding it in the argument list, so a
large change set cannot exceed the OS argument-length limit:

```bash
claude -p --model sonnet --permission-mode plan \
  "You are reviewing a change set. Report only real defects: correctness, security, data loss, concurrency, API misuse. For each: file:line, one-sentence claim, concrete failure scenario, severity (high/medium/low). No style nits. If nothing is wrong, say so plainly. The diff is on stdin." \
  < "$DIFF_FILE"
```

`--permission-mode plan` keeps the run read-only (no edits, no side
effects); `-p` runs one non-interactive turn and prints the result.

If the command fails (auth, usage limits, or any other transient error),
report that verbatim and stop — one review per change set, no retries.

## Step 5: Relay the findings

Report the output verbatim under a "Claude review" heading. For each
finding, add your own agree/disagree call with one line of reasoning — do
not silently drop findings, and do not act on them automatically. Acting on
a finding (fixing code, filing a follow-up) is a separate, explicit step the
user asks for after seeing the review.
