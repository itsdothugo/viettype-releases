#!/bin/bash
# VietType — cài / cập nhật / gỡ trên macOS.
# curl -fsSL https://itsdothugo.github.io/viettype/install.sh | bash
set -euo pipefail
REPO="itsdothugo/viettype-releases"
MAC_TEAM="8TN4M8PFAT"
ASSUME_YES=0
UNINSTALL=0
DRY=0
FORCE_ZIP=0
TMPD=""
STAGE=""
MAC_APP_USER="$HOME/Library/Input Methods/VietType.app"
MAC_APP_SYS="/Library/Input Methods/VietType.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
say()  { printf '\033[1m==>\033[0m %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '\033[33m!!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[31mLỗi:\033[0m %s\n' "$*" >&2; exit 1; }
cleanup() {
  # Recover the old app if replacement failed after moving it aside.
  if [ -n "$STAGE" ] && [ -d "$STAGE/previous.app" ] && [ ! -e "$MAC_APP_USER" ]; then
    /bin/mv "$STAGE/previous.app" "$MAC_APP_USER" || return
  fi
  [ -z "$STAGE" ] || /bin/rm -rf "$STAGE"
  [ -z "$TMPD" ] || /bin/rm -rf "$TMPD"
}
trap cleanup EXIT
usage() { echo "VietType — macOS: --yes/-y, --zip, --uninstall, --dry-run, --help/-h"; }
run() {
  printf '    $ %s\n' "$*"
  [ "$DRY" = 1 ] || "$@"
}
fetch() {
  case "$1" in
    "https://api.github.com/repos/$REPO/"*|"https://github.com/$REPO/releases/download/"*) ;;
    *) die "từ chối tải từ địa chỉ lạ: $1" ;;
  esac
  curl -fsSL --proto '=https' --proto-redir '=https' --tlsv1.2 --retry 2 -o "$2" "$1"
}
ask() {
  [ "$ASSUME_YES" != 1 ] || return 0
  if ! { : </dev/tty; } 2>/dev/null; then [ "$2" = y ]; return; fi
  local ans
  printf '%s ' "$1" >/dev/tty
  read -r ans </dev/tty || ans=""
  [ -n "$ans" ] || ans=$2
  case "$ans" in y|Y|yes|c|C|co|có) return 0 ;; *) return 1 ;; esac
}
json_field() { /usr/bin/plutil -extract "$2" raw -o - "$1" 2>/dev/null; }
brew_managed() { command -v brew >/dev/null 2>&1 && brew list --cask viettype >/dev/null 2>&1; }

mac_verify_app() {
  local app="$1" ver="$2" requirement
  [ -d "$app" ] && [ ! -L "$app" ] || die "ZIP không chứa VietType.app hợp lệ."
  [ "$(json_field "$app/Contents/Info.plist" CFBundleIdentifier)" = "com.viettype.inputmethod.telex" ] \
    || die "bundle ID không phải VietType."
  [ "$(json_field "$app/Contents/Info.plist" CFBundleShortVersionString)" = "$ver" ] \
    || die "phiên bản trong app không khớp bản phát hành."
  requirement="identifier \"com.viettype.inputmethod.telex\" and anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] exists and certificate leaf[field.1.2.840.113635.100.6.1.13] exists and certificate leaf[subject.OU] = \"$MAC_TEAM\""
  /usr/bin/codesign --verify --deep --strict -R="$requirement" "$app" \
    || die "chữ ký không hợp lệ hoặc không phải bản Developer ID của VietType."
  /usr/sbin/spctl --assess --type execute "$app" \
    || die "Gatekeeper từ chối ứng dụng; cần bản phát hành đã notarize."
}

