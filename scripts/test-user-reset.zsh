#!/bin/zsh

set -e
setopt pipe_fail

test_user="moontheripper"
reset_app=0
reset_state=0
delete_user=0
yes=0

usage() {
  cat <<'USAGE'
Usage:
  zsh scripts/test-user-reset.zsh [options]

Options:
  --user NAME        Test macOS user. Default: moontheripper
  --app              Remove the test app only
  --state            Remove RipperMoonKit test configs, logs, prefixes, and caches
  --all              Remove both the test app and state
  --delete-user      Delete the moontheripper macOS user and home folder
  --yes              Skip confirmation prompt
  -h, --help         Show this help

This reset script is intentionally narrow. It only targets the configured test
user's home folder and the separate test bundle name.
USAGE
}

die() {
  print -u2 -- "❌ $*"
  exit 1
}

log() {
  printf '%s [%s] %s\n' "$1" "$(date '+%Y-%m-%d %H:%M:%S')" "$2"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --user)
      [[ $# -ge 2 ]] || die "--user requires a value"
      test_user="$2"
      shift 2
      ;;
    --app)
      reset_app=1
      shift
      ;;
    --state)
      reset_state=1
      shift
      ;;
    --all)
      reset_app=1
      reset_state=1
      shift
      ;;
    --delete-user)
      delete_user=1
      reset_app=1
      reset_state=1
      shift
      ;;
    --yes)
      yes=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
done

[[ "${reset_app}" == "1" || "${reset_state}" == "1" || "${delete_user}" == "1" ]] || {
  usage
  exit 2
}
[[ "${test_user}" == "moontheripper" ]] || die "refusing to reset non-default user without editing the script intentionally"

id -u "${test_user}" >/dev/null 2>&1 || die "test user does not exist: ${test_user}"
test_home="$(dscl . -read "/Users/${test_user}" NFSHomeDirectory 2>/dev/null | awk '{print $2}')"
[[ -n "${test_home}" ]] || test_home="/Users/${test_user}"
[[ "${test_home}" == "/Users/${test_user}" ]] || die "unexpected home for ${test_user}: ${test_home}"

targets=()
if [[ "${reset_app}" == "1" ]]; then
  targets+=("${test_home}/Applications/RipperMoonKit Test Launcher.app")
fi
if [[ "${reset_state}" == "1" ]]; then
  targets+=(
    "${test_home}/.rippermoon-gptk.env"
    "${test_home}/GPTK"
    "${test_home}/WinePrefixes"
    "${test_home}/Library/Application Support/RipperMoonKit"
    "${test_home}/Library/Preferences/com.rippermoon.toolkit.launcher.test.plist"
    "${test_home}/Library/Caches/com.rippermoon.toolkit.launcher.test"
    "${test_home}/Library/Saved Application State/com.rippermoon.toolkit.launcher.test.savedState"
  )
fi

log "🧭" "Targets:"
for target in "${targets[@]}"; do
  print -r -- "  ${target}"
done
if [[ "${delete_user}" == "1" ]]; then
  print -r -- "  macOS user account: ${test_user}"
  print -r -- "  home folder: ${test_home}"
fi

if [[ "${yes}" != "1" ]]; then
  print -rn -- "Type ${test_user} to confirm reset: "
  read -r confirmation
  [[ "${confirmation}" == "${test_user}" ]] || die "confirmation failed"
fi

for target in "${targets[@]}"; do
  [[ "${target}" == "${test_home}"* ]] || die "unsafe target escaped test home: ${target}"
  if [[ -e "${target}" ]]; then
    sudo rm -rf "${target}"
    log "🧹" "Removed ${target}"
  fi
done

if [[ "${delete_user}" == "1" ]]; then
  log "👤" "Deleting macOS test user: ${test_user}"
  sudo sysadminctl -deleteUser "${test_user}" >/dev/null
  if [[ -d "${test_home}" ]]; then
    sudo rm -rf "${test_home}"
  fi
  log "✅" "Deleted ${test_user}"
else
  log "✅" "Reset complete."
fi
