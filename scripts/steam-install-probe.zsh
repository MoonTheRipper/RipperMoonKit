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
  steam-install-probe.zsh --appid APPID [options]

Watches a Steam install/update and records the exact SteamPipe state where it
completes or fails. This script does not delete game files and does not start
downloads by itself; start the install in Steam first, then run the probe.

Options:
  --appid APPID              Steam AppID to watch. Required.
  --depot DEPOTID            Expected depot ID. Can be repeated.
  --prefix PREFIX            Steam Wine prefix. Default: Steam.
  --library PATH             Steam library root. Default: GPTK_STEAM_LIBRARY.
  --timeout SECONDS          Watch duration. Default: 7200.
  --interval SECONDS         Poll interval. Default: 10.
  --snapshot                 Print one report and exit.
  --log-file PATH            Report path. Default: GPTK/logs/steam-install-probe-APPID-*.log.
  -h, --help                 Show this help.

Examples:
  gptk-steam-probe --appid 1196590 --depot 1196591 --library /Volumes/GAMECORE-1/SteamLibrary
  zsh scripts/steam-install-probe.zsh --appid 1196590 --snapshot
USAGE
}

appid=""
prefix="${GPTK_STEAM_PREFIX:-Steam}"
library="${GPTK_STEAM_LIBRARY:-}"
timeout="${STEAM_PROBE_TIMEOUT:-7200}"
interval="${STEAM_PROBE_INTERVAL:-10}"
snapshot_only=0
log_file=""
depots=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --appid)
      [[ $# -ge 2 ]] || gptk_die "--appid requires a value"
      appid="$2"
      shift 2
      ;;
    --depot)
      [[ $# -ge 2 ]] || gptk_die "--depot requires a value"
      depots+=("$2")
      shift 2
      ;;
    --prefix)
      [[ $# -ge 2 ]] || gptk_die "--prefix requires a value"
      prefix="$2"
      shift 2
      ;;
    --library)
      [[ $# -ge 2 ]] || gptk_die "--library requires a path"
      library="$2"
      shift 2
      ;;
    --timeout)
      [[ $# -ge 2 && "$2" == <-> ]] || gptk_die "--timeout requires seconds"
      timeout="$2"
      shift 2
      ;;
    --interval)
      [[ $# -ge 2 && "$2" == <-> ]] || gptk_die "--interval requires seconds"
      interval="$2"
      shift 2
      ;;
    --snapshot)
      snapshot_only=1
      shift
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
for depot in "${depots[@]}"; do
  [[ "${depot}" == <-> ]] || gptk_die "Depot ID must be numeric: ${depot}"
done

prefix_path="$(gptk_resolve_prefix "${prefix}")"
steam_root="${prefix_path}/drive_c/Program Files (x86)/Steam"
steamapps="${steam_root}/steamapps"
[[ -n "${library}" ]] && steamapps="${library}/steamapps"

manifest="${steamapps}/appmanifest_${appid}.acf"
content_log="${steam_root}/logs/content_log.txt"
console_log="${steam_root}/logs/console_log.txt"

if [[ -z "${log_file}" ]]; then
  mkdir -p "${GPTK_LOG_DIR}"
  log_file="${GPTK_LOG_DIR}/steam-install-probe-${appid}-$(date +%Y%m%d-%H%M%S).log"
fi
mkdir -p "${log_file:h}"

log() {
  printf '%s [%s] %s\n' "$1" "$(date '+%Y-%m-%d %H:%M:%S')" "$2" | tee -a "${log_file}"
}

acf_value() {
  local key="$1"
  [[ -f "${manifest}" ]] || return 0
  awk -v key="${key}" '
    $0 ~ "\"" key "\"" {
      n = split($0, parts, "\"")
      if (n >= 4) {
        print parts[4]
        exit
      }
    }
  ' "${manifest}"
}

acf_depots() {
  local section="$1"
  [[ -f "${manifest}" ]] || return 0
  awk -v section="${section}" '
    $0 ~ "\"" section "\"" {
      in_section = 1
      depth = 0
      next
    }
    in_section {
      line = $0
      if (depth == 1 && line ~ /^[[:space:]]*"[0-9]+"[[:space:]]*$/) {
        gsub(/[[:space:]\"]/, "", line)
        print line
      }
      opens = gsub(/{/, "{")
      closes = gsub(/}/, "}")
      depth += opens - closes
      if (depth < 1 && closes > 0) {
        exit
      }
    }
  ' "${manifest}" | sort -u
}

recent_failures() {
  [[ -f "${content_log}" ]] || return 0
  local id_pattern="AppID ${appid}"
  local depot
  for depot in "${depots[@]}"; do
    id_pattern="${id_pattern}|depot/${depot}|depot ${depot}"
  done

  if command -v rg >/dev/null 2>&1; then
    tail -n 500 "${content_log}" | rg -i "Corrupt download|Unpack failed|Failed updating depot|missing file privileges|disk write failure|update canceled" | rg -i "${id_pattern}" || true
  else
    tail -n 500 "${content_log}" | egrep -i "Corrupt download|Unpack failed|Failed updating depot|missing file privileges|disk write failure|update canceled" | egrep -i "${id_pattern}" || true
  fi
}

steam_net_assertions() {
  [[ -f "${console_log}" ]] || {
    print -r -- "0"
    return 0
  }
  if command -v rg >/dev/null 2>&1; then
    rg -c "BGetBoundAddr|SIO_ADDRESS_LIST_SORT|SIO_IDEAL_SEND_BACKLOG" "${console_log}" 2>/dev/null || print -r -- "0"
  else
    egrep -c "BGetBoundAddr|SIO_ADDRESS_LIST_SORT|SIO_IDEAL_SEND_BACKLOG" "${console_log}" 2>/dev/null || print -r -- "0"
  fi
}

manifest_success() {
  [[ -f "${manifest}" ]] || return 1

  local buildid size installed depot
  buildid="$(acf_value buildid)"
  size="$(acf_value SizeOnDisk)"
  installed="$(acf_depots InstalledDepots)"

  [[ "${buildid}" == <-> && "${buildid}" -gt 0 ]] || return 1
  [[ "${size}" == <-> && "${size}" -gt 0 ]] || return 1

  if [[ "${#depots[@]}" -gt 0 ]]; then
    for depot in "${depots[@]}"; do
      print -r -- "${installed}" | grep -qx "${depot}" || return 1
    done
  else
    [[ -n "${installed}" ]] || return 1
  fi

  return 0
}

write_report() {
  local stateflags buildid size installed staged downloading tempdir failures net_assertions

  stateflags="$(acf_value StateFlags)"
  buildid="$(acf_value buildid)"
  size="$(acf_value SizeOnDisk)"
  installed="$(acf_depots InstalledDepots | tr '\n' ' ')"
  staged="$(acf_depots StagedDepots | tr '\n' ' ')"
  downloading="${steamapps}/downloading/${appid}"
  tempdir="${steamapps}/temp/${appid}"
  failures="$(recent_failures)"
  net_assertions="$(steam_net_assertions)"

  {
    print -r -- ""
    print -r -- "=== Steam Install Probe: $(date '+%Y-%m-%d %H:%M:%S') ==="
    print -r -- "AppID: ${appid}"
    print -r -- "Expected depots: ${depots[*]:-any}"
    print -r -- "Prefix: ${prefix_path}"
    print -r -- "Steam root: ${steam_root}"
    print -r -- "Steam apps: ${steamapps}"
    print -r -- "Manifest: ${manifest}"
    print -r -- "Manifest exists: $([[ -f "${manifest}" ]] && print yes || print no)"
    print -r -- "StateFlags: ${stateflags:-missing}"
    print -r -- "BuildID: ${buildid:-missing}"
    print -r -- "SizeOnDisk: ${size:-missing}"
    print -r -- "InstalledDepots: ${installed:-missing}"
    print -r -- "StagedDepots: ${staged:-missing}"
    print -r -- "Downloading dir: $([[ -d "${downloading}" ]] && print present || print missing)"
    print -r -- "Temp dir: $([[ -d "${tempdir}" ]] && print present || print missing)"
    print -r -- "Steam networking assertions in console log: ${net_assertions}"
    print -r -- ""
    print -r -- "Disk:"
    df -h "${steamapps:h}" 2>/dev/null || true
    print -r -- ""
    print -r -- "Recent Steam content failures:"
    [[ -n "${failures}" ]] && print -r -- "${failures}" || print -r -- "none"
  } >> "${log_file}"

  log "📍" "StateFlags=${stateflags:-missing} BuildID=${buildid:-missing} SizeOnDisk=${size:-missing} InstalledDepots=${installed:-missing} StagedDepots=${staged:-missing}"
}

log "🧪" "Watching Steam install for AppID ${appid}."
log "🪵" "Probe log: ${log_file}"
log "📁" "Steam apps folder: ${steamapps}"

write_report

if [[ "${snapshot_only}" == "1" ]]; then
  log "✅" "Snapshot complete."
  exit 0
fi

deadline=$(( SECONDS + timeout ))
while (( SECONDS <= deadline )); do
  if manifest_success; then
    write_report
    log "✅" "Install looks complete. Manifest has buildid, size, and expected depot state."
    exit 0
  fi

  if [[ -n "$(recent_failures)" ]]; then
    write_report
    log "❌" "Steam content install failure detected. Keep this log for patch work."
    exit 80
  fi

  sleep "${interval}"
done

write_report
log "⏳" "Timed out after ${timeout}s without success or a captured Steam content failure."
exit 124
