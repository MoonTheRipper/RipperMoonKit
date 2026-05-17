#!/bin/zsh

set -e
setopt pipe_fail

repo_dir="${0:A:h:h}"
version="${1:-v$(<"${repo_dir}/VERSION")}"
dist_dir="${repo_dir}/dist.noindex"
work_dir="${dist_dir}/work-${version}.noindex"
app_name="RipperMoonKit Launcher.app"
app_path="${work_dir}/${app_name}"
dmg_path="${dist_dir}/RipperMoonKit-Launcher.dmg"
source_zip="${dist_dir}/RipperMoonKit-source.zip"
log_file="${dist_dir}/package-${version}.log"

log() {
  local icon="$1"
  shift
  printf '%s [%s] %s\n' "${icon}" "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "${log_file}"
}

create_app_icon() {
  local resources_dir="$1"
  local source="${repo_dir}/Sources/RipperMoonKitLauncher/Resources/rippermoonlogo.png"
  local work
  local iconset
  local base
  local name
  local size

  work="$(mktemp -d "${TMPDIR:-/tmp}/rippermoon-icon.XXXXXX")"
  iconset="${work}/RipperMoonKitLogo.iconset"
  base="${work}/RipperMoonKitLogo-square.png"
  mkdir -p "${iconset}"

  sips -s format png -z 1024 1024 "${source}" --out "${base}" >> "${log_file}" 2>&1

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
  cp -p "${source}" "${resources_dir}/rippermoonlogo.png"
  rm -rf "${work}"
}

mkdir -p "${dist_dir}"
: > "${log_file}"

log "🚀" "Packaging RipperMoonKit ${version}."
rm -rf "${work_dir}" "${dmg_path}" "${source_zip}"
mkdir -p "${app_path}/Contents/MacOS" "${app_path}/Contents/Resources"

log "🧱" "Building release executable."
build_dir="$(cd "${repo_dir}" && swift build -c release --show-bin-path)"
(cd "${repo_dir}" && swift build -c release --product RipperMoonKitLauncher) >> "${log_file}" 2>&1

executable="${build_dir}/RipperMoonKitLauncher"
resource_bundle="${build_dir}/RipperMoonKit_RipperMoonKitLauncher.bundle"

[[ -x "${executable}" ]] || {
  log "❌" "Built executable not found: ${executable}"
  exit 1
}

[[ -d "${resource_bundle}" ]] || {
  log "❌" "Resource bundle not found: ${resource_bundle}"
  exit 1
}

install -m 755 "${executable}" "${app_path}/Contents/MacOS/RipperMoonKitLauncher"
ditto "${resource_bundle}" "${app_path}/RipperMoonKit_RipperMoonKitLauncher.bundle"
ditto "${resource_bundle}" "${app_path}/Contents/Resources/RipperMoonKit_RipperMoonKitLauncher.bundle"
create_app_icon "${app_path}/Contents/Resources"

cat > "${app_path}/Contents/Info.plist" <<PLIST
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
  <string>${version#v}</string>
  <key>CFBundleVersion</key>
  <string>${version#v}</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

if command -v codesign >/dev/null 2>&1; then
  log "✍️" "Applying ad-hoc app signature."
  if codesign --force --deep --sign - "${app_path}" >> "${log_file}" 2>&1; then
    log "✅" "Applied ad-hoc app signature."
  else
    log "⚠️" "Ad-hoc signing was skipped; SwiftPM resource bundles must remain at the app root for this build."
  fi
fi

log "💿" "Creating DMG."
ln -s /Applications "${work_dir}/Applications"
hdiutil create \
  -volname "RipperMoonKit ${version}" \
  -srcfolder "${work_dir}" \
  -ov \
  -format UDZO \
  "${dmg_path}" >> "${log_file}" 2>&1

log "🗜️" "Creating source ZIP from git."
(cd "${repo_dir}" && git archive --format=zip --prefix="RipperMoonKit-${version}/" -o "${source_zip}" HEAD)

log "✅" "DMG: ${dmg_path}"
log "✅" "Source ZIP: ${source_zip}"
