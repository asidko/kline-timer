#!/usr/bin/env bash
set -euo pipefail
# Build KlineTimer.app — a menu-bar (LSUIElement) macOS app bundle.
# Usage:
#   ./bundle.sh                 build release bundle into ./KlineTimer.app
#   ./bundle.sh && open KlineTimer.app

# --- Configuration ---
# SwiftPM product / executable name.
PRODUCT="KlineTimer"
# Output bundle path.
APP_DIR="KlineTimer.app"
# Info.plist template copied into the bundle.
PLIST="Info.plist"
# Binary to bundle. Default = the local single-arch release build; the release
# workflow overrides this with the universal binary it has already built.
BIN="${BIN:-.build/release/$PRODUCT}"
# Skip `swift build` — set by callers that already built the binary themselves.
SKIP_BUILD="${SKIP_BUILD:-}"
# Ad-hoc codesign the bundle (1 = yes). Unsigned arm64 needs this to launch off-machine.
CODESIGN="${CODESIGN:-0}"

log() { printf '[bundle] %s\n' "$*"; }
die() { printf '[bundle] error: %s\n' "$*" >&2; exit 1; }

# Verify the toolchain and inputs are present.
preflight() {
  command -v swift >/dev/null || die "swift not found"
  [[ -f "$PLIST" ]] || die "missing $PLIST"
}

# Compile the optimised release binary, unless the caller already built one.
build_release() {
  if [[ -n "$SKIP_BUILD" ]]; then
    log "skipping build (SKIP_BUILD set)"
    return
  fi
  log "building release…"
  swift build -c release
}

# Assemble the .app directory and copy the binary + Info.plist into it.
assemble_bundle() {
  local macos="$APP_DIR/Contents/MacOS"
  [[ -f "$BIN" ]] || die "binary not found at $BIN"
  rm -rf "$APP_DIR"
  mkdir -p "$macos" "$APP_DIR/Contents/Resources"
  cp "$PLIST" "$APP_DIR/Contents/Info.plist"
  cp "$BIN" "$macos/$PRODUCT"
  if [[ -f "Resources/AppIcon.icns" ]]; then
    cp "Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
  else
    log "warning: Resources/AppIcon.icns missing — bundle will have no icon"
  fi
  if [[ "$CODESIGN" == "1" ]]; then
    log "ad-hoc signing…"
    codesign -s - --force --deep "$APP_DIR"
  fi
  log "wrote $APP_DIR"
}

preflight
build_release
assemble_bundle
log "done — run: open $APP_DIR"
