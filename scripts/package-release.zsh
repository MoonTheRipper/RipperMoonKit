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

bundle_toolkit() {
  local resources_dir="$1"
  local toolkit_dir="${resources_dir}/toolkit"
  local dir

  rm -rf "${toolkit_dir}"
  mkdir -p "${toolkit_dir}"

  install -m 755 "${repo_dir}/install.zsh" "${toolkit_dir}/install.zsh"
  install -m 644 "${repo_dir}/env.example" "${toolkit_dir}/env.example"
  install -m 644 "${repo_dir}/VERSION" "${toolkit_dir}/VERSION"

  for dir in bin libexec scripts stubs; do
    [[ -d "${repo_dir}/${dir}" ]] && ditto "${repo_dir}/${dir}" "${toolkit_dir}/${dir}"
  done

  chmod +x "${toolkit_dir}/install.zsh" "${toolkit_dir}/scripts/"*.zsh "${toolkit_dir}/bin/"* 2>/dev/null || true
  log "🧰" "Bundled toolkit source into the app: ${toolkit_dir}"
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
ditto "${resource_bundle}" "${app_path}/Contents/Resources/RipperMoonKit_RipperMoonKitLauncher.bundle"
create_app_icon "${app_path}/Contents/Resources"
bundle_toolkit "${app_path}/Contents/Resources"

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
  codesign --force --deep --sign - "${app_path}" >> "${log_file}" 2>&1 || {
    log "❌" "Ad-hoc signing failed; refusing to package an invalid app."
    exit 1
  }
  codesign --verify --deep --strict --verbose=2 "${app_path}" >> "${log_file}" 2>&1 || {
    log "❌" "Ad-hoc signature verification failed."
    exit 1
  }
  log "✅" "Applied and verified ad-hoc app signature."
fi

log "💿" "Creating DMG."
ln -s /Applications "${work_dir}/Applications"
hdiutil create \
  -volname "RipperMoonKit ${version}" \
  -srcfolder "${work_dir}" \
  -ov \
  -format UDZO \
  "${dmg_path}" >> "${log_file}" 2>&1
hdiutil verify "${dmg_path}" >> "${log_file}" 2>&1 || {
  log "❌" "DMG verification failed."
  exit 1
}
log "✅" "Verified DMG image."

log "🗜️" "Creating source ZIP from git."
(cd "${repo_dir}" && git archive --format=zip --prefix="RipperMoonKit-${version}/" -o "${source_zip}" HEAD)

log "✅" "DMG: ${dmg_path}"
log "✅" "Source ZIP: ${source_zip}"
