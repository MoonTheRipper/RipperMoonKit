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

create_app_icon() {
  local resources_dir="$1"
  local source="${repo_dir}/Sources/RipperMoonKitLauncher/Resources/RipperMoonKitLogo.jpg"
  local work
  local iconset
  local base
  local name
  local size

  if [[ ! -f "${source}" ]]; then
    log "⚠️" "App icon source was not found: ${source}"
    return 0
  fi

  if ! command -v sips >/dev/null 2>&1 || ! command -v iconutil >/dev/null 2>&1; then
    log "⚠️" "sips or iconutil is missing; app icon generation skipped."
    return 0
  fi

  work="$(mktemp -d "${TMPDIR:-/tmp}/rippermoon-icon.XXXXXX")"
  iconset="${work}/RipperMoonKitLogo.iconset"
  base="${work}/RipperMoonKitLogo-square.png"
  mkdir -p "${iconset}"

  sips -s format png -c 1080 1080 "${source}" --out "${base}" >> "${log_file}" 2>&1

  for name size in \
    icon_16x16.png 16 \
    icon_16x16@2x.png 32 \
    icon_32x32.png 32 \
    icon_32x32@2x.png 64 \
    icon_128x128.png 128 \
    icon_128x128@2x.png 256 \
    icon_256x256.png 256 \
    icon_256x256@2x.png 512 \
    icon_512x512.png 512 \
    icon_512x512@2x.png 1024
  do
    sips -s format png -z "${size}" "${size}" "${base}" --out "${iconset}/${name}" >> "${log_file}" 2>&1
  done

  iconutil -c icns "${iconset}" -o "${resources_dir}/RipperMoonKitLogo.icns" >> "${log_file}" 2>&1
  cp -p "${source}" "${resources_dir}/RipperMoonKitLogo.jpg"
  rm -rf "${work}"
  log "🎨" "Created app icon from RipperMoonKitLogo."
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
create_app_icon "${tmp_app}/Contents/Resources"

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
  <key>CFBundleIconFile</key>
  <string>RipperMoonKitLogo</string>
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
