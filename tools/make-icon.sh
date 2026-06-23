#!/usr/bin/env bash
set -euo pipefail
# Generate Resources/AppIcon.icns from the Swift/CoreGraphics renderer.
# Usage:
#   tools/make-icon.sh        rebuild Resources/AppIcon.icns

# --- Configuration ---
# Repo root (parent of this script's directory).
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Output icon.
ICNS="$ROOT/Resources/AppIcon.icns"
# Scratch work directory.
WORK="$(mktemp -d)"

log() { printf '[icon] %s\n' "$*"; }
die() { printf '[icon] error: %s\n' "$*" >&2; exit 1; }

# Compile and run the renderer to produce the 1024px master PNG.
render_master() {
  command -v swiftc >/dev/null || die "swiftc not found"
  swiftc -O "$ROOT/tools/AppIconRenderer.swift" -o "$WORK/render"
  "$WORK/render" "$WORK/icon_1024.png"
}

# Resize the master into a full .iconset and pack it into .icns.
pack_icns() {
  local set="$WORK/AppIcon.iconset"
  mkdir -p "$set" "$ROOT/Resources"
  local s
  for s in 16 32 128 256 512; do
    sips -z "$s" "$s"           "$WORK/icon_1024.png" --out "$set/icon_${s}x${s}.png"     >/dev/null
    sips -z $((s * 2)) $((s * 2)) "$WORK/icon_1024.png" --out "$set/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$set" -o "$ICNS"
  log "wrote $ICNS ($(du -h "$ICNS" | cut -f1))"
}

render_master
pack_icns
rm -rf "$WORK"
