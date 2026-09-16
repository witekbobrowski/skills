#!/usr/bin/env bash
set -euo pipefail

# Vendors Apple's agent skills shipped inside Xcode (exported via
# `xcrun agent skills export`) into xcode/. Everything under xcode/ is
# Apple's — never hand-edit it, re-run this script instead.

cd "$(dirname "${BASH_SOURCE[0]}")"

# The export tool resolves relative --output-dir paths against `/`, so
# this must be absolute.
OUT_DIR="$PWD/xcode"

export_log="$(mktemp)"
trap 'rm -f "$export_log"' EXIT

xcrun agent skills export --output-dir "$OUT_DIR" --replace-existing | tee "$export_log"

# Parse exported skill names from lines like "  ✓ swiftui-specialist".
exported=()
while IFS= read -r line; do
  name="${line#*✓}"
  name="${name#"${name%%[![:space:]]*}"}"
  exported+=("$name")
done < <(grep '✓' "$export_log")

# Remove stale skill dirs: any directory directly under xcode/ whose
# basename isn't in the freshly exported list. xcode/VERSION is a file,
# not a directory, so the xcode/*/ glob never matches it and it's
# untouched by this loop.
for dir in xcode/*/; do
  [[ -d "$dir" ]] || continue
  dir="${dir%/}"
  base="$(basename "$dir")"
  found=0
  for name in "${exported[@]}"; do
    if [[ "$name" == "$base" ]]; then
      found=1
      break
    fi
  done
  if [[ "$found" -eq 0 ]]; then
    rm -rf "$dir"
    echo "removed stale: $dir"
  fi
done

# Record the source Xcode build and export date.
{
  xcodebuild -version
  echo "Exported: $(date +%Y-%m-%d)"
} > xcode/VERSION

./link.sh

echo "synced ${#exported[@]} skill(s) into xcode/ — review \`git diff\` and commit"
