#!/bin/zsh

set -e
setopt pipe_fail

repo_dir="${0:A:h:h}"
dmg_path="${repo_dir}/dist.noindex/RipperMoonKit-Launcher.dmg"
test_home="/private/tmp/rippermoon-fresh-home"
reset_home=0
launch_app=1

usage() {
  cat <<'USAGE'
Usage:
  zsh scripts/test-fresh-app-home.zsh [options]

Options:
  --dmg PATH       DMG to install. Defaults to dist.noindex/RipperMoonKit-Launcher.dmg
  --home PATH      Fresh test home. Defaults to /private/tmp/rippermoon-fresh-home
  --reset          Delete the test home before installing the app
  --no-launch      Install the app into the test home but do not launch it
  -h, --help       Show this help

This launches the packaged app with HOME pointed at an isolated disposable
folder. It tests the fresh-user first-run path without logging out or switching
macOS accounts.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dmg)
      [[ $# -ge 2 ]] || { print -u2 -- "--dmg requires a path"; exit 2; }
      dmg_path="$2"
      shift 2
      ;;
    --home)
      [[ $# -ge 2 ]] || { print -u2 -- "--home requires a path"; exit 2; }
      test_home="$2"
      shift 2
      ;;
    --reset)
      reset_home=1
      shift
      ;;
    --no-launch)
      launch_app=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      print -u2 -- "Unknown option: $1"
      usage
      exit 2
      ;;
  esac
done

[[ -f "${dmg_path}" ]] || {
  print -u2 -- "DMG not found: ${dmg_path}"
  print -u2 -- "Run: zsh scripts/package-release.zsh"
  exit 1
}

if [[ "${reset_home}" == "1" ]]; then
  rm -rf "${test_home}"
fi

mkdir -p \
  "${test_home}/Applications" \
  "${test_home}/Desktop" \
  "${test_home}/Documents" \
  "${test_home}/Downloads" \
  "${test_home}/Library/Application Support" \
  "${test_home}/Library/Preferences" \
  "${test_home}/Library/Caches" \
  "${test_home}/Library/Saved Application State"

mount_root="$(mktemp -d "${TMPDIR:-/tmp}/rmk-dmg.XXXXXX")"
detach_target=""
mounted_volume=""
cleanup() {
  if [[ -n "${mounted_volume}" ]]; then
    hdiutil detach "${mounted_volume}" -quiet >/dev/null 2>&1 || true
  fi
  if [[ -n "${detach_target}" ]]; then
    hdiutil detach "${detach_target}" -quiet >/dev/null 2>&1 || true
  fi
  rm -rf "${mount_root}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

print -r -- "💿 Mounting ${dmg_path}"
attach_output="$(hdiutil attach -nobrowse -readonly -mountroot "${mount_root}" "${dmg_path}")"
detach_target="$(print -r -- "${attach_output}" | awk 'NR == 1 { print $1 }')"
mounted_volume="$(print -r -- "${attach_output}" | awk 'NF >= 3 && $NF ~ /^\// { print $NF }' | tail -n 1)"
[[ -n "${mounted_volume}" ]] || mounted_volume="$(find "${mount_root}" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
[[ -n "${mounted_volume}" ]] || {
  print -u2 -- "Could not determine mounted DMG volume."
  print -u2 -- "${attach_output}"
  exit 1
}

source_app="${mounted_volume}/RipperMoonKit Launcher.app"
target_app="${test_home}/Applications/RipperMoonKit Launcher.app"
[[ -d "${source_app}" ]] || {
  print -u2 -- "Packaged app not found in mounted DMG: ${source_app}"
  exit 1
}

rm -rf "${target_app}"
ditto "${source_app}" "${target_app}"
print -r -- "✅ Installed test app: ${target_app}"

if [[ "${launch_app}" != "1" ]]; then
  print -r -- "ℹ️ Launch skipped."
  exit 0
fi

executable="${target_app}/Contents/MacOS/RipperMoonKitLauncher"
[[ -x "${executable}" ]] || {
  print -u2 -- "Executable not found: ${executable}"
  exit 1
}

print -r -- "🚀 Launching with isolated HOME=${test_home}"
print -r -- "ℹ️ Close the app window when finished testing."
env \
  HOME="${test_home}" \
  USER="rippermoonfresh" \
  LOGNAME="rippermoonfresh" \
  TMPDIR="${test_home}/Library/Caches" \
  "${executable}"
