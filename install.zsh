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
create_update_backup=1
backup_only=0
list_backups=0
rollback_target=""
gptk_wait=1
gptk_wait_seconds="${RIPPERMOON_GPTK_WAIT_SECONDS:-900}"
gptk_open_page="${RIPPERMOON_OPEN_GPTK_PAGE:-ask}"

usage() {
  cat <<'USAGE'
Usage:
  ./install.zsh [options]

Options:
  --skip-deps              Copy toolkit files only; do not install host dependencies
  --no-homebrew-bootstrap  Do not install Homebrew if it is missing
  --skip-steam-download    Do not download SteamSetup.exe
  --install-steam          After downloading SteamSetup.exe, install Windows Steam into the Steam prefix
  --skip-gptk              Do not install/copy GPTK app/runtime
  --reinstall-gptk         Replace existing local GPTK app/runtime with detected sources
  --gptk-source PATH       Search a specific mounted GPTK folder or volume first
  --no-zshrc               Do not update ~/.zshrc
  --no-backup              Do not create an update backup before installing
  --backup-only            Create a rollback backup and exit without installing
  --list-backups           List available rollback backups and exit
  --rollback NAME|PATH     Restore toolkit scripts/config from a rollback backup
  --no-gptk-wait           Do not wait for GPTK media when GPTK is missing
  --gptk-wait-seconds N    Seconds to wait for mounted/downloaded GPTK media
  --open-gptk-page         Open Apple's GPTK download page when GPTK is missing
  -h, --help               Show this help

Environment:
  RIPPERMOON_BREW_FORMULAE  Space-separated Homebrew formulae to install
  RIPPERMOON_GPTK_APP_CASK   Homebrew cask used to install Game Porting Toolkit.app
  RIPPERMOON_INSTALL_GPTK_APP_CASK
                            1 to install the GPTK app cask when the app is missing
  STEAM_SETUP_URL           Override the SteamSetup.exe download URL
  STEAM_SETUP_PATH          Override where SteamSetup.exe is stored
  RIPPERMOON_VCREDIST_X64_URL
                            Override the Microsoft VC++ x64 runtime URL
  RIPPERMOON_VCREDIST_X86_URL
                            Override the Microsoft VC++ x86 runtime URL
  RIPPERMOON_DOTNET6_DESKTOP_URL
                            Override the .NET 6 Desktop Runtime x64 URL
  GPTK_SOURCE               Mounted GPTK folder or volume to search first
  RIPPERMOON_BACKUP_EXTRA_PATHS
                            Semicolon-separated extra files/folders to snapshot
  RIPPERMOON_GPTK_WAIT_SECONDS
                            Seconds to watch /Volumes and ~/Downloads for GPTK
  RIPPERMOON_OPEN_GPTK_PAGE  ask, 1, or 0
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
    --no-backup)
      create_update_backup=0
      shift
      ;;
    --backup-only)
      backup_only=1
      shift
      ;;
    --list-backups)
      list_backups=1
      shift
      ;;
    --rollback)
      [[ $# -ge 2 ]] || {
        print -u2 -- "--rollback requires a backup name or path"
        exit 2
      }
      rollback_target="$2"
      shift 2
      ;;
    --no-gptk-wait)
      gptk_wait=0
      shift
      ;;
    --gptk-wait-seconds)
      [[ $# -ge 2 ]] || {
        print -u2 -- "--gptk-wait-seconds requires a number"
        exit 2
      }
      gptk_wait_seconds="$2"
      shift 2
      ;;
    --open-gptk-page)
      gptk_open_page=1
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
GPTK_EXTERNAL_ROOT="${GPTK_EXTERNAL_ROOT:-${HOME}/Library/Application Support/RipperMoonKit}"
GPTK_STEAM_LIBRARY="${GPTK_STEAM_LIBRARY:-${GPTK_EXTERNAL_ROOT}/SteamLibrary}"
GPTK_APP_PATH="${GPTK_APP_PATH:-${GPTK_HOME}/apps/Game Porting Toolkit.app}"
GPTK_RUNTIME="${GPTK_RUNTIME:-${GPTK_HOME}/runtime}"
GPTK_WINE_HOME="${GPTK_WINE_HOME:-${GPTK_APP_PATH}/Contents/Resources/wine}"
GPTK_REQUIRED_VERSION="${GPTK_REQUIRED_VERSION:-3}"
GPTK_DOWNLOAD_PAGE="${GPTK_DOWNLOAD_PAGE:-https://developer.apple.com/games/game-porting-toolkit/}"
GPTK_DOWNLOAD_DIR="${GPTK_DOWNLOAD_DIR:-${HOME}/Downloads}"
STEAM_SETUP_URL="${STEAM_SETUP_URL:-https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe}"
STEAM_SETUP_PATH="${STEAM_SETUP_PATH:-${HOME}/Library/Application Support/RipperMoonKit/Downloads/SteamSetup.exe}"
RIPPERMOON_VCREDIST_X64_URL="${RIPPERMOON_VCREDIST_X64_URL:-https://aka.ms/vc14/vc_redist.x64.exe}"
RIPPERMOON_VCREDIST_X86_URL="${RIPPERMOON_VCREDIST_X86_URL:-https://aka.ms/vc14/vc_redist.x86.exe}"
RIPPERMOON_DOTNET6_DESKTOP_URL="${RIPPERMOON_DOTNET6_DESKTOP_URL:-https://aka.ms/dotnet/6.0/windowsdesktop-runtime-win-x64.exe}"
RIPPERMOON_DOTNET6_DIR="${RIPPERMOON_DOTNET6_DIR:-${GPTK_HOME}/downloads/dotnet6}"
RIPPERMOON_BREW_FORMULAE="${RIPPERMOON_BREW_FORMULAE-cabextract p7zip samba gnutls molten-vk vulkan-loader vulkan-headers}"
RIPPERMOON_GPTK_APP_CASK="${RIPPERMOON_GPTK_APP_CASK:-gcenx/wine/game-porting-toolkit}"
RIPPERMOON_INSTALL_GPTK_APP_CASK="${RIPPERMOON_INSTALL_GPTK_APP_CASK:-1}"

