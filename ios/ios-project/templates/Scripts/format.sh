#!/bin/bash
# Format all Swift sources with swift-format (bundled with Xcode 16+).
#   Scripts/format.sh            — format in place
#   Scripts/format.sh --check    — lint only, non-zero exit on violations (CI)
set -euo pipefail
cd "$(dirname "$0")/.."

DIRS=(APPNAME APPNAMETests APPNAMEUITests Packages/Modules/Sources Packages/Modules/Tests)

if [[ "${1:-}" == "--check" ]]; then
    swift format lint --strict --recursive --configuration .swift-format "${DIRS[@]}"
else
    swift format --in-place --recursive --configuration .swift-format "${DIRS[@]}"
fi
