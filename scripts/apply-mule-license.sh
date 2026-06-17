#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# apply-mule-license.sh
# -----------------------------------------------------------------------------
# Applies MuleSoft enterprise license to Runtime Fabric.
#
# Usage:
#   ./scripts/apply-mule-license.sh /path/to/license.lic
#
# Optional environment variable:
#   MULE_LICENSE_FILE=/path/to/license.lic ./scripts/apply-mule-license.sh
# -----------------------------------------------------------------------------

log() {
  echo "[INFO] $*"
}

error() {
  echo "[ERROR] $*" >&2
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    error "Required command not found: $1"
    exit 1
  fi
}

LICENSE_FILE="${MULE_LICENSE_FILE:-${1:-}}"

main() {
  require_cmd rtfctl
  require_cmd kubectl

  if [[ -z "${LICENSE_FILE}" ]]; then
    error "License file path is required. Usage: $0 /path/to/license.lic"
    exit 1
  fi

  if [[ ! -f "${LICENSE_FILE}" ]]; then
    error "License file not found: ${LICENSE_FILE}"
    exit 1
  fi

  log "Current Kubernetes context: $(kubectl config current-context)"
  log "Applying Mule license from: ${LICENSE_FILE}"

  rtfctl apply mule-license --file "${LICENSE_FILE}"

  log "Verifying Mule license..."
  rtfctl get mule-license

  log "Mule license applied successfully."
}

main "$@"