install_bin="${HOME}/bin"
install_libexec="${GPTK_HOME}/libexec"
install_scripts="${GPTK_HOME}/scripts"
stamp="$(date +%Y%m%d-%H%M%S)"
backup_root="${GPTK_HOME}/backups"
backup_dir="${backup_root}/rippermoon-update-${stamp}"

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

copy_path_preserve() {
  local source="$1"
  local target="$2"

  mkdir -p "${target:h}"
  if [[ -d "${source}" ]]; then
    ditto "${source}" "${target}"
  else
    cp -p "${source}" "${target}"
  fi
}

backup_restore_path() {
  local source="$1"
  local relative="$2"
  local label="$3"
  local target="${backup_dir}/${relative}"

  if [[ ! -e "${source}" ]]; then
    log "ℹ️" "No existing ${label} to back up: ${source}"
    printf '%s\n' "${source}" >> "${backup_dir}/absent.tsv"
    return 0
  fi

  copy_path_preserve "${source}" "${target}"
  printf '%s\t%s\n' "${relative}" "${source}" >> "${backup_dir}/restore.tsv"
  log "🛟" "Backed up ${label}: ${source}"
}

record_protected_path() {
  local label="$1"
  local path="$2"
  local state="missing"

  [[ -n "${path}" ]] || return 0
  [[ -e "${path}" ]] && state="exists"
  printf '%s\t%s\t%s\n' "${state}" "${label}" "${path}" >> "${backup_dir}/protected-paths.tsv"
}

