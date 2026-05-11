#!/bin/zsh

emulate -L zsh
setopt no_unset pipe_fail

gptk_die() {
  print -u2 -- "gptk: $*"
  exit 1
}

gptk_note() {
  print -u2 -- "gptk: $*"
}

gptk_join_path() {
  local result=""
  local item
  for item in "$@"; do
    [[ -n "${item}" ]] || continue
    if [[ -z "${result}" ]]; then
      result="${item}"
    else
      result="${result}:${item}"
    fi
  done
  print -r -- "${result}"
}

gptk_trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  print -r -- "${value}"
}

gptk_init_defaults() {
  [[ -r "${HOME}/.rippermoon-gptk.env" ]] && source "${HOME}/.rippermoon-gptk.env"

  export GPTK_HOME="${GPTK_HOME:-${HOME}/GPTK}"
  export GPTK_PREFIX_ROOT="${GPTK_PREFIX_ROOT:-${HOME}/WinePrefixes}"
  export GPTK_GAMES_ROOT="${GPTK_GAMES_ROOT:-${HOME}/Games}"
  export GPTK_EXTERNAL_ROOT="${GPTK_EXTERNAL_ROOT:-/Volumes/GameCoreApp}"
  export GPTK_STEAM_LIBRARY="${GPTK_STEAM_LIBRARY:-${GPTK_EXTERNAL_ROOT}/SteamLibrary}"
  export GPTK_DRIVE_MAPS="${GPTK_DRIVE_MAPS:-S=${GPTK_STEAM_LIBRARY};X=${GPTK_EXTERNAL_ROOT}/Games;I=${GPTK_EXTERNAL_ROOT}/Installers}"
  export GPTK_LOG_DIR="${GPTK_LOG_DIR:-${GPTK_HOME}/logs}"
  export GPTK_APP_PATH="${GPTK_APP_PATH:-${GPTK_HOME}/apps/Game Porting Toolkit.app}"
  export GPTK_RUNTIME="${GPTK_RUNTIME:-${GPTK_HOME}/runtime}"
  export GPTK_WINE_HOME="${GPTK_WINE_HOME:-${GPTK_APP_PATH}/Contents/Resources/wine}"
  export GPTK_DEFAULT_WINVER="${GPTK_DEFAULT_WINVER:-win10}"
  export GPTK_MTL_HUD_ENABLED="${GPTK_MTL_HUD_ENABLED:-0}"
  export GPTK_WINEESYNC="${GPTK_WINEESYNC:-1}"
  export GPTK_USE_DXVK="${GPTK_USE_DXVK:-0}"
  export GPTK_DXR="${GPTK_DXR:-1}"
  export GPTK_METALFX="${GPTK_METALFX:-0}"
  export GPTK_ADVERTISE_AVX="${GPTK_ADVERTISE_AVX:-0}"
}

gptk_find_wine_home() {
  local candidate
  for candidate in \
    "${GPTK_WINE_HOME}" \
    "${GPTK_HOME}/apps/Game Porting Toolkit.app/Contents/Resources/wine" \
    "/Applications/Game Porting Toolkit.app/Contents/Resources/wine" \
    "/Applications/Wine Stable.app/Contents/Resources/wine" \
    "/Applications/Wine Staging.app/Contents/Resources/wine"; do
    [[ -x "${candidate}/bin/wine64" ]] && {
      print -r -- "${candidate}"
      return 0
    }
  done

  local wine_path
  wine_path="$(command -v wine64 2>/dev/null || true)"
  if [[ -n "${wine_path}" ]]; then
    wine_path="$(readlink "${wine_path}" 2>/dev/null || print -r -- "${wine_path}")"
    if [[ "${wine_path}" == */bin/wine64 ]]; then
      print -r -- "${wine_path:h:h}"
      return 0
    fi
  fi

  return 1
}

gptk_tool_path() {
  local tool="$1"
  local path="${GPTK_WINE_HOME}/bin/${tool}"
  [[ -x "${path}" ]] || gptk_die "missing ${tool}; expected ${path}"
  print -r -- "${path}"
}

