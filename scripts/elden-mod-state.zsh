#!/bin/zsh

set -e
setopt pipe_fail

config="${HOME}/.rippermoon-gptk.env"
env_gptk_home="${GPTK_HOME:-}"
env_gptk_log_dir="${GPTK_LOG_DIR:-}"
[[ -r "${config}" ]] && source "${config}"
[[ -n "${env_gptk_home}" ]] && GPTK_HOME="${env_gptk_home}"
[[ -n "${env_gptk_log_dir}" ]] && GPTK_LOG_DIR="${env_gptk_log_dir}"
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"

GPTK_HOME="${GPTK_HOME:-${HOME}/GPTK}"
GPTK_LOG_DIR="${GPTK_LOG_DIR:-${GPTK_HOME}/logs}"
BACKUP_DIR="${GPTK_HOME}/backups/elden-ring-mods"

script_dir="${0:A:h}"
installer="${script_dir}/install-elden-mod-pack.zsh"
stamp="$(date +%Y%m%d-%H%M%S)"
mkdir -p "${GPTK_LOG_DIR}" "${BACKUP_DIR}"
log_file="${GPTK_LOG_DIR}/elden-mod-state-${stamp}.log"

command_name=""
game_dir=""
friend_kit=""
output=""
force=0

usage() {
  cat <<'USAGE'
Usage:
  scripts/elden-mod-state.zsh backup --game-dir PATH [--output PATH]
  scripts/elden-mod-state.zsh import-friend --game-dir PATH --friend-kit PATH [--force]

Commands:
  backup          Create a rollback ZIP of the Elden Ring mod footprint.
  import-friend   Import an elden-randomizer-coop friend kit into ModEngine.

Options:
  --game-dir PATH       Elden Ring Game folder containing eldenring.exe
  --friend-kit PATH     Friend kit folder or ZIP
  --output PATH         Backup ZIP destination
  --force              Reinstall bundled tools even if already present
  -h, --help            Show this help
USAGE
}

log() {
  local icon="$1"
  shift
  printf '%s [%s] %s\n' "${icon}" "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "${log_file}"
}

die() {
  log "❌" "$*"
  exit 1
}

json_value() {
  local json="$1"
  local key="$2"
  local value
  value="$(plutil -extract "${key}" raw -o - "${json}" 2>/dev/null || true)"
  if [[ -n "${value}" ]]; then
    print -r -- "${value}"
    return 0
  fi
  sed -nE "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\"([^\"]*)\".*/\1/p" "${json}" | head -n 1
}

cleanup_mac_sidecars() {
  local path="$1"
  [[ -d "${path}" ]] || return 0
  find "${path}" \( -name '._*' -o -name '.DS_Store' -o -name '__MACOSX' \) -print -exec rm -rf {} + >> "${log_file}" 2>&1 || true
}

copy_payload_item() {
  local source="$1"
  local dest="$2"
  mkdir -p "${dest:h}"
  if [[ -d "${source}" ]]; then
    ditto "${source}" "${dest}" >> "${log_file}" 2>&1
  else
    cp -p "${source}" "${dest}"
  fi
}

create_backup() {
  local game="$1"
  local destination="$2"
  local allow_empty="${3:-0}"
  local backup_items=(
    "ModEngine2"
    "SeamlessCoop"
    "toggle_anti_cheat.exe"
    "start_game_in_offline_mode.exe"
    "ersc_launcher.exe"
  )

  [[ -f "${game}/eldenring.exe" ]] || die "eldenring.exe not found in ${game}"

  if [[ -z "${destination}" ]]; then
    destination="${BACKUP_DIR}/elden-mod-state-${stamp}.zip"
  fi
  mkdir -p "${destination:h}"

  local stage
  stage="$(mktemp -d -t elden-mod-backup.XXXXXX)"
  local payload="${stage}/payload"
  mkdir -p "${payload}"

  local copied=0
  local item
  log "🛟" "Creating Elden Ring mod-state backup."
  for item in "${backup_items[@]}"; do
    if [[ -e "${game}/${item}" ]]; then
      log "📌" "Capturing ${item}"
      copy_payload_item "${game}/${item}" "${payload}/${item}"
      copied=1
    fi
  done

  if [[ "${copied}" != "1" ]]; then
    rm -rf "${stage}"
    if [[ "${allow_empty}" == "1" ]]; then
      log "⚠️" "No existing mod components found to back up in ${game}; continuing."
      return 1
    fi
    die "No mod components found to back up in ${game}"
  fi

  cat > "${stage}/manifest.json" <<JSON
{
  "version": 1,
  "createdAt": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "gamePath": "${game}",
  "items": [
    "ModEngine2",
    "SeamlessCoop",
    "toggle_anti_cheat.exe",
    "start_game_in_offline_mode.exe",
    "ersc_launcher.exe"
  ]
}
JSON

  rm -f "${destination}"
  (cd "${stage}" && zip -qry "${destination}" manifest.json payload) >> "${log_file}" 2>&1
  rm -rf "${stage}"

  log "✅" "Backup written: ${destination}"
  print -r -- "${destination}"
}

resolve_friend_root() {
  local source="$1"
  local extract_dir="$2"
  if [[ -f "${source}" ]]; then
    log "📦" "Extracting friend kit: ${source}"
    mkdir -p "${extract_dir}"
    unzip -oq "${source}" -d "${extract_dir}" >> "${log_file}" 2>&1
    cleanup_mac_sidecars "${extract_dir}"
    find "${extract_dir}" -maxdepth 4 -type f -name friend-config.json -print | head -n 1
  else
    find "${source}" -maxdepth 4 -type f -name friend-config.json -print | head -n 1
  fi
}

