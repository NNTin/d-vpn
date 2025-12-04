#!/usr/bin/with-contenv bash
set -euo pipefail

log() {
  echo "[init-wireguard] $*"
}

error_exit() {
  log "ERROR: $*"
  exit 1
}

ensure_keys() {
  local server_dir="/config/server"
  local private_key_path="${server_dir}/privatekey-server"
  local public_key_path="${server_dir}/publickey-server"

  mkdir -p "$server_dir"

  if [[ -f "$private_key_path" && -s "$private_key_path" ]]; then
    log "Server private key already present; skipping generation."
  else
    log "Generating WireGuard server keys..."
    wg genkey | tee "$private_key_path" | wg pubkey > "$public_key_path" || error_exit "Failed to generate WireGuard keys."
    chmod 600 "$private_key_path"
    chmod 644 "$public_key_path"
    log "Server keys generated at ${server_dir}."
  fi

  if [[ ! -f "$public_key_path" || ! -s "$public_key_path" ]]; then
    log "Public key missing or empty; regenerating from existing private key."
    wg pubkey < "$private_key_path" > "$public_key_path" || error_exit "Failed to regenerate public key."
    chmod 644 "$public_key_path"
  fi
}

populate_config() {
  local interface_subnet="${INTERFACE:-10.13.13}"
  local template_path="/config/templates/server.conf"
  local config_dir="/config/wg_confs"
  local config_path="${config_dir}/wg0.conf"
  local private_key_path="/config/server/privatekey-server"

  mkdir -p "$config_dir"

  if [[ -s "$config_path" ]]; then
    chmod 600 "$config_path" || log "Warning: unable to set permissions on ${config_path}"
    log "Existing wg0.conf detected; skipping template rendering."
    return
  fi

  [[ -f "$template_path" ]] || error_exit "Template not found at ${template_path}."
  [[ -f "$private_key_path" && -s "$private_key_path" ]] || error_exit "Private key missing at ${private_key_path}."

  local server_private_key
  server_private_key=$(cat "$private_key_path")

  local template_content
  template_content=$(cat "$template_path")

  # Replace INTERFACE placeholder and embed the generated private key.
  local rendered_config="${template_content//\$\{INTERFACE\}/$interface_subnet}"
  local key_placeholder="\$(cat /config/server/privatekey-server)"
  rendered_config="${rendered_config//$key_placeholder/$server_private_key}"

  printf '%s\n' "$rendered_config" > "$config_path" || error_exit "Failed to write wg0.conf."
  chmod 600 "$config_path"
  log "wg0.conf populated from template."
}

main() {
  log "Starting WireGuard initialization."
  ensure_keys
  populate_config
  log "WireGuard initialization complete."
}

main "$@"
