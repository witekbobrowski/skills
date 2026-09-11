---
name: verify
description: Build APPNAME and run its test plan to verify a change actually works.
---

# Verify a change

1. Fast compile check: `Scripts/build.sh`
2. Full test plan (package tests + app unit tests + UI smoke test): `Scripts/test.sh`
   - `Scripts/test.sh --skip-ui` when the change cannot affect launch/UI chrome.
3. Formatting gate (CI enforces it): `Scripts/format.sh --check`

For visual verification (screenshots, tapping through a flow), prefer
XcodeBuildMCP tools (`build_run_sim_name_ws`, `screenshot`, `describe_ui`)
when that MCP server is connected.
