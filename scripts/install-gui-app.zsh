#!/bin/zsh

set -e
setopt pipe_fail

repo_dir="${0:A:h:h}"
config="${HOME}/.rippermoon-gptk.env"
stamp="$(date +%Y%m%d-%H%M%S)"
variant=""
app_path=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --variant)
      [[ $# -ge 2 ]] || { print -u2 -- "--variant requires a name"; exit 2; }
      variant="$2"
      shift 2
      ;;
    --variant=*)
      variant="${1#--variant=}"
      shift
      ;;
    *)
      app_path="$1"
      shift
      ;;
  esac
done

# Sanitize variant: kebab-case, letters/digits/dash only.
variant_slug="$(print -r -- "${variant}" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9-' '-' | sed -e 's/^-//' -e 's/-$//')"

if [[ -n "${variant}" ]]; then
  app_label="RipperMoonKit Launcher ${variant}"
  bundle_id="com.rippermoon.toolkit.launcher.${variant_slug}"
  display_name="RipperMoonKit ${variant}"
else
  app_label="RipperMoonKit Launcher"
  bundle_id="com.rippermoon.toolkit.launcher"
  display_name="RipperMoonKit"
fi

[[ -n "${app_path}" ]] || app_path="${HOME}/Applications/${app_label}.app"

app_version="${RIPPERMOON_APP_VERSION:-$(<"${repo_dir}/VERSION")}"

if [[ -r "${config}" ]]; then
  source "${config}"
fi