validate_archive() {
  local archive="$1" entry
  /usr/bin/unzip -Z1 "$archive" > "$TMPD/entries" || die "ZIP không hợp lệ."
  while IFS= read -r entry; do
    case "$entry" in
      /*|../*|*/../*|*/..|*\\*) die "đường dẫn không hợp lệ trong ZIP." ;;
      VietType.app|VietType.app/*|__MACOSX/*) ;;
      *) die "ZIP chứa mục ngoài VietType.app: $entry" ;;
    esac
  done < "$TMPD/entries"
  # The standalone app ships without symlinks; reject links before extraction.
  /usr/bin/zipinfo -l "$archive" > "$TMPD/listing" || die "không đọc được ZIP."
  if /usr/bin/grep -q '^l' "$TMPD/listing"; then die "ZIP chứa liên kết tượng trưng."; fi
}

mac_install_zip() {
  if [ "$DRY" = 1 ]; then
    say "Sẽ tải VietType-<version>.app.zip từ GitHub Releases ($REPO)."
    info "Kiểm tra bundle ID, phiên bản, chữ ký Developer ID và Gatekeeper."
    info "Thay VietType.app trong ~/Library/Input Methods, rồi mở app để hỏi quyền."
    return
  fi
  TMPD=$(mktemp -d)
  say "Đọc bản phát hành mới nhất"
  fetch "https://api.github.com/repos/$REPO/releases/latest" "$TMPD/release.json"
  local tag ver archive entry
  tag=$(json_field "$TMPD/release.json" tag_name) || die "không đọc được release."
  ver=${tag#v}
  [[ "$tag" = v* && "$ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "tag phiên bản lạ: $tag"
  archive="$TMPD/VietType-$ver.app.zip"
  say "Tải VietType $ver (.app.zip)"
  fetch "https://github.com/$REPO/releases/download/$tag/VietType-$ver.app.zip" "$archive"
  validate_archive "$archive"
  /bin/mkdir -p "$HOME/Library/Input Methods"
  STAGE=$(mktemp -d "$HOME/Library/Input Methods/.viettype-install.XXXXXX")
  /usr/bin/ditto -x -k "$archive" "$STAGE"
  mac_verify_app "$STAGE/VietType.app" "$ver"
  say "Cài vào ~/Library/Input Methods (không cần mật khẩu quản trị)"
  /usr/bin/pkill -x VietType 2>/dev/null || true
  local attempt
  for attempt in {1..50}; do
    /usr/bin/pgrep -u "$(id -u)" -x VietType >/dev/null || break
    /bin/sleep 0.1
  done
  if /usr/bin/pgrep -u "$(id -u)" -x VietType >/dev/null; then
    die "VietType chưa thoát; chưa thay ứng dụng. Hãy thử lại."
  fi
  if [ -e "$MAC_APP_USER" ]; then /bin/mv "$MAC_APP_USER" "$STAGE/previous.app"; fi
  /bin/mv "$STAGE/VietType.app" "$MAC_APP_USER"
  "$LSREGISTER" -f "$MAC_APP_USER" || warn "Không cập nhật được đăng ký ứng dụng."
  /usr/bin/open "$MAC_APP_USER" --args --request-permissions \
    || warn "Hãy mở VietType.app để cấp quyền."
}

mac_install() {
  [ "$(id -u)" != 0 ] || die "hãy chạy bằng tài khoản người dùng (không sudo)."
  if brew_managed; then
    [ "$FORCE_ZIP" != 1 ] || die "hãy chạy 'brew uninstall --cask viettype' trước khi dùng --zip."
    say "Cập nhật bản đang được Homebrew quản lý"
    run brew upgrade --cask viettype
  else
    mac_install_zip
  fi
  echo "Bước tiếp theo: System Settings → Keyboard → Input Sources → Edit… → + → Vietnamese → VietType."
  echo "Bật quyền Trợ năng cho VietType khi macOS yêu cầu. Chuyển Việt/Anh bằng Ctrl+Space hoặc 🌐."
}

mac_uninstall() {
  if brew_managed; then
    ask "Gỡ VietType (Homebrew cask)? [c/N]" n || { say "Huỷ."; return; }
    run brew uninstall --cask viettype
  else
    local found=0
    [ -e "$MAC_APP_USER" ] && found=1
    [ -e "$MAC_APP_SYS" ] && found=1
    [ "$found" = 1 ] || { say "Không thấy VietType.app."; return; }
    ask "Gỡ VietType.app khỏi máy? [c/N]" n || { say "Huỷ."; return; }
    run /usr/bin/pkill -x VietType || true
    [ -e "$MAC_APP_USER" ] && run rm -rf "$MAC_APP_USER"
    if [ -e "$MAC_APP_SYS" ]; then
      say "Bản cũ ở /Library/Input Methods (cần mật khẩu quản trị)"
      run sudo rm -rf "$MAC_APP_SYS"
    fi
  fi
  say "Đã gỡ. Đăng xuất/đăng nhập để macOS bỏ VietType khỏi Input Sources."
  info "Cài đặt cá nhân: ~/Library/Preferences/com.viettype.settings.plist (xoá tay nếu muốn)."
}

main() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --yes|-y) ASSUME_YES=1 ;;
      --uninstall) UNINSTALL=1 ;;
      --dry-run) DRY=1 ;;
      --zip) FORCE_ZIP=1 ;;
      --help|-h) usage; exit 0 ;;
      *) die "tuỳ chọn lạ: $1 (xem --help)" ;;
    esac
    shift
  done
  [ "$(uname -s)" = Darwin ] || die "VietType chỉ hỗ trợ macOS."
  if [ "$UNINSTALL" = 1 ]; then mac_uninstall; else mac_install; fi
}
if [[ "${BASH_SOURCE[0]}" = "$0" ]]; then main "$@"; fi
