#!/bin/zsh

set -e
setopt pipe_fail

repo_dir="${0:A:h:h}"
config="${HOME}/.rippermoon-gptk.env"
stamp="$(date +%Y%m%d-%H%M%S)"
app_path="${1:-${HOME}/Applications/RipperMoonKit Launcher.app}"

if [[ -r "${config}" ]]; then
  source "${config}"
fi

GPTK_HOME="${GPTK_HOME:-${HOME}/GPTK}"
GPTK_LOG_DIR="${GPTK_LOG_DIR:-${GPTK_HOME}/logs}"
mkdir -p "${GPTK_LOG_DIR}" "${GPTK_HOME}/backups" "${app_path:h}"
log_file="${GPTK_LOG_DIR}/rippermoon-gui-install-${stamp}.log"

log() {
  local icon="$1"
  shift
  printf '%s [%s] %s\n' "${icon}" "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "${log_file}"
}

log "🚀" "Building RipperMoonKitLauncher."
log "🪵" "GUI install log: ${log_file}"

build_dir="$(cd "${repo_dir}" && swift build -c release --show-bin-path)"
(cd "${repo_dir}" && swift build -c release --product RipperMoonKitLauncher) >> "${log_file}" 2>&1

executable="${build_dir}/RipperMoonKitLauncher"
resource_bundle="${build_dir}/RipperMoonKit_RipperMoonKitLauncher.bundle"

[[ -x "${executable}" ]] || {
  log "❌" "Built executable was not found: ${executable}"
  exit 1
}

[[ -d "${resource_bundle}" ]] || {
  log "❌" "Built resource bundle was not found: ${resource_bundle}"
  exit 1
}

tmp_app="${app_path}.tmp-${stamp}"
rm -rf "${tmp_app}"
mkdir -p "${tmp_app}/Contents/MacOS" "${tmp_app}/Contents/Resources"

install -m 755 "${executable}" "${tmp_app}/Contents/MacOS/RipperMoonKitLauncher"
ditto "${resource_bundle}" "${tmp_app}/RipperMoonKit_RipperMoonKitLauncher.bundle"
ditto "${resource_bundle}" "${tmp_app}/Contents/Resources/RipperMoonKit_RipperMoonKitLauncher.bundle"

cat > "${tmp_app}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>RipperMoonKitLauncher</string>
  <key>CFBundleIdentifier</key>
  <string>com.rippermoon.toolkit.launcher</string>
  <key>CFBundleName</key>
  <string>RipperMoonKit Launcher</string>
  <key>CFBundleDisplayName</key>
  <string>RipperMoonKit</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>${stamp}</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

if [[ -d "${app_path}" ]]; then
  backup="${GPTK_HOME}/backups/gui-app-${stamp}/RipperMoonKit Launcher.app"
  mkdir -p "${backup:h}"
  ditto "${app_path}" "${backup}"
  log "🛟" "Backed up existing GUI app: ${backup}"
  rm -rf "${app_path}"
fi

mv "${tmp_app}" "${app_path}"
log "✅" "Installed GUI app: ${app_path}"
