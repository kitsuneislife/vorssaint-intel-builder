#!/bin/zsh
# Builds the official Vorssaint source for Intel (x86_64) Macs.
#
# Upstream ships Apple Silicon builds only, but the source compiles for x86_64
# once the target triple in its build.sh is changed. This script fetches an
# official release tag, applies that one change, builds it and optionally
# installs the result into /Applications. Nothing is redistributed: every build
# happens on your own Mac from the upstream source.
#
# Usage: ./build.sh [--install] [--version <tag>]
set -euo pipefail

UPSTREAM="vorssaint/vorssaint-utils"
APP="Vorssaint.app"
INSTALL=0
VERSION=""

usage() {
    print "Usage: ./build.sh [--install] [--version <tag>]"
    print "  --install         replace /Applications/$APP with the Intel build"
    print "  --version <tag>   build a specific release tag (default: latest release)"
}

while (( $# )); do
    case "$1" in
        --install) INSTALL=1 ;;
        --version) [[ $# -ge 2 ]] || { usage >&2; exit 2 }; VERSION="$2"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) print -u2 "Unknown option: $1"; usage >&2; exit 2 ;;
    esac
    shift
done

step() { print "▸ $*" }
fail() { print -u2 "✗ $*"; exit 1 }

[[ "$(uname -m)" == "x86_64" ]] \
    || fail "This Mac is $(uname -m). Install the official build instead: https://github.com/$UPSTREAM/releases"
command -v swiftc >/dev/null \
    || fail "Swift is missing. Install the Command Line Tools with: xcode-select --install"
command -v git >/dev/null || fail "git is missing. Install the Command Line Tools with: xcode-select --install"

if [[ -z "$VERSION" ]]; then
    step "Looking up the latest release…"
    VERSION="$(curl -fsSL "https://api.github.com/repos/$UPSTREAM/releases/latest" \
        | sed -nE 's/^[[:space:]]*"tag_name":[[:space:]]*"([^"]+)".*/\1/p' | head -1)"
    [[ -n "$VERSION" ]] || fail "Could not read the latest release. Pass one with --version <tag>."
fi

# Upstream warns that folders synced by File Provider (~/Documents, iCloud)
# add xattrs that break codesign, so everything is built under a temp dir.
WORK="$(mktemp -d -t vorssaint-intel)"
trap 'rm -rf "$WORK"' EXIT

step "Fetching $UPSTREAM at $VERSION…"
git clone --quiet --depth 1 --branch "$VERSION" "https://github.com/$UPSTREAM.git" "$WORK/src" 2>/dev/null \
    || fail "Could not fetch $VERSION from $UPSTREAM (check the tag name and your connection)."

step "Switching the build target to x86_64…"
sed -i '' -E 's/^TARGET="arm64-apple-macosx([0-9.]+)"/TARGET="x86_64-apple-macosx\1"/' "$WORK/src/build.sh"
grep -qE '^TARGET="x86_64-apple-macosx' "$WORK/src/build.sh" \
    || fail "Upstream build.sh changed and no longer has the expected TARGET line. Please open an issue."

step "Building (this takes a few minutes)…"
( cd "$WORK/src" && ./build.sh ) > "$WORK/build.log" 2>&1 || {
    tail -40 "$WORK/build.log" >&2
    fail "Build failed (last 40 lines above)."
}

BUILT="$WORK/src/build/stage/$APP"
[[ -d "$BUILT" ]] || fail "Build finished but $APP was not produced."
[[ "$(lipo -archs "$BUILT/Contents/MacOS/Vorssaint")" == "x86_64" ]] \
    || fail "The built binary is not x86_64."
codesign --verify --deep --strict "$BUILT" || fail "The built bundle failed codesign verification."

if (( INSTALL )); then
    if [[ -d "/Applications/$APP" ]]; then
        step "Moving the current /Applications/$APP to the Trash…"
        osascript -e 'if application "Vorssaint" is running then tell application "Vorssaint" to quit' >/dev/null 2>&1 || true
        # Finder can report -10010 here even after it moved the item, so check the result instead.
        osascript -e "tell application \"Finder\" to delete POSIX file \"/Applications/$APP\"" >/dev/null 2>&1 || true
        [[ ! -e "/Applications/$APP" ]] || fail "Could not move the existing /Applications/$APP to the Trash."
    fi
    ditto "$BUILT" "/Applications/$APP"
    print "✓ Installed Vorssaint $VERSION for Intel in /Applications."
else
    OUT="$(pwd)/dist"
    rm -rf "$OUT/$APP"
    mkdir -p "$OUT"
    ditto "$BUILT" "$OUT/$APP"
    print "✓ Built Vorssaint $VERSION for Intel: $OUT/$APP"
    print "  Run again with --install to put it in /Applications."
fi
