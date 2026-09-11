#!/bin/bash
# Canonical build command — agents and CI use this instead of guessing
# xcodebuild incantations.
set -euo pipefail
cd "$(dirname "$0")/.."

xcodebuild \
    -workspace APPNAME.xcworkspace \
    -scheme APPNAME \
    -destination 'generic/platform=iOS Simulator' \
    -configuration Debug \
    build
