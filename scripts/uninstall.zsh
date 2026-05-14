#!/bin/zsh

set -e
setopt pipe_fail

config="${HOME}/.rippermoon-gptk.env"
remove_config=0
remove_prefixes=0
remove_app=1
app_path="${HOME}/Applications/RipperMoonKit Launcher.app"
stamp="$(date +%Y%m%d-%H%M%S)"

usage() {
  cat <<'USAGE'
Usage:
  zsh scripts/uninstall.zsh [options]

Options:
  --remove-config       Remove ~/.rippermoon-gptk.env after backing it up
  --remove-prefixes     Remove $GPTK_PREFIX_ROOT after backing up metadata only
  --keep-app            Do not remove the local .app bundle
  --app PATH            App bundle to remove
  -h, --help            Show this help

Defaults keep user configuration, Wine prefixes, saves, games, Steam data,
GPTK runtimes, and patched runners.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --remove-config)
      remove_config=1
      shift
      ;;
    --remove-prefixes)
      remove_prefixes=1
      shift
      ;;
    --keep-app)
      remove_app=0
      shift
      ;;
    --app)
      [[ $# -ge 2 ]] || {
        print -u2 -- "--app requires a path"
        exit 2
      }
      app_path="$2"
      shift 2
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

if [[ -r "${config}" ]]; then
  source "${config}"
fi

GPTK_HOME="${GPTK_HOME:-${HOME}/GPTK}"
GPTK_LOG_DIR="${GPTK_LOG_DIR:-${GPTK_HOME}/logs}"
GPTK_PREFIX_ROOT="${GPTK_PREFIX_ROOT:-${HOME}/WinePrefixes}"
install_bin="${HOME}/bin"
install_libexec="${GPTK_HOME}/libexec"
backup_dir="${GPTK_HOME}/backups/uninstall-${stamp}"
log_file="${GPTK_LOG_DIR}/rippermoon-uninstall-${stamp}.log"

mkdir -p "${GPTK_LOG_DIR}" "${backup_dir}"

log() {
  local icon="$1"
  shift
  printf '%s [%s] %s\n' "${icon}" "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "${log_file}"
}

safe_rm() {
  local path="$1"
  local label="$2"

  [[ -n "${path}" && -e "${path}" ]] || {
    log "ℹ️" "No ${label} found: ${path}"
    return 0
  }

  case "${path:A}" in
    "/"|"${HOME:A}"|"/Users"|"/Users/"*"/.."|"/Volumes"|"/Volumes/"*"/..")
      log "❌" "Refusing to remove unsafe ${label} path: ${path}"
      return 1
      ;;
  esac

  rm -rf "${path}"
  log "🧹" "Removed ${label}: ${path}"
}

backup_if_exists() {
  local path="$1"
  local label="$2"
  local target="${backup_dir}/${path#/}"
  target="${target//\//__}"

  [[ -e "${path}" ]] || return 0

  if [[ -d "${path}" ]]; then
    ditto "${path}" "${target}"
  else
    cp -p "${path}" "${target}"
  fi
  log "🛟" "Backed up ${label}: ${path}"
}

log "🚀" "Starting RipperMoonKit uninstall."
log "🪵" "Uninstall log: ${log_file}"

backup_if_exists "${install_bin}/gptk-launch" "launcher"
backup_if_exists "${install_bin}/gptk-steam" "Steam launcher"
backup_if_exists "${install_bin}/gptk-game" "game helper"
backup_if_exists "${install_libexec}/gptk-common.zsh" "shared helper"
backup_if_exists "${config}" "config"

{
  print -r -- "GPTK_HOME=${GPTK_HOME}"
  print -r -- "GPTK_PREFIX_ROOT=${GPTK_PREFIX_ROOT}"
  print -r -- "App=${app_path}"
  print -r -- "Removed config=${remove_config}"
  print -r -- "Removed prefixes=${remove_prefixes}"
} > "${backup_dir}/uninstall-manifest.txt"

safe_rm "${install_bin}/gptk-launch" "launcher"
safe_rm "${install_bin}/gptk-steam" "Steam launcher"
safe_rm "${install_bin}/gptk-game" "game helper"
safe_rm "${install_libexec}/gptk-common.zsh" "shared helper"

if [[ "${remove_app}" == "1" ]]; then
  backup_if_exists "${app_path}" "app bundle"
  safe_rm "${app_path}" "app bundle"
fi

if [[ "${remove_config}" == "1" ]]; then
  safe_rm "${config}" "config"
else
  log "✅" "Kept config: ${config}"
fi

if [[ "${remove_prefixes}" == "1" ]]; then
  log "⚠️" "Removing Wine prefixes also removes prefix-local saves and app data."
  safe_rm "${GPTK_PREFIX_ROOT}" "Wine prefix root"
else
  log "✅" "Kept Wine prefixes and saves: ${GPTK_PREFIX_ROOT}"
fi

log "✅" "Uninstall complete."