backup_extra_paths() {
  local extra_paths
  local path
  local safe_name
  local target

  [[ -n "${RIPPERMOON_BACKUP_EXTRA_PATHS:-}" ]] || return 0

  extra_paths=(${(s:;:)RIPPERMOON_BACKUP_EXTRA_PATHS})
  mkdir -p "${backup_dir}/extra"

  for path in "${extra_paths[@]}"; do
    [[ -n "${path}" ]] || continue
    if [[ ! -e "${path}" ]]; then
      log "⚠️" "Extra backup path is missing: ${path}"
      continue
    fi

    safe_name="${path#/}"
    safe_name="${safe_name//\//__}"
    target="${backup_dir}/extra/${safe_name}"
    copy_path_preserve "${path}" "${target}"
    printf '%s\t%s\n' "extra/${safe_name}" "${path}" >> "${backup_dir}/extra-paths.tsv"
    log "🛟" "Snapshotted extra protected path: ${path}"
  done
}

write_backup_readme() {
  {
    print -r -- "RipperMoonToolKit update backup"
    print -r -- ""
    print -r -- "Created: $(date '+%Y-%m-%d %H:%M:%S')"
    print -r -- "Repository: ${repo_dir}"
    print -r -- "Config: ${config}"
    print -r -- "GPTK_HOME: ${GPTK_HOME}"
    print -r -- ""
    print -r -- "This backup restores small toolkit files only:"
    print -r -- "- ${config}"
    print -r -- "- ${HOME}/.zshrc"
    print -r -- "- ${install_bin}/gptk-launch"
    print -r -- "- ${install_bin}/gptk-steam"
    print -r -- "- ${install_bin}/gptk-game"
    print -r -- "- ${install_bin}/gptk-vcrun"
    print -r -- "- ${install_bin}/gptk-dotnet6"
    print -r -- "- ${install_bin}/gptk-stubs"
    print -r -- "- ${install_libexec}/gptk-common.zsh"
    print -r -- "- ${install_scripts}/install-elden-mod-pack.zsh"
    print -r -- "- ${install_scripts}/elden-mod-state.zsh"
    print -r -- ""
    print -r -- "Files listed in absent.tsv did not exist before the update and are removed during rollback if the update created them."
    print -r -- ""
    print -r -- "Wine prefixes, Steam data, games, saves, GPTK runtimes, and patched runners are not modified by rollback."
    print -r -- "Protected paths are recorded in protected-paths.tsv for audit."
    print -r -- ""
    print -r -- "Rollback command:"
    print -r -- "./install.zsh --rollback ${backup_dir:t}"
  } > "${backup_dir}/README.txt"
}

create_backup() {
  [[ "${create_update_backup}" == "1" ]] || {
    log "ℹ️" "Update backup disabled."
    return 0
  }

  mkdir -p "${backup_dir}"
  : > "${backup_dir}/restore.tsv"
  : > "${backup_dir}/absent.tsv"
  : > "${backup_dir}/protected-paths.tsv"
  : > "${backup_dir}/extra-paths.tsv"

  log "🛟" "Creating update backup: ${backup_dir}"
  backup_restore_path "${config}" "home/.rippermoon-gptk.env" "config"
  backup_restore_path "${HOME}/.zshrc" "home/.zshrc" "shell config"
  backup_restore_path "${install_bin}/gptk-launch" "home/bin/gptk-launch" "launcher"
  backup_restore_path "${install_bin}/gptk-steam" "home/bin/gptk-steam" "Steam launcher"
  backup_restore_path "${install_bin}/gptk-game" "home/bin/gptk-game" "game helper"
  backup_restore_path "${install_bin}/gptk-vcrun" "home/bin/gptk-vcrun" "VC++ runtime helper"
  backup_restore_path "${install_bin}/gptk-dotnet6" "home/bin/gptk-dotnet6" ".NET 6 Desktop Runtime helper"
  backup_restore_path "${install_bin}/gptk-stubs" "home/bin/gptk-stubs" "API stubs helper"
  backup_restore_path "${install_libexec}/gptk-common.zsh" "gptk/libexec/gptk-common.zsh" "shared helper library"
  backup_restore_path "${install_scripts}/install-elden-mod-pack.zsh" "gptk/scripts/install-elden-mod-pack.zsh" "Elden Ring mod profile helper"
  backup_restore_path "${install_scripts}/elden-mod-state.zsh" "gptk/scripts/elden-mod-state.zsh" "Elden Ring mod backup/import helper"

  record_protected_path "Wine prefix root" "${GPTK_PREFIX_ROOT}"
  record_protected_path "Game script root" "${GPTK_GAMES_ROOT}"
  record_protected_path "External storage root" "${GPTK_EXTERNAL_ROOT}"
  record_protected_path "External games root" "${GPTK_EXTERNAL_ROOT}/Games"
  record_protected_path "Steam library" "${GPTK_STEAM_LIBRARY}"
  record_protected_path "GPTK app" "${GPTK_APP_PATH}"
  record_protected_path "GPTK runtime" "${GPTK_RUNTIME}"

  backup_extra_paths
  write_backup_readme

  log "✅" "Rollback backup ready: ${backup_dir}"
}

