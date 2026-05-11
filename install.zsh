#!/bin/zsh

set -e
setopt pipe_fail

repo_dir="${0:A:h}"
config="${HOME}/.rippermoon-gptk.env"
install_deps=1
bootstrap_homebrew=1
download_steam=1
install_steam="${RIPPERMOON_INSTALL_STEAM:-0}"
install_gptk=1
reinstall_gptk=0
update_zshrc=1

usage() {
  cat <<'USAGE'
Usage:
  ./install.zsh [options]

Options:
  --skip-deps              Copy toolkit files only; do not install host dependencies
  --no-homebrew-bootstrap  Do not install Homebrew if it is missing
  --skip-steam-download    Do not download SteamSetup.exe
  --install-steam          After downloading SteamSetup.exe, install Windows Steam into the Steam prefix
  --skip-gptk              Do not install/copy GPTK from mounted Apple media
  --reinstall-gptk         Replace existing local GPTK app/runtime with mounted GPTK media
  --gptk-source PATH       Search a specific mounted GPTK folder or volume first
  --no-zshrc               Do not update ~/.zshrc
  -h, --help               Show this help

Environment:
  RIPPERMOON_BREW_FORMULAE  Space-separated Homebrew formulae to install
  STEAM_SETUP_URL           Override the SteamSetup.exe download URL
  STEAM_SETUP_PATH          Override where SteamSetup.exe is stored
  GPTK_SOURCE               Mounted GPTK folder or volume to search first
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-deps)
      install_deps=0
      shift
      ;;
    --no-homebrew-bootstrap)
      bootstrap_homebrew=0
      shift
      ;;
    --skip-steam-download)
      download_steam=0
      shift
      ;;
    --install-steam)
      install_steam=1
      shift
      ;;
    --skip-gptk)
      install_gptk=0
      shift
      ;;
    --reinstall-gptk)
      reinstall_gptk=1
      shift
      ;;
    --gptk-source)
      [[ $# -ge 2 ]] || {
        print -u2 -- "--gptk-source requires a path"
        exit 2
      }
      GPTK_SOURCE="$2"
      shift 2
      ;;
    --no-zshrc)
      update_zshrc=0
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

if [[ -r "${config}" ]]; then
  source "${config}"
fi

GPTK_HOME="${GPTK_HOME:-${HOME}/GPTK}"
GPTK_LOG_DIR="${GPTK_LOG_DIR:-${GPTK_HOME}/logs}"
GPTK_PREFIX_ROOT="${GPTK_PREFIX_ROOT:-${HOME}/WinePrefixes}"
GPTK_GAMES_ROOT="${GPTK_GAMES_ROOT:-${HOME}/Games}"
GPTK_EXTERNAL_ROOT="${GPTK_EXTERNAL_ROOT:-/Volumes/GameCoreApp}"
GPTK_STEAM_LIBRARY="${GPTK_STEAM_LIBRARY:-${GPTK_EXTERNAL_ROOT}/SteamLibrary}"
GPTK_APP_PATH="${GPTK_APP_PATH:-${GPTK_HOME}/apps/Game Porting Toolkit.app}"
GPTK_RUNTIME="${GPTK_RUNTIME:-${GPTK_HOME}/runtime}"
GPTK_WINE_HOME="${GPTK_WINE_HOME:-${GPTK_APP_PATH}/Contents/Resources/wine}"
GPTK_REQUIRED_VERSION="${GPTK_REQUIRED_VERSION:-3}"
STEAM_SETUP_URL="${STEAM_SETUP_URL:-https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe}"
STEAM_SETUP_PATH="${STEAM_SETUP_PATH:-${GPTK_EXTERNAL_ROOT}/Installers/SteamSetup.exe}"
RIPPERMOON_BREW_FORMULAE="${RIPPERMOON_BREW_FORMULAE-cabextract p7zip samba gnutls molten-vk vulkan-loader vulkan-headers}"

