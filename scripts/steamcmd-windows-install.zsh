#!/bin/zsh

set -e
setopt pipe_fail

SCRIPT_DIR="${0:A:h}"
COMMON="${GPTK_COMMON:-${HOME}/GPTK/libexec/gptk-common.zsh}"
[[ -r "${COMMON}" ]] || COMMON="${SCRIPT_DIR:h}/libexec/gptk-common.zsh"
source "${COMMON}"
gptk_raise_file_limit

usage() {
  cat <<'USAGE'
Usage:
  steamcmd-windows-install.zsh --appid APPID [options]

Downloads Windows SteamPipe content with native SteamCMD instead of the Windows
Steam GUI running under GPTK/Wine. This is an experimental fallback for games
whose Steam GUI install reaches "Corrupt download" during depot unpacking.

Options:
  --appid APPID              Steam AppID to install. Required.
  --login USERNAME           Steam account login. Use --anonymous for anonymous.
  --anonymous                Log in anonymously.
  --target-root PATH         Parent folder for installs. Default: GPTK_STEAMCMD_LIBRARY.
  --install-dir PATH         Exact install folder. Overrides --target-root.
  --name NAME                Folder name under target root. Default: App-APPID.
  --platform windows         SteamCMD platform. Default: windows.
  --beta NAME                Optional beta branch.
  --beta-password PASSWORD   Optional beta branch password.
  --no-validate              Skip SteamCMD validation.
  --steamcmd-dir PATH        Native SteamCMD folder. Default: GPTK/tools/steamcmd-osx.
  --log-file PATH            Log path. Default: GPTK/logs/steamcmd-windows-APPID-*.log.
  -h, --help                 Show this help.

Examples:
  gptk-steamcmd --appid 1196590 --login USERNAME --target-root /Volumes/GAMECORE-1/SteamCMDLibrary
  zsh scripts/steamcmd-windows-install.zsh --appid 480 --anonymous
USAGE
}