list_update_backups() {
  local dir

  if [[ ! -d "${backup_root}" ]]; then
    print -r -- "No backups found: ${backup_root}"
    return 0
  fi

  for dir in "${backup_root}"/rippermoon-update-*(N/om); do
    print -r -- "${dir:t}	${dir}"
  done
}

resolve_backup_path() {
  local target="$1"

  if [[ -d "${target}" ]]; then
    print -r -- "${target:A}"
    return 0
  fi

  if [[ -d "${backup_root}/${target}" ]]; then
    print -r -- "${backup_root}/${target}"
    return 0
  fi

  return 1
}

rollback_backup() {
  local requested="$1"
  local selected
  local relative
  local destination
  local source
  local current_backup

  selected="$(resolve_backup_path "${requested}" || true)"
  if [[ -z "${selected}" || ! -f "${selected}/restore.tsv" ]]; then
    log "❌" "Rollback backup not found or invalid: ${requested}"
    log "ℹ️" "Run ./install.zsh --list-backups to see available backups."
    return 1
  fi

  log "↩️" "Rolling back toolkit files from ${selected}"

  while IFS=$'\t' read -r relative destination; do
    [[ -n "${relative}" && -n "${destination}" ]] || continue
    source="${selected}/${relative}"
    [[ -e "${source}" ]] || {
      log "⚠️" "Backup entry is missing, skipping: ${source}"
      continue
    }

    if [[ -e "${destination}" ]]; then
      current_backup="${destination}.pre-rollback-${stamp}"
      copy_path_preserve "${destination}" "${current_backup}"
      log "📦" "Preserved current file before rollback: ${current_backup}"
    fi

    copy_path_preserve "${source}" "${destination}"
    log "✅" "Restored ${destination}"
  done < "${selected}/restore.tsv"

  if [[ -f "${selected}/absent.tsv" ]]; then
    while IFS= read -r destination; do
      [[ -n "${destination}" && -e "${destination}" ]] || continue
      case "${destination:A}" in
        "${HOME:A}/.rippermoon-gptk.env"|\
        "${HOME:A}/bin/gptk-launch"|\
        "${HOME:A}/bin/gptk-steam"|\
        "${HOME:A}/bin/gptk-game"|\
        "${HOME:A}/bin/gptk-vcrun"|\
        "${HOME:A}/bin/gptk-dotnet6"|\
        "${HOME:A}/bin/gptk-stubs"|\
        "${HOME:A}/.zshrc"|\
        "${GPTK_HOME:A}/libexec/gptk-common.zsh"|\
        "${GPTK_HOME:A}/scripts/install-elden-mod-pack.zsh"|\
        "${GPTK_HOME:A}/scripts/elden-mod-state.zsh")
          rm -rf "${destination}"
          log "✅" "Removed file that did not exist before backup: ${destination}"
          ;;
        *)
          log "⚠️" "Refusing to remove unrecognized absent-path entry: ${destination}"
          ;;
      esac
    done < "${selected}/absent.tsv"
  fi

  log "✅" "Rollback complete."
  log "ℹ️" "Wine prefixes, games, saves, Steam data, GPTK runtimes, and runners were not changed."
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