gptk_resolve_prefix() {
  local prefix="$1"
  [[ -n "${prefix}" ]] || prefix="Default"

  if [[ "${prefix}" == /* || "${prefix}" == ./* || "${prefix}" == ../* ]]; then
    print -r -- "${prefix:A}"
  else
    print -r -- "${GPTK_PREFIX_ROOT}/${prefix}"
  fi
}

gptk_configure_environment() {
  local prefix_path="$1"
  GPTK_WINE_HOME="$(gptk_find_wine_home)" || gptk_die "no compatible wine64 found"
  export GPTK_WINE_HOME

  export WINEPREFIX="${prefix_path}"
  export WINEARCH="${WINEARCH:-win64}"
  export MTL_HUD_ENABLED="${GPTK_MTL_HUD_ENABLED}"
  export WINEESYNC="${GPTK_WINEESYNC}"
  export D3DM_SUPPORT_DXR="${GPTK_DXR}"
  export D3DM_ENABLE_METALFX="${GPTK_METALFX}"
  export ROSETTA_ADVERTISE_AVX="${GPTK_ADVERTISE_AVX}"

  export PATH="$(gptk_join_path \
    "${GPTK_WINE_HOME}/bin" \
    "${HOME}/bin" \
    "/opt/homebrew/bin" \
    "/usr/local/bin" \
    "${PATH}")"

  export WINEDLLPATH="$(gptk_join_path \
    "${GPTK_RUNTIME}/lib/wine/x86_64-windows" \
    "${GPTK_WINE_HOME}/lib/wine/x86_64-windows" \
    "${GPTK_WINE_HOME}/lib/wine/i386-windows" \
    "${WINEDLLPATH:-}")"

  export DYLD_FALLBACK_LIBRARY_PATH="$(gptk_join_path \
    "${GPTK_RUNTIME}/lib/external" \
    "${GPTK_RUNTIME}/lib/wine/x86_64-unix" \
    "${GPTK_WINE_HOME}/lib" \
    "${GPTK_WINE_HOME}/lib/external" \
    "${GPTK_WINE_HOME}/lib/wine/x86_64-unix" \
    "${GPTK_WINE_HOME}/lib/wine/x86_32on64-unix" \
    "${DYLD_FALLBACK_LIBRARY_PATH:-}")"

  export DYLD_LIBRARY_PATH="$(gptk_join_path \
    "${GPTK_RUNTIME}/lib/external" \
    "${GPTK_WINE_HOME}/lib" \
    "${GPTK_WINE_HOME}/lib/external" \
    "${DYLD_LIBRARY_PATH:-}")"

  if [[ "${GPTK_USE_DXVK}" == "1" ]]; then
    export WINEDLLOVERRIDES="d3d9,d3d10,d3d10core,d3d11,dxgi=n,b;d3d12=b;${WINEDLLOVERRIDES:-}"
  else
    export WINEDLLOVERRIDES="d3d10,d3d11,d3d12,dxgi=b;${WINEDLLOVERRIDES:-}"
  fi
}

gptk_run_native() {
  local executable="$1"
  shift
  if [[ "$(uname -m)" == "arm64" ]]; then
    arch -x86_64 "${executable}" "$@"
  else
    "${executable}" "$@"
  fi
}

gptk_run_tool() {
  local tool="$1"
  shift
  local native_tool="${GPTK_WINE_HOME}/bin/${tool}"

  if [[ -x "${native_tool}" ]]; then
    gptk_run_native "${native_tool}" "$@"
  else
    gptk_run_native "$(gptk_tool_path wine64)" "${tool}" "$@"
  fi
}

gptk_link_drive() {
  local letter="$1"
  local target="$2"
  local prefix_path="$3"
  letter="${letter%:}"
  letter="${letter:u}"

  if [[ "${#letter}" -ne 1 || "${letter}" != [A-Z] ]]; then
    gptk_die "invalid Wine drive letter '${letter}'; use one letter A-Z"
  fi

  if [[ "${letter:l}" == "c" ]]; then
    gptk_die "refusing to map C:; Wine owns C: inside each prefix"
  fi

  local drive="${prefix_path}/dosdevices/${letter:l}:"

  [[ -d "${target}" ]] || return 0
  mkdir -p "${prefix_path}/dosdevices"

  if [[ -e "${drive}" && ! -L "${drive}" ]]; then
    gptk_note "not replacing existing non-symlink Wine drive ${drive}"
    return 0
  fi

  [[ -L "${drive}" ]] && command rm -f -- "${drive}"
  ln -s "${target}" "${drive}"
}

gptk_link_configured_drives() {
  local prefix_path="$1"
  local maps="${GPTK_DRIVE_MAPS:-}"
  local entry letter target
  local entries

  entries=("${(@s:;:)maps}")
  for entry in "${entries[@]}"; do
    entry="$(gptk_trim "${entry}")"
    [[ -n "${entry}" ]] || continue

    if [[ "${entry}" != *"="* ]]; then
      gptk_die "invalid GPTK_DRIVE_MAPS entry '${entry}'; expected LETTER=/path"
    fi

    letter="$(gptk_trim "${entry%%=*}")"
    target="$(gptk_trim "${entry#*=}")"
    [[ -n "${letter}" && -n "${target}" ]] || gptk_die "invalid GPTK_DRIVE_MAPS entry '${entry}'; expected LETTER=/path"

    gptk_link_drive "${letter}" "${target}" "${prefix_path}"
  done
}

gptk_prepare_prefix_dirs() {
  local prefix_path="$1"
  mkdir -p "${prefix_path}" "${GPTK_LOG_DIR}" "${GPTK_GAMES_ROOT}"
  if [[ -d "${prefix_path}/drive_c" ]]; then
    gptk_link_configured_drives "${prefix_path}"
  fi
}

gptk_log_file() {
  local prefix_name="$1"
  local stamp
  stamp="$(date +%Y%m%d-%H%M%S)"
  print -r -- "${GPTK_LOG_DIR}/${prefix_name}-${stamp}.log"
}

gptk_run_logged() {
  local log_enabled="$1"
  local log_file="$2"
  shift 2

  if [[ "${log_enabled}" == "1" ]]; then
    mkdir -p "${log_file:h}"
    gptk_note "logging to ${log_file}"
    "$@" 2>&1 | tee -a "${log_file}"
    return ${pipestatus[1]}
  fi

  "$@"
}

gptk_init_defaults
