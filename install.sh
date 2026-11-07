#!/bin/bash
# Install or update VietType on macOS.
# curl -fsSL https://itsdothugo.github.io/viettype/install.sh | bash
set -euo pipefail
export LC_ALL=C

REPO="itsdothugo/viettype-releases"
MAC_TEAM="8TN4M8PFAT"
MAC_APP_USER="$HOME/Library/Input Methods/VietType.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
TMPD=""
STAGE=""

log() { printf '%s\n' "$*"; }
die() { printf 'Error: %s\n' "$*" >&2; exit 1; }
cleanup() {
  # Keep the previous app if replacement fails.
  if [ -n "$STAGE" ] && [ -d "$STAGE/previous.app" ] && [ ! -e "$MAC_APP_USER" ]; then
    /bin/mv "$STAGE/previous.app" "$MAC_APP_USER" || return
  fi
  [ -z "$STAGE" ] || /bin/rm -rf "$STAGE"
  [ -z "$TMPD" ] || /bin/rm -rf "$TMPD"
}
trap cleanup EXIT

fetch() {
  curl -fsSL --proto '=https' --proto-redir '=https' --tlsv1.2 --retry 2 -o "$2" "$1"
}
json_field() { /usr/bin/plutil -extract "$2" raw -o - "$1" 2>/dev/null; }

mac_verify_app() {
  local app="$1" ver="$2" requirement
  [ -d "$app" ] && [ ! -L "$app" ] || die "The archive does not contain VietType.app."
  [ "$(json_field "$app/Contents/Info.plist" CFBundleIdentifier)" = "com.viettype.inputmethod.telex" ] \
    || die "Unexpected app identifier."
  [ "$(json_field "$app/Contents/Info.plist" CFBundleShortVersionString)" = "$ver" ] \
    || die "The app version does not match the release."
  requirement="identifier \"com.viettype.inputmethod.telex\" and anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] exists and certificate leaf[field.1.2.840.113635.100.6.1.13] exists and certificate leaf[subject.OU] = \"$MAC_TEAM\""
  /usr/bin/codesign --verify --deep --strict -R="$requirement" "$app" \
    || die "Invalid VietType Developer ID signature."
  /usr/sbin/spctl --assess --type execute "$app" \
    || die "Gatekeeper rejected the app. A notarized release is required."
}

validate_archive() {
  local archive="$1" entry
  /usr/bin/unzip -Z1 "$archive" > "$TMPD/entries" || die "Invalid ZIP archive."
  while IFS= read -r entry; do
    case "$entry" in
      /*|../*|*/../*|*/..|*\\*) die "Unsafe archive path." ;;
      VietType.app|VietType.app/*|__MACOSX/*) ;;
      *) die "Unexpected archive entry: $entry" ;;
    esac
  done < "$TMPD/entries"
  # This standalone app does not need symbolic links.
  /usr/bin/zipinfo -l "$archive" > "$TMPD/listing" || die "Cannot read ZIP archive."
  if /usr/bin/grep -q '^l' "$TMPD/listing"; then die "Archive contains symbolic links."; fi
}

mac_install_zip() {
  TMPD=$(mktemp -d)
  log "Checking the latest VietType release..."
  fetch "https://api.github.com/repos/$REPO/releases/latest" "$TMPD/release.json" \
    || die "Cannot find a release. Check your connection and try again."
  local tag ver archive attempt
  tag=$(json_field "$TMPD/release.json" tag_name) || die "Cannot read release metadata."
  ver=${tag#v}
  [[ "$tag" = v* && "$ver" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] || die "Invalid release tag: $tag"
  archive="$TMPD/VietType-$ver.app.zip"
  log "Downloading VietType $ver..."
  fetch "https://github.com/$REPO/releases/download/$tag/VietType-$ver.app.zip" "$archive" \
    || die "Cannot download VietType $ver."
  validate_archive "$archive"
  /bin/mkdir -p "$HOME/Library/Input Methods"
  STAGE=$(mktemp -d "$HOME/Library/Input Methods/.viettype-install.XXXXXX")
  /usr/bin/ditto -x -k "$archive" "$STAGE"
  mac_verify_app "$STAGE/VietType.app" "$ver"

  /usr/bin/pkill -u "$(id -u)" -x VietType 2>/dev/null || true
  for attempt in {1..50}; do
    /usr/bin/pgrep -u "$(id -u)" -x VietType >/dev/null || break
    /bin/sleep 0.1
  done
  if /usr/bin/pgrep -u "$(id -u)" -x VietType >/dev/null; then
    die "VietType is still running. Quit it and try again."
  fi
  if [ -e "$MAC_APP_USER" ]; then /bin/mv "$MAC_APP_USER" "$STAGE/previous.app"; fi
  /bin/mv "$STAGE/VietType.app" "$MAC_APP_USER"
  "$LSREGISTER" -f "$MAC_APP_USER" || log "Open VietType.app to register it."
  /usr/bin/open "$MAC_APP_USER" --args --request-permissions || log "Open VietType.app to grant permissions."
  log "Installed VietType $ver."
  log "Add VietType in System Settings > Keyboard > Input Sources."
}

main() {
  [ "$#" -eq 0 ] || die "This script does not accept arguments."
  [ "$(uname -s)" = Darwin ] || die "VietType requires macOS."
  [ "$(id -u)" != 0 ] || die "Run this script as your normal user, without sudo."
  if command -v brew >/dev/null 2>&1 && brew list --cask viettype >/dev/null 2>&1; then
    die "Homebrew manages VietType. Update it with: brew upgrade --cask viettype"
  fi
  mac_install_zip
}
if [[ "${BASH_SOURCE[0]:-$0}" = "$0" ]]; then main "$@"; fi
