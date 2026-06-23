#!/usr/bin/env bash
set -euo pipefail
# Build KlineTimer.dmg — a drag-to-install disk image: opening it shows the app
# next to an Applications shortcut, so the user drags one onto the other.
# Usage:
#   ./bundle.sh && tools/make-dmg.sh        build KlineTimer.dmg from ./KlineTimer.app

# --- Configuration ---
# App bundle to package (build it first with ./bundle.sh).
APP="KlineTimer.app"
# Output disk image.
DMG="KlineTimer.dmg"
# Volume name shown when the image is mounted.
VOLNAME="Kline Timer"
# Read-write scratch image used to lay out the window before compressing.
RW="$(mktemp -d)/rw.dmg"

log() { printf '[dmg] %s\n' "$*"; }
die() { printf '[dmg] error: %s\n' "$*" >&2; exit 1; }

# Best-effort Finder layout: icon view, app on the left, Applications on the
# right. Skipped (non-fatal) when Finder is not scriptable, e.g. headless CI.
layout_window() {
  osascript >/dev/null 2>&1 <<EOF || return 1
tell application "Finder"
  tell disk "$VOLNAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, 700, 460}
    set opts to the icon view options of container window
    set arrangement of opts to not arranged
    set icon size of opts to 112
    set position of item "$APP" of container window to {130, 170}
    set position of item "Applications" of container window to {370, 170}
    update without registering applications
    delay 1
    close
  end tell
end tell
EOF
}

# Stage the app + an Applications symlink on a read-write image, lay it out,
# then convert to a compressed read-only image.
build_dmg() {
  [[ -d "$APP" ]] || die "missing $APP (run ./bundle.sh first)"
  rm -f "$DMG"
  hdiutil detach "/Volumes/$VOLNAME" >/dev/null 2>&1 || true

  hdiutil create -volname "$VOLNAME" -size 64m -fs HFS+ -ov "$RW" >/dev/null
  hdiutil attach -noautoopen "$RW" >/dev/null
  local mnt="/Volumes/$VOLNAME"

  cp -R "$APP" "$mnt/"
  ln -s /Applications "$mnt/Applications"
  layout_window || log "layout skipped (Finder not scriptable)"
  sync

  hdiutil detach "$mnt" >/dev/null 2>&1 || hdiutil detach "$mnt" -force >/dev/null
  hdiutil convert "$RW" -format UDZO -ov -o "$DMG" >/dev/null
  rm -f "$RW"
  log "wrote $DMG ($(du -h "$DMG" | cut -f1))"
}

build_dmg