normalize_friend_inputs() {
  local root="$1"
  local dest="$2"
  mkdir -p "${dest}"

  local zip
  local count=0
  while IFS= read -r zip; do
    local name="${zip:t}"
    name="${name//\\/_}"
    cp -p "${zip}" "${dest}/${name}"
    log "📦" "Staged bundled ZIP: ${name}"
    count=$((count + 1))
  done < <(find "${root}" -maxdepth 5 -type f -name '*.zip' -print)

  [[ "${count}" -gt 0 ]] || die "No mod ZIPs found in friend kit."
}

set_ersc_password() {
  local ini="$1"
  local password="$2"
  [[ -n "${password}" ]] || return 0
  [[ -f "${ini}" ]] || die "Cannot set friend password; missing ${ini}"

  local tmp
  tmp="$(mktemp -t ersc-settings.XXXXXX)"
  awk -v password="${password}" '
    BEGIN { in_password=0; replaced=0 }
    /^\[[^]]+\][[:space:]]*$/ {
      if (tolower($0) == "[password]") { in_password=1 } else { in_password=0 }
      print
      next
    }
    in_password && /^[[:space:]]*cooppassword[[:space:]]*=/ {
      print "cooppassword = " password
      replaced=1
      next
    }
    { print }
    END {
      if (!replaced) {
        print ""
        print "[PASSWORD]"
        print "cooppassword = " password
      }
    }
  ' "${ini}" > "${tmp}"
  cp -p "${ini}" "${ini}.${stamp}.bak"
  mv "${tmp}" "${ini}"
  log "🔐" "Updated Seamless Coop password from friend kit; previous INI was backed up."
}

import_friend() {
  local game="$1"
  local kit="$2"

  [[ -f "${game}/eldenring.exe" ]] || die "eldenring.exe not found in ${game}"
  [[ -e "${kit}" ]] || die "Friend kit not found: ${kit}"
  [[ -x "${installer}" ]] || die "Installer script not found or not executable: ${installer}"

  local import_stage
  import_stage="$(mktemp -d -t elden-friend-import.XXXXXX)"
  local cfg_path
  cfg_path="$(resolve_friend_root "${kit}" "${import_stage}/kit")"
  [[ -n "${cfg_path}" && -f "${cfg_path}" ]] || die "friend-config.json not found in friend kit."

  local root="${cfg_path:h}"
  local seed_file
  local password
  seed_file="$(json_value "${cfg_path}" "seedFile")"
  password="$(json_value "${cfg_path}" "password")"
  [[ -n "${seed_file}" ]] || die "friend-config.json is missing seedFile."

  log "🤝" "Friend kit detected."
  log "🌱" "Seed/options file: ${seed_file}"
  if [[ -n "${password}" ]]; then
    log "🔐" "Friend password present; it will be applied without printing it."
  else
    log "⚠️" "No password found in friend-config.json."
  fi

  local seed_path
  seed_path="$(find "${root}" -maxdepth 5 -type f -name "${seed_file}" -print | head -n 1)"
  [[ -n "${seed_path}" && -f "${seed_path}" ]] || die "Seed/options file not found: ${seed_file}"

  local backup_path="${BACKUP_DIR}/elden-mod-state-${stamp}-pre-friend-import.zip"
  if create_backup "${game}" "${backup_path}" "1"; then
    log "🛡️" "Rollback backup created before import: ${backup_path}"
  else
    log "🛡️" "No rollback backup was needed before import."
  fi

  local inputs="${import_stage}/inputs"
  normalize_friend_inputs "${root}" "${inputs}"

  local install_args=(--game-dir "${game}" --inputs-dir "${inputs}")
  if [[ "${force}" == "1" ]]; then
    install_args+=(--force)
  fi
  log "🧩" "Installing friend kit mod components."
  zsh "${installer}" "${install_args[@]}" >> "${log_file}" 2>&1

  local randomizer_dir="${game}/ModEngine2/randomizer"
  mkdir -p "${randomizer_dir}"
  cp -p "${seed_path}" "${randomizer_dir}/${seed_file}"
  log "🌱" "Copied ${seed_file} into ${randomizer_dir}"

  set_ersc_password "${game}/SeamlessCoop/ersc_settings.ini" "${password}"
  cleanup_mac_sidecars "${game}/ModEngine2"
  cleanup_mac_sidecars "${game}/SeamlessCoop"

  rm -rf "${import_stage}"
  log "✅" "Friend kit import complete."
  log "ℹ️" "Next: Run Randomizer, import ${seed_file}, click Randomize, then Launch Modded."
}

if [[ $# -eq 0 ]]; then
  usage
  exit 2
fi

command_name="$1"
shift

while [[ $# -gt 0 ]]; do
  case "$1" in
    --game-dir)
      game_dir="$2"
      shift 2
      ;;
    --friend-kit)
      friend_kit="$2"
      shift 2
      ;;
    --output)
      output="$2"
      shift 2
      ;;
    --force)
      force=1
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

[[ -n "${game_dir}" ]] || die "--game-dir is required"
game_dir="${game_dir:A}"

case "${command_name}" in
  backup)
    create_backup "${game_dir}" "${output}"
    ;;
  import-friend)
    [[ -n "${friend_kit}" ]] || die "--friend-kit is required"
    friend_kit="${friend_kit:A}"
    import_friend "${game_dir}" "${friend_kit}"
    ;;
  *)
    print -u2 -- "unknown command: ${command_name}"
    usage
    exit 2
    ;;
esac
