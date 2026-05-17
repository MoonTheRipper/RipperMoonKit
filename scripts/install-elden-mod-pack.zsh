#!/bin/zsh

set -e
setopt pipe_fail

config="${HOME}/.rippermoon-gptk.env"
env_gptk_home="${GPTK_HOME:-}"
env_gptk_log_dir="${GPTK_LOG_DIR:-}"
env_gptk_external_root="${GPTK_EXTERNAL_ROOT:-}"
[[ -r "${config}" ]] && source "${config}"
[[ -n "${env_gptk_home}" ]] && GPTK_HOME="${env_gptk_home}"
[[ -n "${env_gptk_log_dir}" ]] && GPTK_LOG_DIR="${env_gptk_log_dir}"
[[ -n "${env_gptk_external_root}" ]] && GPTK_EXTERNAL_ROOT="${env_gptk_external_root}"
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"

GPTK_HOME="${GPTK_HOME:-${HOME}/GPTK}"
GPTK_LOG_DIR="${GPTK_LOG_DIR:-${GPTK_HOME}/logs}"
GPTK_EXTERNAL_ROOT="${GPTK_EXTERNAL_ROOT:-/Volumes/GameCoreApp}"

repo_url="${RIPPERMOON_ERCOOP_REPO_URL:-git@github.com:MoonTheRipper/elden-randomizer-coop.git}"
profile_repo="${RIPPERMOON_ERCOOP_REPO:-${GPTK_HOME}/tools/elden-randomizer-coop}"
game_dir=""
inputs_dir=""
open_pages=0
force=0
no_anticheat=0
prepare_only=0

usage() {
  cat <<'USAGE'
Usage:
  scripts/install-elden-mod-pack.zsh --game-dir PATH [options]

Options:
  --game-dir PATH          Elden Ring Game folder containing eldenring.exe
  --inputs-dir PATH        Folder containing downloaded mod ZIPs
  --profile-repo PATH      Existing elden-randomizer-coop clone/path to use
  --repo-url URL           Git URL used when cloning the setup reference repo
  --open-download-pages    Open ModEngine/Randomizer/Seamless download pages
  --force                  Reinstall tools even if marker files already exist
  --no-anticheat           Do not install Anti Cheat Toggler even if provided
  --prepare-only           Only write config_eldenring.toml and launch bat
  -h, --help               Show this help

The script is a native macOS/GPTK wrapper around the same setup shape as the
Windows ercoop installer. It does not run PowerShell. It installs selected ZIPs
and writes GPTK-local ModEngine files for the current machine.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --game-dir)
      game_dir="$2"
      shift 2
      ;;
    --inputs-dir)
      inputs_dir="$2"
      shift 2
      ;;
    --profile-repo)
      profile_repo="$2"
      shift 2
      ;;
    --repo-url)
      repo_url="$2"
      shift 2
      ;;
    --open-download-pages)
      open_pages=1
      shift
      ;;
    --force)
      force=1
      shift
      ;;
    --no-anticheat)
      no_anticheat=1
      shift
      ;;
    --prepare-only)
      prepare_only=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      print -u2 -- "unknown option: $1"
      usage
      exit 2
      ;;
  esac
done

stamp="$(date +%Y%m%d-%H%M%S)"
mkdir -p "${GPTK_LOG_DIR}"
log_file="${GPTK_LOG_DIR}/elden-mod-pack-${stamp}.log"

log() {
  local icon="$1"
  shift
  printf '%s [%s] %s\n' "${icon}" "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "${log_file}"
}

die() {
  log "❌" "$*"
  exit 1
}

backup_file() {
  local file_path="$1"
  [[ -f "${file_path}" ]] || return 0
  local backup="${file_path}.${stamp}.bak"
  cp -p "${file_path}" "${backup}"
  log "🛟" "Backed up ${file_path} -> ${backup}"
}

mac_to_wine_path() {
  local mac_path="${1:A}"
  mac_path="${mac_path#/}"
  print -r -- "Z:\\${mac_path//\//\\}"
}

ensure_profile_repo() {
  if [[ -d "${profile_repo}/.git" ]]; then
    log "🔄" "Updating setup reference repo: ${profile_repo}"
    git -C "${profile_repo}" fetch --tags --quiet origin >> "${log_file}" 2>&1 || true
    git -C "${profile_repo}" pull --ff-only --quiet origin main >> "${log_file}" 2>&1 || true
    return 0
  fi

  if [[ -d "${profile_repo}" && -f "${profile_repo}/links.json" ]]; then
    log "📁" "Using local setup reference repo: ${profile_repo}"
    return 0
  fi

  log "⬇️" "Cloning setup reference repo: ${repo_url}"
  mkdir -p "${profile_repo:h}"
  git clone "${repo_url}" "${profile_repo}" >> "${log_file}" 2>&1
}