ensure_gptk_app_cask() {
  [[ "${RIPPERMOON_INSTALL_GPTK_APP_CASK}" == "1" ]] || {
    log "ℹ️" "Automatic GPTK app cask install is disabled."
    return 1
  }

  if [[ -x "/Applications/Game Porting Toolkit.app/Contents/Resources/wine/bin/wine64" ]]; then
    log "✅" "System GPTK app is already available: /Applications/Game Porting Toolkit.app"
    return 0
  fi

  command_exists brew || {
    log "❌" "Homebrew is required to install ${RIPPERMOON_GPTK_APP_CASK}."
    return 1
  }

  local cask="${RIPPERMOON_GPTK_APP_CASK}"
  local token="${cask:t}"

  if brew list --cask "${token}" >/dev/null 2>&1; then
    log "✅" "GPTK app cask is already installed: ${token}"
  else
    log "🍺" "Installing GPTK app cask: ${cask}"
    if ! brew install --cask --no-quarantine "${cask}" >> "${log_file}" 2>&1; then
      log "❌" "Could not install ${cask}."
      log "❌" "Install it manually, or set RIPPERMOON_GPTK_APP_CASK to another compatible cask that provides Game Porting Toolkit.app."
      return 1
    fi
    log "✅" "Installed GPTK app cask: ${cask}"
  fi

  if [[ -x "/Applications/Game Porting Toolkit.app/Contents/Resources/wine/bin/wine64" ]]; then
    log "✅" "System GPTK app is ready: /Applications/Game Porting Toolkit.app"
    return 0
  fi

  log "❌" "The GPTK app cask installed, but /Applications/Game Porting Toolkit.app was not found."
  return 1
}

