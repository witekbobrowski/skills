#!/bin/bash
# Scaffold a new iOS app repo from the blueprint templates.
# Mechanical part only: copies templates, renames APPNAME paths, substitutes tokens.
# The wizard (SKILL.md) handles everything bespoke afterwards: vision doc,
# capabilities/entitlements, extra modules, git init.
set -euo pipefail

usage() {
    cat >&2 <<'EOF'
Usage: scaffold.sh --name <AppName> --bundle-id <id> --dest <dir> [options]

Required:
  --name <AppName>        Product/target name. UpperCamelCase, letters+digits only.
  --bundle-id <id>        Full bundle identifier, e.g. dev.bobrowski.MyApp
  --dest <dir>            Destination directory (created if missing; must be
                          empty or nonexistent).

Optional:
  --display-name <name>   Human-facing app name (default: --name)
  --team <TEAMID>         Apple Development Team ID (default: empty = set later)
  --target <version>      iOS deployment target (default: 18.0)
  --device-family <fam>   1 = iPhone, 1,2 = iPhone+iPad (default: 1,2)
  --pitch <text>          One-line product pitch (default: token left for wizard)
EOF
    exit 1
}

NAME="" BUNDLE="" DEST="" DISPLAY="" TEAM="" TARGET="18.0" FAMILY="1,2" PITCH=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --name) NAME="$2"; shift 2 ;;
        --bundle-id) BUNDLE="$2"; shift 2 ;;
        --dest) DEST="$2"; shift 2 ;;
        --display-name) DISPLAY="$2"; shift 2 ;;
        --team) TEAM="$2"; shift 2 ;;
        --target) TARGET="$2"; shift 2 ;;
        --device-family) FAMILY="$2"; shift 2 ;;
        --pitch) PITCH="$2"; shift 2 ;;
        *) echo "Unknown option: $1" >&2; usage ;;
    esac
done

[[ -n "$NAME" && -n "$BUNDLE" && -n "$DEST" ]] || usage
[[ "$NAME" =~ ^[A-Za-z][A-Za-z0-9]*$ ]] || { echo "error: --name must be letters/digits, no spaces: '$NAME'" >&2; exit 1; }
[[ "$TARGET" =~ ^[0-9]+(\.[0-9]+)?$ ]] || { echo "error: --target must look like 18.0" >&2; exit 1; }
DISPLAY="${DISPLAY:-$NAME}"

TEMPLATES="$(cd "$(dirname "$0")/../templates" && pwd)"
mkdir -p "$DEST"
if [[ -n "$(ls -A "$DEST" 2>/dev/null)" ]]; then
    echo "error: destination '$DEST' is not empty" >&2
    exit 1
fi

cp -R "$TEMPLATES/." "$DEST/"
cd "$DEST"
# dot-<name> template entries become .<name> (gitignore, github, cursor, claude, swift-format, …)
for dot in dot-*; do
    mv "$dot" ".${dot#dot-}"
done

# Rename APPNAME paths, deepest entries first so parents stay valid.
while IFS= read -r -d '' path; do
    base="$(basename "$path")"
    mv "$path" "$(dirname "$path")/${base//APPNAME/$NAME}"
done < <(find . -depth -name '*APPNAME*' -print0)

MAJOR="${TARGET%%.*}"
TODAY="$(date +%Y-%m-%d)"

# Token substitution across every file ('|' delimiter: values may contain '/').
LC_ALL=C find . -type f -print0 | xargs -0 sed -i '' \
    -e "s|APPNAME|$NAME|g" \
    -e "s|__DISPLAY_NAME__|$DISPLAY|g" \
    -e "s|__BUNDLE_ID__|$BUNDLE|g" \
    -e "s|__TEAM_ID__|$TEAM|g" \
    -e "s|__DEPLOYMENT_TARGET__|$TARGET|g" \
    -e "s|__DEVICE_FAMILY__|$FAMILY|g" \
    -e "s|__PACKAGE_PLATFORM__|.v$MAJOR|g" \
    -e "s|__TODAY__|$TODAY|g"

if [[ -n "$PITCH" ]]; then
    LC_ALL=C find . -type f -print0 | xargs -0 sed -i '' -e "s|__ONE_LINE_PITCH__|$PITCH|g"
fi

echo "Scaffolded $NAME at $DEST"
echo "Remaining tokens for the wizard to fill:"
grep -rn "__[A-Z_]*__" . --include='*' -l 2>/dev/null || echo "  (none)"