open_download_pages() {
  [[ "${open_pages}" == "1" ]] || return 0
  log "🌐" "Opening mod download pages."
  open "https://github.com/soulsmods/ModEngine2/releases/latest" || true
  open "https://www.nexusmods.com/eldenring/mods/428?tab=files" || true
  open "https://www.nexusmods.com/eldenring/mods/510?tab=files" || true
  if [[ "${no_anticheat}" != "1" ]]; then
    open "https://www.nexusmods.com/eldenring/mods/90?tab=files" || true
  fi
}

zip_has() {
  local zip="$1"
  local marker="$2"
  unzip -Z1 "${zip}" 2>/dev/null | grep -qi -- "${marker}"
}

cleanup_mac_sidecars() {
  local path="$1"
  [[ -d "${path}" ]] || return 0
  find "${path}" \( -name '._*' -o -name '.DS_Store' -o -name '__MACOSX' \) -print -exec rm -rf {} + >> "${log_file}" 2>&1 || true
}

flatten_single_root() {
  local dest="$1"
  local marker="$2"
  local item
  [[ -f "${dest}/${marker}" ]] && return 0
  local root
  root="$(find "${dest}" -mindepth 1 -maxdepth 1 -type d -print | head -n 1)"
  if [[ -n "${root}" && -f "${root}/${marker}" ]]; then
    for item in "${root}"/*(DN); do
      [[ "${item:t}" == ._* ]] && continue
      mv -f "${item}" "${dest}/"
    done
    rmdir "${root}" 2>/dev/null || true
  fi
}

flatten_marker_parent() {
  local source="$1"
  local dest="$2"
  local marker="$3"
  local marker_path
  local marker_parent
  local item

  marker_path="$(find "${source}" -name "${marker}" -type f -print | head -n 1)"
  [[ -n "${marker_path}" ]] || return 1
  marker_parent="${marker_path:h}"
  mkdir -p "${dest}"
  for item in "${marker_parent}"/*(DN); do
    [[ "${item:t}" == ._* ]] && continue
    mv -f "${item}" "${dest}/"
  done
  return 0
}

flatten_existing_modengine_child() {
  local modengine="$1"
  local child
  local item
  for child in "${modengine}"/*(N/); do
    [[ "${child:t}" == "randomizer" ]] && continue
    if [[ -f "${child}/modengine2_launcher.exe" ]]; then
      log "🧹" "Flattening nested ModEngine folder: ${child}"
      for item in "${child}"/*(DN); do
        [[ "${item:t}" == ._* ]] && continue
        mv -f "${item}" "${modengine}/"
      done
      rmdir "${child}" 2>/dev/null || true
      return 0
    fi
  done
}

install_modengine() {
  local zip="$1"
  local modengine="$2"
  flatten_existing_modengine_child "${modengine}"
  if [[ "${force}" != "1" && -f "${modengine}/modengine2_launcher.exe" ]]; then
    log "ℹ️" "ModEngine 2 already present; skipping."
    return 0
  fi
  log "📦" "Installing ModEngine 2 from ${zip}"
  local tmp="${modengine}/.modengine-install-${stamp}"
  rm -rf "${tmp}"
  mkdir -p "${modengine}"
  mkdir -p "${tmp}"
  unzip -oq "${zip}" -d "${tmp}" >> "${log_file}" 2>&1
  cleanup_mac_sidecars "${tmp}"
  flatten_marker_parent "${tmp}" "${modengine}" "modengine2_launcher.exe" || true
  rm -rf "${tmp}"
  cleanup_mac_sidecars "${modengine}"
  [[ -f "${modengine}/modengine2_launcher.exe" ]] || die "ModEngine install failed: modengine2_launcher.exe missing"
}

install_randomizer() {
  local zip="$1"
  local modengine="$2"
  local target="${modengine}/randomizer"
  if [[ "${force}" != "1" && -f "${target}/EldenRingRandomizer.exe" ]]; then
    log "ℹ️" "Randomizer already present; skipping."
    return 0
  fi
  log "📦" "Installing Item and Enemy Randomizer from ${zip}"
  local tmp="${modengine}/.randomizer-install-${stamp}"
  [[ -d "${target}" ]] && mv "${target}" "${target}.${stamp}.backup"
  rm -rf "${tmp}"
  mkdir -p "${tmp}"
  unzip -oq "${zip}" -d "${tmp}" >> "${log_file}" 2>&1
  cleanup_mac_sidecars "${tmp}"
  local root
  root="$(find "${tmp}" -mindepth 1 -maxdepth 1 -type d -print | head -n 1)"
  if [[ -n "${root}" && -f "${root}/EldenRingRandomizer.exe" ]]; then
    mv "${root}" "${target}"
  else
    mkdir -p "${target}"
    find "${tmp}" -mindepth 1 -maxdepth 1 -exec mv -f {} "${target}/" \;
  fi
  rm -rf "${tmp}"
  cleanup_mac_sidecars "${target}"
  [[ -f "${target}/EldenRingRandomizer.exe" ]] || die "Randomizer install failed: EldenRingRandomizer.exe missing"
}

install_seamless() {
  local zip="$1"
  local game="$2"
  if [[ "${force}" != "1" && -f "${game}/SeamlessCoop/ersc.dll" ]]; then
    log "ℹ️" "Seamless Coop already present; skipping."
    return 0
  fi
  log "📦" "Installing Seamless Coop from ${zip}"
  local keep=""
  if [[ -f "${game}/SeamlessCoop/ersc_settings.ini" ]]; then
    keep="$(mktemp -t ersc-settings.XXXXXX)"
    cp -p "${game}/SeamlessCoop/ersc_settings.ini" "${keep}"
  fi
  unzip -oq "${zip}" -d "${game}" >> "${log_file}" 2>&1
  cleanup_mac_sidecars "${game}/SeamlessCoop"
  if [[ -n "${keep}" && -s "${keep}" ]]; then
    mkdir -p "${game}/SeamlessCoop"
    cp -p "${keep}" "${game}/SeamlessCoop/ersc_settings.ini"
    rm -f "${keep}"
    log "🛟" "Preserved existing Seamless Coop settings."
  fi
  [[ -f "${game}/SeamlessCoop/ersc.dll" ]] || die "Seamless install failed: ersc.dll missing"
}

install_anticheat() {
  local zip="$1"
  local game="$2"
  [[ "${no_anticheat}" == "1" ]] && return 0
  if [[ "${force}" != "1" && -f "${game}/toggle_anti_cheat.exe" ]]; then
    log "ℹ️" "Anti Cheat Toggler already present; skipping."
    return 0
  fi
  log "📦" "Installing Anti Cheat Toggler from ${zip}"
  unzip -oq "${zip}" -d "${game}" >> "${log_file}" 2>&1
  cleanup_mac_sidecars "${game}"
}

install_zips() {
  local game="$1"
  local modengine="$2"
  local inputs="$3"
  [[ -d "${inputs}" ]] || die "Inputs folder not found: ${inputs}"

  local found=0
  for zip in "${inputs}"/*.zip(N); do
    found=1
    if zip_has "${zip}" "modengine2_launcher.exe"; then
      install_modengine "${zip}" "${modengine}"
    elif zip_has "${zip}" "EldenRingRandomizer.exe"; then
      install_randomizer "${zip}" "${modengine}"
    elif zip_has "${zip}" "ersc_launcher.exe" || zip_has "${zip}" "ersc.dll"; then
      install_seamless "${zip}" "${game}"
    elif zip_has "${zip}" "toggle_anti_cheat.exe"; then
      install_anticheat "${zip}" "${game}"
    else
      log "⚠️" "Skipped unrecognized ZIP: ${zip}"
    fi
  done
  [[ "${found}" == "1" ]] || log "⚠️" "No ZIPs found in ${inputs}"
}

write_modengine_files() {
  local game="$1"
  local modengine="$2"
  mkdir -p "${modengine}/mod" "${modengine}/randomizer"

  local cfg="${modengine}/config_eldenring.toml"
  local bat="${modengine}/launchmod_eldenring.bat"
  local game_wine
  game_wine="$(mac_to_wine_path "${game}/eldenring.exe")"

  backup_file "${cfg}"
  cat > "${cfg}" <<'TOML'
[modengine]
debug = false

external_dlls = [
    "../SeamlessCoop/ersc.dll"
]

[extension.mod_loader]
enabled = true
loose_params = false

mods = [
    { enabled = true, name = "default", path = "mod" },
    { enabled = true, name = "randomizer", path = "randomizer" }
]

[extension.scylla_hide]
enabled = false
TOML
  log "✅" "Wrote ${cfg}"

  backup_file "${bat}"
  cat > "${bat}" <<BAT
@echo off
chcp 65001
.\\modengine2_launcher.exe -t er -c .\\config_eldenring.toml --game-path "${game_wine}"
BAT
  log "✅" "Wrote ${bat}"
}

[[ -n "${game_dir}" ]] || die "--game-dir is required"
game_dir="${game_dir:A}"
[[ -f "${game_dir}/eldenring.exe" ]] || die "eldenring.exe not found in ${game_dir}"

if [[ -z "${inputs_dir}" ]]; then
  ensure_profile_repo
  inputs_dir="${profile_repo}/inputs"
elif [[ "${open_pages}" == "1" ]]; then
  ensure_profile_repo
fi
modengine_dir="${game_dir}/ModEngine2"

log "🎮" "Game folder: ${game_dir}"
log "🧩" "ModEngine folder: ${modengine_dir}"
log "📝" "Log file: ${log_file}"

open_download_pages

if [[ "${prepare_only}" != "1" ]]; then
  install_zips "${game_dir}" "${modengine_dir}" "${inputs_dir}"
fi

write_modengine_files "${game_dir}" "${modengine_dir}"

log "✅" "Elden Ring ModEngine + Randomizer profile setup finished."
log "ℹ️" "Next: run the randomizer GUI, import .randomizeopt, click Randomize, then launch through ModEngine."