ensure_directories() {
  log "📁" "Creating toolkit directories."
  mkdir -p "${install_bin}" "${install_libexec}" "${install_scripts}" "${GPTK_LOG_DIR}" "${GPTK_PREFIX_ROOT}" "${GPTK_GAMES_ROOT}" "${GPTK_HOME}/apps" "${GPTK_RUNTIME}"

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
  install -m 755 "${repo_dir}/bin/gptk-vcrun" "${install_bin}/gptk-vcrun"
  install -m 755 "${repo_dir}/bin/gptk-dotnet6" "${install_bin}/gptk-dotnet6"
  install -m 755 "${repo_dir}/bin/gptk-stubs" "${install_bin}/gptk-stubs"
  install -m 644 "${repo_dir}/libexec/gptk-common.zsh" "${install_libexec}/gptk-common.zsh"
  install -m 755 "${repo_dir}/scripts/install-elden-mod-pack.zsh" "${install_scripts}/install-elden-mod-pack.zsh"
  install -m 755 "${repo_dir}/scripts/elden-mod-state.zsh" "${install_scripts}/elden-mod-state.zsh"

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
  ensure_config_export "RIPPERMOON_GPTK_APP_CASK" "gcenx/wine/game-porting-toolkit"
  ensure_config_export "RIPPERMOON_INSTALL_GPTK_APP_CASK" "1"
  ensure_config_export "RIPPERMOON_DOTNET6_DESKTOP_URL" "https://aka.ms/dotnet/6.0/windowsdesktop-runtime-win-x64.exe"
  ensure_config_export "RIPPERMOON_DOTNET6_DIR" '${GPTK_HOME}/downloads/dotnet6'
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
  local candidate

  [[ -n "${GPTK_SOURCE:-}" ]] && roots+=("${GPTK_SOURCE}")
  roots+=(/Volumes/*)
  roots+=("/Applications" "${HOME}/Applications")

  for candidate in \
    "${GPTK_SOURCE:-}/Game Porting Toolkit.app" \
    "/Applications/Game Porting Toolkit.app" \
    "${HOME}/Applications/Game Porting Toolkit.app"; do
    [[ -x "${candidate}/Contents/Resources/wine/bin/wine64" ]] || continue
    [[ "${candidate:A}" == "${GPTK_APP_PATH:A}" ]] && continue
    print -r -- "${candidate}"
    return 0
  done

  found="$(find "${roots[@]}" -maxdepth 5 -type d -name "Game Porting Toolkit.app" -print 2>/dev/null | while read -r candidate; do
    [[ -x "${candidate}/Contents/Resources/wine/bin/wine64" ]] || continue
    [[ "${candidate:A}" == "${GPTK_APP_PATH:A}" ]] && continue
    print -r -- "${candidate}"
    break
  done || true)"
  [[ -n "${found}" ]] && print -r -- "${found}"
}

find_gptk_runtime_source() {
  local roots=()
  local root
  local candidate
  local found=""

  [[ -n "${GPTK_SOURCE:-}" ]] && roots+=("${GPTK_SOURCE}")
  roots+=(/Volumes/*)

  for root in "${roots[@]}"; do
    [[ -d "${root}" ]] || continue
    for candidate in "${root}" "${root}/redist"; do
      if [[ -f "${candidate}/lib/wine/x86_64-windows/d3d12.dll" && -d "${candidate}/lib/external" ]]; then
        print -r -- "${candidate}"
        return 0
      fi
    done
  done

  found="$(find "${roots[@]}" -maxdepth 6 -type d \( -iname "Evaluation environment for Windows games*" -o -iname "redist" \) -print 2>/dev/null | while read -r candidate; do
    for root in "${candidate}" "${candidate}/redist"; do
      [[ -f "${root}/lib/wine/x86_64-windows/d3d12.dll" && -d "${root}/lib/external" ]] || continue
      print -r -- "${root}"
      break 2
    done
  done || true)"
  if [[ -n "${found}" ]]; then
    print -r -- "${found}"
  fi
}

find_downloaded_gptk_dmg() {
  local roots=()
  local found=""

  [[ -n "${GPTK_SOURCE:-}" ]] && roots+=("${GPTK_SOURCE}")
  roots+=("${GPTK_DOWNLOAD_DIR}")
  roots+=("${HOME}/Desktop")

  found="$(find "${roots[@]}" -maxdepth 4 -type f \( \
    -iname "*Game Porting Toolkit*.dmg" -o \
    -iname "*game*porting*toolkit*.dmg" -o \
    -iname "*Evaluation environment for Windows games*.dmg" -o \
    -iname "*evaluation*windows*games*.dmg" \
  \) -print 2>/dev/null | sort -r | head -n 1 || true)"

  [[ -n "${found}" ]] && print -r -- "${found}"
}

attach_gptk_dmg() {
  local dmg="$1"

  [[ -f "${dmg}" ]] || return 1

  log "💿" "Attaching GPTK disk image: ${dmg}"
  if hdiutil attach "${dmg}" -quiet >> "${log_file}" 2>&1; then
    log "✅" "Attached GPTK disk image."
    return 0
  fi

  log "⚠️" "Could not attach GPTK disk image yet: ${dmg}"
  return 1
}

maybe_open_gptk_download_page() {
  log "🔗" "Apple GPTK ${GPTK_REQUIRED_VERSION} download page: ${GPTK_DOWNLOAD_PAGE}"

  if [[ "${gptk_open_page}" == "1" ]]; then
    command_exists open && open "${GPTK_DOWNLOAD_PAGE}" >> "${log_file}" 2>&1 || true
    return 0
  fi

  [[ "${gptk_open_page}" == "0" ]] && return 0

  if [[ -t 0 ]]; then
    local reply
    print -rn -- "Open Apple's Game Porting Toolkit ${GPTK_REQUIRED_VERSION} download page now? [Y/n] "
    read -r reply
    if [[ -z "${reply}" || "${reply:l}" == "y" || "${reply:l}" == "yes" ]]; then
      command_exists open && open "${GPTK_DOWNLOAD_PAGE}" >> "${log_file}" 2>&1 || true
    fi
  else
    log "ℹ️" "Non-interactive install: set RIPPERMOON_OPEN_GPTK_PAGE=1 to open the download page automatically."
  fi
}

wait_for_gptk_media() {
  local waited=0
  local interval=5
  local dmg=""
  local last_dmg=""
  local runtime_source=""

  [[ "${gptk_wait}" == "1" ]] || return 1

  maybe_open_gptk_download_page

  log "⏳" "Waiting up to ${gptk_wait_seconds}s for GPTK media in /Volumes or ${GPTK_DOWNLOAD_DIR}."
  log "ℹ️" "Download Game Porting Toolkit ${GPTK_REQUIRED_VERSION} from Apple, then mount the DMG or leave it in Downloads."

  while (( waited <= gptk_wait_seconds )); do
    runtime_source="$(find_gptk_runtime_source || true)"

    if [[ -n "${runtime_source}" ]]; then
      log "✅" "Found mounted GPTK runtime media."
      return 0
    fi

    dmg="$(find_downloaded_gptk_dmg || true)"
    if [[ -n "${dmg}" && "${dmg}" != "${last_dmg}" ]]; then
      attach_gptk_dmg "${dmg}" || true
      attach_nested_gptk_runtime_image || true
      last_dmg="${dmg}"
    fi

    sleep "${interval}"
    waited=$(( waited + interval ))
  done

  log "❌" "Timed out waiting for GPTK ${GPTK_REQUIRED_VERSION} media."
  return 1
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
    log "ℹ️" "Skipping GPTK app/runtime install."
    return 0
  }

  log "🎮" "Preparing Game Porting Toolkit app runner and Apple GPTK ${GPTK_REQUIRED_VERSION} runtime."

  local local_app_ok=0
  local local_runtime_ok=0
  local need_app=0
  local need_runtime=0
  local app_source
  local runtime_source

  [[ -x "${GPTK_APP_PATH}/Contents/Resources/wine/bin/wine64" ]] && local_app_ok=1
  [[ -f "${GPTK_RUNTIME}/lib/wine/x86_64-windows/d3d12.dll" ]] && local_runtime_ok=1

  if [[ "${reinstall_gptk}" != "1" && "${local_app_ok}" == "1" && "${local_runtime_ok}" == "1" ]]; then
    log "✅" "Local GPTK app/runtime already installed."
    export GPTK_WINE_HOME="${GPTK_APP_PATH}/Contents/Resources/wine"
    export GPTK_RUNTIME
    return 0
  fi

  [[ "${reinstall_gptk}" == "1" || "${local_app_ok}" != "1" ]] && need_app=1
  [[ "${reinstall_gptk}" == "1" || "${local_runtime_ok}" != "1" ]] && need_runtime=1

  app_source="$(find_gptk_app_source || true)"
  runtime_source="$(find_gptk_runtime_source || true)"

  if [[ "${need_app}" == "1" && -z "${app_source}" ]]; then
    ensure_gptk_app_cask || true
    app_source="$(find_gptk_app_source || true)"
  fi

  if [[ "${need_runtime}" == "1" && -z "${runtime_source}" ]]; then
    attach_nested_gptk_runtime_image
    runtime_source="$(find_gptk_runtime_source || true)"
  fi

  if [[ "${need_runtime}" == "1" && -z "${runtime_source}" ]]; then
    log "⚠️" "No mounted GPTK runtime media found."
    wait_for_gptk_media || {
      log "❌" "Download Game Porting Toolkit ${GPTK_REQUIRED_VERSION} from Apple Developer, mount the DMG, then rerun ./install.zsh."
      return 1
    }

    app_source="$(find_gptk_app_source || true)"
    runtime_source="$(find_gptk_runtime_source || true)"

    if [[ "${need_app}" == "1" && -z "${app_source}" ]]; then
      ensure_gptk_app_cask || true
      app_source="$(find_gptk_app_source || true)"
    fi

    if [[ "${need_runtime}" == "1" && -z "${runtime_source}" ]]; then
      attach_nested_gptk_runtime_image
      runtime_source="$(find_gptk_runtime_source || true)"
    fi
  fi

  if [[ "${need_app}" == "1" && -z "${app_source}" ]]; then
    log "❌" "Game Porting Toolkit.app was not found."
    log "❌" "Install ${RIPPERMOON_GPTK_APP_CASK}, or mount/copy a GPTK-compatible app that provides Contents/Resources/wine/bin/wine64."
    return 1
  fi

  if [[ "${need_runtime}" == "1" && -z "${runtime_source}" ]]; then
    log "❌" "GPTK evaluation runtime was not found."
    log "❌" "Mount Game Porting Toolkit ${GPTK_REQUIRED_VERSION} and its nested 'Evaluation environment for Windows games' image, then rerun setup."
    return 1
  fi

  if [[ "${need_app}" != "1" ]]; then
    log "✅" "GPTK app already installed: ${GPTK_APP_PATH}"
  else
    if [[ -e "${GPTK_APP_PATH}" ]]; then
      local app_backup="${GPTK_APP_PATH}.backup-${stamp}"
      log "📦" "Backing up existing GPTK app to ${app_backup}"
      mv "${GPTK_APP_PATH}" "${app_backup}"
    fi
    mkdir -p "${GPTK_APP_PATH:h}"
    log "📦" "Copying GPTK app from ${app_source}."
    ditto "${app_source}" "${GPTK_APP_PATH}" >> "${log_file}" 2>&1
    log "✅" "Installed GPTK app: ${GPTK_APP_PATH}"
  fi

  if [[ "${need_runtime}" != "1" ]]; then
    log "✅" "GPTK runtime already installed: ${GPTK_RUNTIME}"
  else
    if [[ -d "${GPTK_RUNTIME}/lib" ]]; then
      local runtime_backup="${GPTK_RUNTIME}.backup-${stamp}"
      log "📦" "Backing up existing GPTK runtime to ${runtime_backup}"
      mv "${GPTK_RUNTIME}" "${runtime_backup}"
      mkdir -p "${GPTK_RUNTIME}"
    fi
    log "📦" "Copying GPTK evaluation runtime from ${runtime_source}."
    mkdir -p "${GPTK_RUNTIME}"
    ditto "${runtime_source}/lib" "${GPTK_RUNTIME}/lib" >> "${log_file}" 2>&1
    log "✅" "Installed GPTK runtime: ${GPTK_RUNTIME}"
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
  local steam_exe="${GPTK_PREFIX_ROOT}/Steam/drive_c/Program Files (x86)/Steam/steam.exe"
  if [[ -f "${steam_exe}" ]]; then
    log "✅" "Windows Steam installed and validated: ${steam_exe}"
  else
    log "❌" "Steam installer finished, but steam.exe was not created: ${steam_exe}"
    log "❌" "Open the newest log in ${GPTK_LOG_DIR}, then retry with ./install.zsh --install-steam."
    return 1
  fi
}

if [[ "${list_backups}" == "1" ]]; then
  list_update_backups
  exit 0
fi

log "🚀" "Starting RipperMoonToolKit install."
log "🪵" "Install log: ${log_file}"

if [[ -n "${rollback_target}" ]]; then
  rollback_backup "${rollback_target}"
  exit 0
fi

ensure_directories
create_backup

if [[ "${backup_only}" == "1" ]]; then
  log "✅" "Backup-only mode complete."
  exit 0
fi

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
log "✅" "Installed helper scripts to ${install_scripts}"
log "✅" "Config file: ${config}"
log "✅" "Done. Open a new terminal or run: source ~/.zshrc"
