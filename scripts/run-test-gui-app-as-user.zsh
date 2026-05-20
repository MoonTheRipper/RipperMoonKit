#!/bin/zsh

set -e
setopt pipe_fail

test_user="moontheripper"
app_name="RipperMoonKit Test Launcher.app"
binary_smoke=0

usage() {
  cat <<'USAGE'
Usage:
  zsh scripts/run-test-gui-app-as-user.zsh [options]

Options:
  --user NAME       Test macOS user. Default: moontheripper
  --binary-smoke    Run the app executable as the test user instead of opening Finder
  -h, --help        Show this help

For a full GUI test, log into the moontheripper macOS account and open:

  ~/Applications/RipperMoonKit Test Launcher.app

This helper can launch it when the active macOS console session belongs to the
test user. Otherwise it prints the exact path and refuses to run the test app as
the normal user.
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
    --binary-smoke)
      binary_smoke=1
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

uid="$(id -u "${test_user}" 2>/dev/null)" || die "test user does not exist: ${test_user}"
test_home="$(dscl . -read "/Users/${test_user}" NFSHomeDirectory 2>/dev/null | awk '{print $2}')"
[[ -n "${test_home}" ]] || test_home="/Users/${test_user}"
target_app="${test_home}/Applications/${app_name}"
executable="${target_app}/Contents/MacOS/RipperMoonKitLauncher"

[[ -d "${target_app}" ]] || die "test app not installed: ${target_app}"
[[ -x "${executable}" ]] || die "test app executable missing: ${executable}"

console_user="$(stat -f %Su /dev/console 2>/dev/null || print -r -- unknown)"

if [[ "${binary_smoke}" == "1" ]]; then
  log "🧪" "Running executable smoke test as ${test_user}."
  sudo -H -u "${test_user}" env \
    HOME="${test_home}" \
    USER="${test_user}" \
    LOGNAME="${test_user}" \
    TMPDIR="${test_home}/Library/Caches" \
    "${executable}"
  exit 0
fi

if [[ "${console_user}" != "${test_user}" ]]; then
  log "⚠️" "Active macOS GUI session belongs to '${console_user}', not '${test_user}'."
  log "📍" "Switch to the ${test_user} account and open:"
  print -r -- "   ${target_app}"
  log "ℹ️" "Use --binary-smoke only for a non-Finder executable check."
  exit 75
fi

log "🚀" "Opening test app as ${test_user}: ${target_app}"
launchctl asuser "${uid}" open "${target_app}"
