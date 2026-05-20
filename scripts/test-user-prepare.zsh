#!/bin/zsh

set -e
setopt pipe_fail

test_user="moontheripper"
full_name="RipperMoonKit Test User"
home_dir=""
create_user=1

usage() {
  cat <<'USAGE'
Usage:
  zsh scripts/test-user-prepare.zsh [options]

Options:
  --user NAME       Test macOS short name. Default: moontheripper
  --home PATH       Test user's home folder. Default: /Users/NAME
  --no-create       Fail if the user does not already exist
  -h, --help        Show this help

This prepares a real macOS user for fresh-install testing. It keeps the test
app and all RipperMoonKit state outside the normal user's app and config paths.

When the user is missing, the script asks for a password for the new test
account. The password is passed to macOS user creation and is not written to
RipperMoonKit files.
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
    --home)
      [[ $# -ge 2 ]] || die "--home requires a path"
      home_dir="$2"
      shift 2
      ;;
    --no-create)
      create_user=0
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

[[ "${test_user}" == "moontheripper" ]] || {
  log "⚠️" "Using a non-default test user: ${test_user}"
}
[[ -n "${home_dir}" ]] || home_dir="/Users/${test_user}"

if id -u "${test_user}" >/dev/null 2>&1; then
  ds_home="$(dscl . -read "/Users/${test_user}" NFSHomeDirectory 2>/dev/null | awk '{print $2}')"
  [[ -n "${ds_home}" ]] && home_dir="${ds_home}"
  log "✅" "Test user exists: ${test_user}"
else
  [[ "${create_user}" == "1" ]] || die "test user does not exist: ${test_user}"

  print -r -- "RipperMoonKit needs a real test macOS user named '${test_user}'."
  print -r -- "macOS will ask for a temporary password for that test user."

  log "👤" "Creating macOS test user: ${test_user}"
  sudo sysadminctl \
    -addUser "${test_user}" \
    -fullName "${full_name}" \
    -password - \
    -home "${home_dir}" >/dev/null
  log "✅" "Created test user: ${test_user}"
fi

group_name="$(id -gn "${test_user}" 2>/dev/null || print -r -- staff)"

log "📁" "Preparing isolated folders under ${home_dir}"
sudo mkdir -p \
  "${home_dir}/Applications" \
  "${home_dir}/Desktop" \
  "${home_dir}/Downloads" \
  "${home_dir}/GPTK/logs" \
  "${home_dir}/GPTK/backups" \
  "${home_dir}/WinePrefixes" \
  "${home_dir}/Library/Application Support/RipperMoonKit" \
  "${home_dir}/Library/Preferences" \
  "${home_dir}/Library/Caches" \
  "${home_dir}/Library/Saved Application State"

sudo chown -R "${test_user}:${group_name}" \
  "${home_dir}/Applications" \
  "${home_dir}/Desktop" \
  "${home_dir}/Downloads" \
  "${home_dir}/GPTK" \
  "${home_dir}/WinePrefixes" \
  "${home_dir}/Library/Application Support/RipperMoonKit" \
  "${home_dir}/Library/Preferences" \
  "${home_dir}/Library/Caches" \
  "${home_dir}/Library/Saved Application State"

log "✅" "Ready for isolated app testing."
log "📍" "Test app target: ${home_dir}/Applications/RipperMoonKit Test Launcher.app"
