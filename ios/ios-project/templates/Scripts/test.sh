#!/bin/bash
# Run the full test plan (package tests + app unit tests + UI smoke test).
#   Scripts/test.sh              — everything
#   Scripts/test.sh --skip-ui    — skip the UI test bundle (fast lane / CI)
# Override the simulator with SIMULATOR_NAME=<name>.
set -euo pipefail
cd "$(dirname "$0")/.."

SKIP_ARGS=()
if [[ "${1:-}" == "--skip-ui" ]]; then
    SKIP_ARGS=(-skip-testing:APPNAMEUITests)
fi

SIM="${SIMULATOR_NAME:-$(xcrun simctl list devices available | grep -oE 'iPhone [^(]+' | head -1 | xargs)}"
if [[ -z "$SIM" ]]; then
    echo "error: no available iPhone simulator found" >&2
    exit 1
fi
echo "Testing on simulator: $SIM"

# ${arr[@]+...} keeps bash 3.2's `set -u` happy when the array is empty
xcodebuild test \
    -workspace APPNAME.xcworkspace \
    -scheme APPNAME \
    -destination "platform=iOS Simulator,name=$SIM" \
    ${SKIP_ARGS[@]+"${SKIP_ARGS[@]}"}