install_bin="${HOME}/bin"
install_libexec="${GPTK_HOME}/libexec"
stamp="$(date +%Y%m%d-%H%M%S)"

mkdir -p "${GPTK_LOG_DIR}"
log_file="${GPTK_LOG_DIR}/rippermoon-install-${stamp}.log"

log() {
  local icon="$1"
  shift
  local msg="$*"
  printf '%s [%s] %s\n' "${icon}" "$(date '+%Y-%m-%d %H:%M:%S')" "${msg}" | tee -a "${log_file}"
}

run_logged() {
  local icon="$1"
  shift
  log "${icon}" "$*"
  "$@" >> "${log_file}" 2>&1
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

refresh_brew_path() {
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

ensure_rosetta() {
  if [[ "$(uname -m)" != "arm64" ]]; then
    log "ℹ️" "Rosetta check skipped on non-arm64 Mac."
    return 0
  fi

  if arch -x86_64 /usr/bin/true >/dev/null 2>&1; then
    log "✅" "Rosetta is installed."
    return 0
  fi

  log "🧬" "Installing Rosetta for x86_64 Windows/Wine processes."
  run_logged "🧬" /usr/sbin/softwareupdate --install-rosetta --agree-to-license
}

ensure_homebrew() {
  refresh_brew_path
  if command_exists brew; then
    log "✅" "Homebrew is available: $(command -v brew)"
    return 0
  fi

  if [[ "${bootstrap_homebrew}" != "1" ]]; then
    log "⚠️" "Homebrew is missing and bootstrap is disabled. Install Homebrew, then rerun ./install.zsh."
    return 1
  fi

  command_exists curl || {
    log "❌" "curl is required to bootstrap Homebrew."
    return 1
  }

  log "🍺" "Homebrew is missing; downloading and running the official Homebrew installer."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" >> "${log_file}" 2>&1
  refresh_brew_path
  command_exists brew || {
    log "❌" "Homebrew installation finished, but brew is still not on PATH."
    return 1
  }
  log "✅" "Homebrew installed: $(command -v brew)"
}

ensure_brew_formulae() {
  local formula
  local formulae
  formulae=(${=RIPPERMOON_BREW_FORMULAE})

  [[ "${#formulae[@]}" -gt 0 ]] || {
    log "ℹ️" "No Homebrew formulae configured."
    return 0
  }

  log "📦" "Installing Homebrew dependencies: ${formulae[*]}"
  for formula in "${formulae[@]}"; do
    if brew list --formula "${formula}" >/dev/null 2>&1; then
      log "✅" "Already installed: ${formula}"
    else
      run_logged "📦" brew install "${formula}"
      log "✅" "Installed: ${formula}"
    fi
  done
}

ensure_directories() {
  log "📁" "Creating toolkit directories."
  mkdir -p "${install_bin}" "${install_libexec}" "${GPTK_LOG_DIR}" "${GPTK_PREFIX_ROOT}" "${GPTK_GAMES_ROOT}" "${GPTK_HOME}/apps" "${GPTK_RUNTIME}"

  if [[ -d "${GPTK_EXTERNAL_ROOT}" ]]; then
    mkdir -p "${GPTK_EXTERNAL_ROOT}/Games" "${GPTK_EXTERNAL_ROOT}/Installers" "${GPTK_STEAM_LIBRARY}"
    log "✅" "External root is available: ${GPTK_EXTERNAL_ROOT}"
  else
    log "⚠️" "External root is not mounted: ${GPTK_EXTERNAL_ROOT}"
    log "⚠️" "Mount it later, or edit ${config} before installing Steam/games."
  fi
}

install_toolkit_files() {
  log "🧰" "Installing RipperMoonToolKit launchers."
  install -m 755 "${repo_dir}/bin/gptk-launch" "${install_bin}/gptk-launch"
  install -m 755 "${repo_dir}/bin/gptk-steam" "${install_bin}/gptk-steam"
  install -m 755 "${repo_dir}/bin/gptk-game" "${install_bin}/gptk-game"
  install -m 644 "${repo_dir}/libexec/gptk-common.zsh" "${install_libexec}/gptk-common.zsh"

  if [[ ! -e "${config}" ]]; then
    install -m 644 "${repo_dir}/env.example" "${config}"
    log "📝" "Created config file: ${config}"
  else
    log "📝" "Using existing config file: ${config}"
  fi
}

ensure_config_export() {
  local key="$1"
  local value="$2"

  [[ -e "${config}" ]] || return 0

  if ! grep -q "^export ${key}=" "${config}" 2>/dev/null; then
    print -r -- "export ${key}=\"${value}\"" >> "${config}"
    log "📝" "Added ${key} to ${config}"
  fi
}

ensure_gptk_config() {
  ensure_config_export "GPTK_APP_PATH" '${GPTK_HOME}/apps/Game Porting Toolkit.app'
  ensure_config_export "GPTK_RUNTIME" '${GPTK_HOME}/runtime'
  ensure_config_export "GPTK_WINE_HOME" '${GPTK_APP_PATH}/Contents/Resources/wine'
  ensure_config_export "GPTK_REQUIRED_VERSION" "3"
}

update_shell_config() {
  [[ "${update_zshrc}" == "1" ]] || {
    log "ℹ️" "Skipping ~/.zshrc update."
    return 0
  }

  if ! grep -q 'rippermoon-gptk.env' "${HOME}/.zshrc" 2>/dev/null; then
    {
      print -r -- ''
      print -r -- '# RipperMoonToolKit'
      print -r -- 'export PATH="$HOME/bin:$PATH"'
      print -r -- '[[ -r "$HOME/.rippermoon-gptk.env" ]] && source "$HOME/.rippermoon-gptk.env"'
    } >> "${HOME}/.zshrc"
    log "✅" "Updated ~/.zshrc."
  else
    log "✅" "~/.zshrc already sources RipperMoonToolKit config."
  fi
}

find_first_path() {
  local path
  for path in "$@"; do
    [[ -e "${path}" ]] && {
      print -r -- "${path}"
      return 0
    }
  done
  return 1
}

find_gptk_app_source() {
  local roots=()
  local found=""

  [[ -n "${GPTK_SOURCE:-}" ]] && roots+=("${GPTK_SOURCE}")
  roots+=(/Volumes/*)

  found="$(find "${roots[@]}" -maxdepth 5 -type d -name "Game Porting Toolkit.app" -print -quit 2>/dev/null || true)"
  [[ -n "${found}" ]] && print -r -- "${found}"
}

find_gptk_runtime_source() {
  local roots=()
  local root
  local found=""

  [[ -n "${GPTK_SOURCE:-}" ]] && roots+=("${GPTK_SOURCE}")
  roots+=(/Volumes/*)

  for root in "${roots[@]}"; do
    [[ -d "${root}" ]] || continue
    if [[ -f "${root}/lib/wine/x86_64-windows/d3d12.dll" && -d "${root}/lib/external" ]]; then
      print -r -- "${root}"
      return 0
    fi
  done

  found="$(find "${roots[@]}" -maxdepth 5 -type d -iname "Evaluation environment for Windows games*" -print -quit 2>/dev/null || true)"
  if [[ -n "${found}" && -f "${found}/lib/wine/x86_64-windows/d3d12.dll" ]]; then
    print -r -- "${found}"
  fi
}

attach_nested_gptk_runtime_image() {
  local roots=()
  local dmg=""
  local before after mounted

  [[ -n "${GPTK_SOURCE:-}" ]] && roots+=("${GPTK_SOURCE}")
  roots+=(/Volumes/*)

  dmg="$(find "${roots[@]}" -maxdepth 5 -type f \( -iname "*Evaluation environment for Windows games*.dmg" -o -iname "*evaluation*windows*games*.dmg" \) -print -quit 2>/dev/null || true)"
  [[ -n "${dmg}" ]] || return 0

  log "💿" "Attaching nested GPTK evaluation environment image: ${dmg}"
  before="$(mktemp)"
  after="$(mktemp)"
  find /Volumes -maxdepth 1 -type d -print 2>/dev/null | sort > "${before}"
  hdiutil attach "${dmg}" -nobrowse -quiet >> "${log_file}" 2>&1 || {
    log "⚠️" "Could not attach nested evaluation environment image."
    command rm -f "${before}" "${after}"
    return 0
  }
  find /Volumes -maxdepth 1 -type d -print 2>/dev/null | sort > "${after}"
  mounted="$(comm -13 "${before}" "${after}" | head -n 1)"
  command rm -f "${before}" "${after}"

  [[ -n "${mounted}" ]] && log "✅" "Mounted nested GPTK image: ${mounted}"
}

install_mounted_gptk() {
  [[ "${install_gptk}" == "1" ]] || {
    log "ℹ️" "Skipping GPTK install/copy from mounted Apple media."
    return 0
  }

  log "🎮" "Looking for mounted Apple Game Porting Toolkit ${GPTK_REQUIRED_VERSION} media."

  local app_source
  local runtime_source

  app_source="$(find_gptk_app_source || true)"
  runtime_source="$(find_gptk_runtime_source || true)"

  if [[ -z "${runtime_source}" ]]; then
    attach_nested_gptk_runtime_image
    runtime_source="$(find_gptk_runtime_source || true)"
  fi

  if [[ -z "${app_source}" && -z "${runtime_source}" ]]; then
    log "⚠️" "No mounted GPTK media found."
    log "⚠️" "Download Game Porting Toolkit ${GPTK_REQUIRED_VERSION} from Apple Developer, mount the DMG, then rerun ./install.zsh."
    return 0
  fi

  if [[ -n "${app_source}" ]]; then
    if [[ -x "${GPTK_APP_PATH}/Contents/Resources/wine/bin/wine64" && "${reinstall_gptk}" != "1" ]]; then
      log "✅" "GPTK app already installed: ${GPTK_APP_PATH}"
    else
      if [[ -e "${GPTK_APP_PATH}" ]]; then
        local app_backup="${GPTK_APP_PATH}.backup-${stamp}"
        log "📦" "Backing up existing GPTK app to ${app_backup}"
        mv "${GPTK_APP_PATH}" "${app_backup}"
      fi
      mkdir -p "${GPTK_APP_PATH:h}"
      log "📦" "Copying GPTK app from mounted media."
      ditto "${app_source}" "${GPTK_APP_PATH}" >> "${log_file}" 2>&1
      log "✅" "Installed GPTK app: ${GPTK_APP_PATH}"
    fi
  else
    log "⚠️" "Mounted GPTK app was not found. The installer will use any existing wine64 it can find."
  fi

  if [[ -n "${runtime_source}" ]]; then
    if [[ -f "${GPTK_RUNTIME}/lib/wine/x86_64-windows/d3d12.dll" && "${reinstall_gptk}" != "1" ]]; then
      log "✅" "GPTK runtime already installed: ${GPTK_RUNTIME}"
    else
      if [[ -d "${GPTK_RUNTIME}/lib" ]]; then
        local runtime_backup="${GPTK_RUNTIME}.backup-${stamp}"
        log "📦" "Backing up existing GPTK runtime to ${runtime_backup}"
        mv "${GPTK_RUNTIME}" "${runtime_backup}"
        mkdir -p "${GPTK_RUNTIME}"
      fi
      log "📦" "Copying GPTK evaluation runtime from mounted media."
      mkdir -p "${GPTK_RUNTIME}"
      ditto "${runtime_source}/lib" "${GPTK_RUNTIME}/lib" >> "${log_file}" 2>&1
      log "✅" "Installed GPTK runtime: ${GPTK_RUNTIME}"
    fi
  else
    log "⚠️" "Mounted GPTK evaluation runtime was not found."
    log "⚠️" "Mount the nested 'Evaluation environment for Windows games 3.0' image if the main DMG does not expose it."
  fi

  export GPTK_WINE_HOME="${GPTK_APP_PATH}/Contents/Resources/wine"
  export GPTK_RUNTIME
}

download_steam_setup() {
  [[ "${download_steam}" == "1" ]] || {
    log "ℹ️" "Skipping SteamSetup.exe download."
    return 0
  }

  local target="${STEAM_SETUP_PATH}"
  local target_dir="${target:h}"
  local tmp="${target}.download"

  if [[ ! -d "${target_dir}" ]]; then
    if mkdir -p "${target_dir}" >/dev/null 2>&1; then
      log "📁" "Created Steam installer directory: ${target_dir}"
    else
      target="${GPTK_HOME}/downloads/SteamSetup.exe"
      target_dir="${target:h}"
      tmp="${target}.download"
      mkdir -p "${target_dir}"
      log "⚠️" "Could not create configured Steam installer directory; using ${target}"
    fi
  fi

  if [[ -s "${target}" ]]; then
    log "✅" "SteamSetup.exe already exists: ${target}"
  else
    command_exists curl || {
      log "❌" "curl is required to download SteamSetup.exe."
      return 1
    }
    log "⬇️" "Downloading SteamSetup.exe from ${STEAM_SETUP_URL}"
    curl -fL --retry 3 --connect-timeout 30 -o "${tmp}" "${STEAM_SETUP_URL}" >> "${log_file}" 2>&1
    mv "${tmp}" "${target}"
    log "✅" "Downloaded SteamSetup.exe to ${target}"
  fi

  export STEAM_SETUP_PATH="${target}"
}

verify_gptk_wine() {
  if [[ -x "${GPTK_WINE_HOME}/bin/wine64" ]]; then
    log "✅" "Found GPTK/Wine runtime: ${GPTK_WINE_HOME}"
    return 0
  fi

  local wine_path
  wine_path="$(command -v wine64 2>/dev/null || true)"
  if [[ -n "${wine_path}" ]]; then
    log "✅" "Found wine64 on PATH: ${wine_path}"
    return 0
  fi

  log "⚠️" "No GPTK/Wine runtime found yet."
  log "⚠️" "Install Apple Game Porting Toolkit, then set GPTK_WINE_HOME in ${config}."
  return 0
}

install_windows_steam() {
  [[ "${install_steam}" == "1" ]] || {
    log "ℹ️" "Windows Steam prefix install skipped. Use ./install.zsh --install-steam when ready."
    return 0
  }

  local steam_setup="${STEAM_SETUP_PATH:-${GPTK_EXTERNAL_ROOT}/Installers/SteamSetup.exe}"
  [[ -f "${steam_setup}" ]] || {
    log "❌" "SteamSetup.exe not found: ${steam_setup}"
    return 1
  }

  if [[ ! -x "${install_bin}/gptk-steam" ]]; then
    log "❌" "gptk-steam was not installed correctly."
    return 1
  fi

  log "🎮" "Installing Windows Steam into the Steam prefix."
  "${install_bin}/gptk-steam" --install "${steam_setup}" >> "${log_file}" 2>&1
  log "✅" "Windows Steam install command completed."
}

log "🚀" "Starting RipperMoonToolKit install."
log "🪵" "Install log: ${log_file}"

ensure_directories
install_toolkit_files
ensure_gptk_config
update_shell_config

if [[ "${install_deps}" == "1" ]]; then
  ensure_rosetta
  ensure_homebrew
  ensure_brew_formulae
  install_mounted_gptk
  download_steam_setup
  verify_gptk_wine
  install_windows_steam
else
  log "ℹ️" "Dependency installation skipped."
fi

log "✅" "Installed launchers to ${install_bin}"
log "✅" "Installed shared library to ${install_libexec}"
log "✅" "Config file: ${config}"
log "✅" "Done. Open a new terminal or run: source ~/.zshrc"
