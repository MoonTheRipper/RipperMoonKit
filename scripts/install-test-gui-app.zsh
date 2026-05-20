#!/bin/zsh

set -e
setopt pipe_fail

repo_dir="${0:A:h:h}"
test_user="moontheripper"
app_name="RipperMoonKit Test Launcher.app"
launch_after=0

usage() {
  cat <<'USAGE'
Usage:
  zsh scripts/install-test-gui-app.zsh [options]

Options:
  --user NAME       Test macOS user. Default: moontheripper
  --launch          Try to launch after install
  -h, --help        Show this help

Builds a separate test app and installs it into:

  /Users/moontheripper/Applications/RipperMoonKit Test Launcher.app

This script intentionally refuses /Applications and the current user's normal
RipperMoonKit app path. It is for fresh-user testing only.
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
    --launch)
      launch_after=1
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

id -u "${test_user}" >/dev/null 2>&1 || die "test user does not exist. Run: zsh scripts/test-user-prepare.zsh"

test_home="$(dscl . -read "/Users/${test_user}" NFSHomeDirectory 2>/dev/null | awk '{print $2}')"
[[ -n "${test_home}" ]] || test_home="/Users/${test_user}"
target_app="${test_home}/Applications/${app_name}"

[[ "${target_app}" != /Applications/* ]] || die "refusing to install test app system-wide"
if [[ "${target_app}" == "${HOME}/Applications/"* && "$(id -un)" != "${test_user}" ]]; then
  die "refusing to install test app into the current user's Applications folder"
fi
[[ "${target_app:t}" == "${app_name}" ]] || die "unexpected test app name: ${target_app:t}"

tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/rmk-test-app.XXXXXX")"
tmp_app="${tmp_root}/${app_name}"
cleanup() {
  rm -rf "${tmp_root}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

log "🧪" "Building isolated test app bundle."
RIPPERMOON_BUNDLE_ID="com.rippermoon.toolkit.launcher.test" \
RIPPERMOON_BUNDLE_NAME="RipperMoonKit Test Launcher" \
RIPPERMOON_DISPLAY_NAME="RipperMoonKit Test" \
RIPPERMOON_BACKUP_NAME="${app_name}.backup" \
  zsh "${repo_dir}/scripts/install-gui-app.zsh" "${tmp_app}"

[[ -d "${tmp_app}" ]] || die "test app build failed: ${tmp_app}"

stamp="$(date +%Y%m%d-%H%M%S)"
group_name="$(id -gn "${test_user}" 2>/dev/null || print -r -- staff)"
backup_dir="${test_home}/GPTK/backups/gui-test-app-${stamp}.noindex"

log "📦" "Installing test app for ${test_user}: ${target_app}"
sudo mkdir -p "${target_app:h}" "${backup_dir}"

if [[ -d "${target_app}" ]]; then
  sudo ditto "${target_app}" "${backup_dir}/${app_name}.backup"
  sudo rm -rf "${target_app}"
  log "🛟" "Backed up previous test app: ${backup_dir}/${app_name}.backup"
fi

sudo ditto "${tmp_app}" "${target_app}"
sudo chown -R "${test_user}:${group_name}" "${target_app}" "${backup_dir}"

log "✅" "Installed isolated test app: ${target_app}"
log "✅" "Normal user app was not touched."

if [[ "${launch_after}" == "1" ]]; then
  zsh "${repo_dir}/scripts/run-test-gui-app-as-user.zsh" --user "${test_user}"
fi