# Force user-scope install only for the stable build; variants are user-scope by default.
if [[ -z "${variant}" && "${app_path}" == /Applications/* ]]; then
  app_path="${HOME}/Applications/${app_label}.app"
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
  local source="${repo_dir}/Sources/RipperMoonKitLauncher/Resources/rippermoonlogo.png"
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
  log "🎨" "Created app icon from rippermoonlogo."
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
  log "🧰" "Bundled toolkit source into the app."
}

bundle_docs() {
  local resources_dir="$1"
  local docs_dir="${resources_dir}/docs"

  rm -rf "${docs_dir}"
  if [[ -d "${repo_dir}/docs" ]]; then
    ditto "${repo_dir}/docs" "${docs_dir}"
    log "📚" "Bundled documentation into the app."
  else
    log "⚠️" "docs folder not found; in-app Help will fall back to GitHub."
  fi
}

# Pick a GPTK runtime for a variant install. Honors the RIPPERMOON_VARIANT_GPTK
# env var (3 or 4) for non-interactive callers; otherwise prompts on a TTY.
choose_variant_gptk_version() {
  local default="${1:-3}"
  local choice="${RIPPERMOON_VARIANT_GPTK:-}"
  if [[ -z "${choice}" && -t 0 ]]; then
    print -u2 -- ""
    print -u2 -- "Which Apple Game Porting Toolkit runtime should this variant use?"
    print -u2 -- "  [3] GPTK 3  — stable, full D3DMetal path. Best for 64-bit games."
    print -u2 -- "  [4] GPTK 4  — Apple beta runtime (no Apple-supplied wine yet; reuses the GPTK 3 wine bundle)."
    print -u2 -n -- "Choice [${default}]: "
    if ! read choice; then choice=""; fi
    choice="${choice:-${default}}"
  fi
  case "${choice}" in
    4|gptk4|"GPTK 4") print -r -- "4" ;;
    *)                print -r -- "3" ;;
  esac
}

# When --variant is set, seed ~/.rippermoon-gptk-<slug>.env with paths under
# ~/GPTK-<slug>, symlink the GPTK app + runtime from the stable install, and
# create the prefix/games directories. Idempotent: existing files are kept.
setup_variant_environment() {
  local variant_home="${HOME}/GPTK-${variant_slug}"
  local variant_env="${HOME}/.rippermoon-gptk-${variant_slug}.env"
  local stable_app="${HOME}/GPTK/apps/Game Porting Toolkit.app"
  local variant_app="${variant_home}/apps/Game Porting Toolkit.app"

  mkdir -p "${variant_home}/apps" "${variant_home}/logs" "${variant_home}/backups" \
           "${HOME}/WinePrefixes-${variant_slug}" "${HOME}/Games-${variant_slug}"

  if [[ -d "${stable_app}" && ! -e "${variant_app}" ]]; then
    ln -s "${stable_app}" "${variant_app}"
    log "🔗" "Linked GPTK app into variant: ${variant_app}"
  fi

  local gptk_version
  gptk_version="$(choose_variant_gptk_version 3)"
  local v3_runtime="${HOME}/GPTK/runtime"
  local v4_runtime="${HOME}/GPTK/runtime-v4"
  local chosen_runtime=""

  case "${gptk_version}" in
    4)
      if [[ -d "${v4_runtime}/lib/wine/x86_64-windows" ]]; then
        chosen_runtime="${v4_runtime}"
      else
        log "⚠️" "GPTK 4 runtime missing at ${v4_runtime}. Mount Apple's GPTK 4 DMG and copy redist/ there first. Falling back to GPTK 3."
        chosen_runtime="${v3_runtime}"
      fi
      ;;
    *)
      chosen_runtime="${v3_runtime}"
      ;;
  esac

  if [[ -d "${chosen_runtime}/lib/wine/x86_64-windows" ]]; then
    rm -f "${variant_home}/runtime" 2>/dev/null
    [[ -e "${variant_home}/runtime" ]] || ln -s "${chosen_runtime}" "${variant_home}/runtime"
    log "🔗" "Linked GPTK ${gptk_version} runtime into variant: ${variant_home}/runtime -> ${chosen_runtime}"
  else
    log "⚠️" "No usable GPTK runtime found at ${chosen_runtime}. Install GPTK before launching the variant."
  fi

  if [[ -e "${variant_env}" ]]; then
    log "📝" "Variant env file already exists, leaving untouched: ${variant_env}"
    return 0
  fi

  # Use a quoted heredoc + explicit literals so values get written as-is rather
  # than picking up stale runtime values from the stable env file we sourced.
  local external_root="${RIPPERMOON_VARIANT_EXTERNAL_ROOT:-${HOME}/Library/Application Support/RipperMoonKit-${variant_slug}}"
  cat > "${variant_env}" <<ENV
# RipperMoonKit ${variant} variant config — managed by install-gui-app.zsh.
# Isolated from the stable launcher's ~/.rippermoon-gptk.env.

export GPTK_HOME="${variant_home}"
export GPTK_PREFIX_ROOT="${HOME}/WinePrefixes-${variant_slug}"
export GPTK_GAMES_ROOT="${HOME}/Games-${variant_slug}"

# External storage root. Defaults to a variant-specific Application Support
# folder so beta state can never overwrite stable files. Point this at a
# mounted external volume in Settings > Paths once your game library lives
# there — the stable launcher uses its own independent value.
export GPTK_EXTERNAL_ROOT="${external_root}"
ENV
  cat >> "${variant_env}" <<'ENV'
export GPTK_STEAM_LIBRARY="$GPTK_EXTERNAL_ROOT/SteamLibrary"
export GPTK_DRIVE_MAPS="S=$GPTK_STEAM_LIBRARY;X=$GPTK_EXTERNAL_ROOT/Games;I=$GPTK_EXTERNAL_ROOT/Installers"

# GPTK runner + runtime are symlinks under $GPTK_HOME; change them to point at
# a different wine app or runtime if you want to test alternatives.
export GPTK_APP_PATH="$GPTK_HOME/apps/Game Porting Toolkit.app"
export GPTK_RUNTIME="$GPTK_HOME/runtime"
export GPTK_WINE_HOME="$GPTK_APP_PATH/Contents/Resources/wine"

export GPTK_DEFAULT_WINVER="win10"
export GPTK_LOG_ENABLED="1"
export GPTK_WINEESYNC="1"
export GPTK_DXR="1"
export GPTK_USE_DXVK="0"
export GPTK_MTL_HUD_ENABLED="0"
ENV
  log "📝" "Created variant env file: ${variant_env}"
  log "🧪" "Variant '${variant}' is wired to GPTK ${gptk_version}. Override RIPPERMOON_VARIANT_GPTK=3|4 next time to skip the prompt."
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
ditto "${resource_bundle}" "${tmp_app}/Contents/Resources/RipperMoonKit_RipperMoonKitLauncher.bundle"
create_app_icon "${tmp_app}/Contents/Resources"
bundle_toolkit "${tmp_app}/Contents/Resources"
bundle_docs "${tmp_app}/Contents/Resources"

cat > "${tmp_app}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>RipperMoonKitLauncher</string>
  <key>CFBundleIdentifier</key>
  <string>${bundle_id}</string>
  <key>CFBundleName</key>
  <string>${app_label}</string>
  <key>CFBundleDisplayName</key>
  <string>${display_name}</string>
  <key>CFBundleIconFile</key>
  <string>RipperMoonKitLogo</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${app_version#v}</string>
  <key>CFBundleVersion</key>
  <string>${stamp}</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

if command -v codesign >/dev/null 2>&1; then
  log "✍️" "Applying ad-hoc app signature."
  codesign --force --deep --sign - "${tmp_app}" >> "${log_file}" 2>&1 || {
    log "❌" "Ad-hoc signing failed."
    exit 1
  }
  codesign --verify --deep --strict --verbose=2 "${tmp_app}" >> "${log_file}" 2>&1 || {
    log "❌" "Ad-hoc signature verification failed."
    exit 1
  }
  log "✅" "Applied and verified ad-hoc app signature."
fi

if [[ -d "${app_path}" ]]; then
  backup_tag="gui-app${variant:+-${variant_slug}}-${stamp}"
  backup="${GPTK_HOME}/backups/${backup_tag}.noindex/${app_path:t}.backup"
  mkdir -p "${backup:h}"
  ditto "${app_path}" "${backup}"
  log "🛟" "Backed up existing GUI app: ${backup}"
  rm -rf "${app_path}"
fi

mv "${tmp_app}" "${app_path}"
log "✅" "Installed GUI app: ${app_path}"

system_app="/Applications/RipperMoonKit Launcher.app"
system_alias="/Applications/RipperMoonKit Launcher.app alias"
lsregister="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

# Variant installs leave the stable install alone — they intentionally
# coexist with the stable launcher under a different bundle ID.
if [[ -z "${variant}" && "${app_path}" != "${system_app}" && (-d "${system_app}" || -L "${system_app}") ]]; then
  system_backup="${GPTK_HOME}/backups/gui-app-system-${stamp}.noindex/RipperMoonKit Launcher.app.backup"
  mkdir -p "${system_backup:h}"
  if ditto "${system_app}" "${system_backup}" 2>/dev/null; then
    log "🧹" "Backed up stale system-wide install: ${system_backup}"
  else
    log "⚠️" "Could not back up ${system_app}; continuing with removal."
  fi
  if rm -rf "${system_app}" 2>/dev/null; then
    log "🧹" "Removed stale system-wide install: ${system_app}"
  else
    log "⚠️" "Could not remove ${system_app} (permission denied). Remove it manually: sudo rm -rf \"${system_app}\""
  fi
  [[ -x "${lsregister}" ]] && "${lsregister}" -u "${system_app}" >/dev/null 2>&1 || true
fi

if [[ -z "${variant}" && (-e "${system_alias}" || -L "${system_alias}") ]]; then
  rm -f "${system_alias}" 2>/dev/null && log "🧹" "Removed stale system-wide alias: ${system_alias}" || \
    log "⚠️" "Could not remove alias ${system_alias}; remove it manually."
fi

[[ -x "${lsregister}" ]] && "${lsregister}" -f "${app_path}" >/dev/null 2>&1 || true

if [[ -n "${variant}" ]]; then
  setup_variant_environment
  log "🧪" "Installed variant '${variant}' with bundle id ${bundle_id}. This build reads ~/.rippermoon-gptk-${variant_slug}.env, isolated from the stable launcher."
fi
