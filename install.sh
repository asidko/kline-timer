#!/bin/sh
set -eu
# Install Kline Timer into /Applications from the latest GitHub release.
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/asidko/kline-timer/main/install.sh | sh
#   curl -fsSL .../install.sh | sh -s -- --tag v1.0.0   # pin a release
#   curl -fsSL .../install.sh | sh -s -- --remove       # uninstall

# --- Configuration ---
# GitHub repo to pull releases from.
REPO="asidko/kline-timer"
# App bundle name and install destination.
APP="KlineTimer.app"
DEST="/Applications"
# Release asset (universal arm64+x86_64 disk image) and its checksum file.
ASSET="KlineTimer.dmg"
SUMS="SHA256SUMS"

log() { printf '==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

# Refuse anything but macOS.
require_macos() {
  [ "$(uname -s)" = "Darwin" ] || die "Kline Timer is macOS only."
}

# Resolve the release tag: explicit --tag wins, else the latest published release.
resolve_tag() {
  if [ -n "${TAG:-}" ]; then printf '%s' "$TAG"; return; fi
  api="https://api.github.com/repos/$REPO/releases/latest"
  # Branch on the token so the quoted auth header survives (an unquoted
  # ${TOKEN:+-H "..."} word-splits and sends a broken header).
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    json=$(curl -fsSL -H "Authorization: Bearer $GITHUB_TOKEN" "$api")
  else
    json=$(curl -fsSL "$api")
  fi
  tag=$(printf '%s' "$json" | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1)
  [ -n "$tag" ] || die "could not resolve latest release (rate limited? set GITHUB_TOKEN)."
  printf '%s' "$tag"
}

# Download dmg + checksum, verify, copy the app out of the mounted image into
# /Applications, clear the quarantine flag.
install_app() {
  tag="$1"
  base="https://github.com/$REPO/releases/download/$tag"
  tmp=$(mktemp -d)
  mnt="$tmp/mnt"
  trap 'hdiutil detach "$mnt" >/dev/null 2>&1 || true; rm -rf "$tmp"' EXIT

  log "downloading $ASSET ($tag)..."
  curl -fsSL "$base/$ASSET" -o "$tmp/$ASSET"
  curl -fsSL "$base/$SUMS"  -o "$tmp/$SUMS"

  log "verifying checksum..."
  ( cd "$tmp" && grep " $ASSET\$" "$SUMS" | shasum -a 256 -c - ) \
    || die "checksum verification failed."

  log "installing to $DEST/$APP..."
  mkdir -p "$mnt"
  hdiutil attach -nobrowse -readonly -mountpoint "$mnt" "$tmp/$ASSET" >/dev/null
  rm -rf "${DEST:?}/${APP:?}"
  cp -R "$mnt/$APP" "$DEST/$APP"
  hdiutil detach "$mnt" >/dev/null

  xattr -dr com.apple.quarantine "$DEST/$APP" 2>/dev/null || true
  log "done — launch Kline Timer from /Applications or Spotlight."
}

# Remove the app; note where preferences live.
remove_app() {
  rm -rf "${DEST:?}/${APP:?}"
  log "removed $DEST/$APP."
  log "preferences remain at ~/Library/Preferences/com.kline.timer.plist"
  log "clear them with: defaults delete com.kline.timer"
}

main() {
  action="install"
  while [ $# -gt 0 ]; do
    case "$1" in
      --tag) TAG="$2"; shift 2 ;;
      --tag=*) TAG="${1#*=}"; shift ;;
      --remove|--uninstall) action="remove"; shift ;;
      *) die "unknown option: $1" ;;
    esac
  done

  require_macos
  if [ "$action" = "remove" ]; then remove_app; else install_app "$(resolve_tag)"; fi
}

main "$@"