appid=""
login=""
target_root="${GPTK_STEAMCMD_LIBRARY:-${GPTK_EXTERNAL_ROOT}/SteamCMDLibrary}"
install_dir=""
install_name=""
platform="windows"
beta=""
beta_password=""
validate=1
steamcmd_dir="${GPTK_HOME}/tools/steamcmd-osx"
log_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --appid)
      [[ $# -ge 2 ]] || gptk_die "--appid requires a value"
      appid="$2"
      shift 2
      ;;
    --login)
      [[ $# -ge 2 ]] || gptk_die "--login requires a username"
      login="$2"
      shift 2
      ;;
    --anonymous)
      login="anonymous"
      shift
      ;;
    --target-root)
      [[ $# -ge 2 ]] || gptk_die "--target-root requires a path"
      target_root="$2"
      shift 2
      ;;
    --install-dir)
      [[ $# -ge 2 ]] || gptk_die "--install-dir requires a path"
      install_dir="$2"
      shift 2
      ;;
    --name)
      [[ $# -ge 2 ]] || gptk_die "--name requires a folder name"
      install_name="$2"
      shift 2
      ;;
    --platform)
      [[ $# -ge 2 ]] || gptk_die "--platform requires a value"
      platform="$2"
      shift 2
      ;;
    --beta)
      [[ $# -ge 2 ]] || gptk_die "--beta requires a branch name"
      beta="$2"
      shift 2
      ;;
    --beta-password)
      [[ $# -ge 2 ]] || gptk_die "--beta-password requires a value"
      beta_password="$2"
      shift 2
      ;;
    --no-validate)
      validate=0
      shift
      ;;
    --steamcmd-dir)
      [[ $# -ge 2 ]] || gptk_die "--steamcmd-dir requires a path"
      steamcmd_dir="$2"
      shift 2
      ;;
    --log-file)
      [[ $# -ge 2 ]] || gptk_die "--log-file requires a path"
      log_file="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      gptk_die "unknown option: $1"
      ;;
  esac
done

[[ -n "${appid}" ]] || {
  usage
  exit 2
}
[[ "${appid}" == <-> ]] || gptk_die "AppID must be numeric: ${appid}"

if [[ -z "${login}" && -t 0 ]]; then
  print -rn -- "Steam username for AppID ${appid} (or anonymous): "
  read -r login
fi
[[ -n "${login}" ]] || gptk_die "Steam login is required. Use --login USERNAME or --anonymous."

[[ -n "${install_name}" ]] || install_name="App-${appid}"
[[ -n "${install_dir}" ]] || install_dir="${target_root}/${install_name}"

if [[ -z "${log_file}" ]]; then
  mkdir -p "${GPTK_LOG_DIR}"
  log_file="${GPTK_LOG_DIR}/steamcmd-windows-${appid}-$(date +%Y%m%d-%H%M%S).log"
fi
mkdir -p "${log_file:h}" "${install_dir}" "${steamcmd_dir}"

log() {
  printf '%s [%s] %s\n' "$1" "$(date '+%Y-%m-%d %H:%M:%S')" "$2" | tee -a "${log_file}"
}

ensure_steamcmd() {
  local tarball="${steamcmd_dir}/steamcmd_osx.tar.gz"
  local url="${STEAMCMD_OSX_URL:-https://steamcdn-a.akamaihd.net/client/installer/steamcmd_osx.tar.gz}"

  if [[ -x "${steamcmd_dir}/steamcmd.sh" ]]; then
    log "✅" "Native SteamCMD already exists: ${steamcmd_dir}/steamcmd.sh"
    return 0
  fi

  command -v curl >/dev/null 2>&1 || gptk_die "curl is required to download SteamCMD"
  log "⬇️" "Downloading native SteamCMD from ${url}"
  curl -fL --retry 3 --connect-timeout 30 -o "${tarball}.download" "${url}" >> "${log_file}" 2>&1
  mv "${tarball}.download" "${tarball}"

  log "📦" "Unpacking SteamCMD into ${steamcmd_dir}"
  tar -xzf "${tarball}" -C "${steamcmd_dir}" >> "${log_file}" 2>&1
  chmod +x "${steamcmd_dir}/steamcmd.sh" 2>/dev/null || true
  [[ -x "${steamcmd_dir}/steamcmd.sh" ]] || gptk_die "SteamCMD unpacked, but steamcmd.sh is missing"
}

run_steamcmd() {
  local script="${steamcmd_dir}/steamcmd.sh"
  if [[ "$(uname -m)" == "arm64" ]]; then
    arch -x86_64 /bin/bash "${script}" "$@"
  else
    /bin/bash "${script}" "$@"
  fi
}

args=(
  +@ShutdownOnFailedCommand 1
  +@NoPromptForPassword 0
  +@sSteamCmdForcePlatformType "${platform}"
  +force_install_dir "${install_dir}"
  +login "${login}"
  +app_update "${appid}"
)

if [[ -n "${beta}" ]]; then
  args+=(-beta "${beta}")
fi
if [[ -n "${beta_password}" ]]; then
  args+=(-betapassword "${beta_password}")
fi
if [[ "${validate}" == "1" ]]; then
  args+=(validate)
fi
args+=(+quit)

log "🧪" "Starting native SteamCMD Windows-platform install."
log "🪵" "SteamCMD log: ${log_file}"
log "🎮" "AppID: ${appid}"
log "🧭" "Platform: ${platform}"
log "📁" "Install folder: ${install_dir}"
log "🔐" "Login: ${login}"
log "ℹ️" "SteamCMD may ask for your password and Steam Guard code in this Terminal."

ensure_steamcmd

set +e
run_steamcmd "${args[@]}" >> "${log_file}" 2>&1
steamcmd_status=$?
set -e

summary="${install_dir}/.rippermoon-steamcmd-install.txt"
{
  print -r -- "RipperMoonKit SteamCMD Windows install"
  print -r -- "Created: $(date '+%Y-%m-%d %H:%M:%S')"
  print -r -- "AppID: ${appid}"
  print -r -- "Platform: ${platform}"
  print -r -- "Install folder: ${install_dir}"
  print -r -- "SteamCMD dir: ${steamcmd_dir}"
  print -r -- "Log: ${log_file}"
  print -r -- "Exit status: ${steamcmd_status}"
} > "${summary}"

if [[ "${steamcmd_status}" -eq 0 ]]; then
  log "✅" "SteamCMD finished successfully."
  log "📄" "Wrote install summary: ${summary}"
  log "ℹ️" "If this is a client game, add a RipperMoonKit game profile pointing at the downloaded .exe and keep Steam running when the game requires Steam APIs."
  exit 0
fi

log "❌" "SteamCMD failed with status ${steamcmd_status}."
log "❌" "Open the log and check for access, ownership, Steam Guard, or app_update restrictions."
exit "${steamcmd_status}"
