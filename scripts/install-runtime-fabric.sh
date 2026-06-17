#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# install-runtime-fabric.sh
# -----------------------------------------------------------------------------
# Validates and installs MuleSoft Runtime Fabric on the current Kubernetes context.
#
# Usage options:
#   RTF_ACTIVATION_DATA='<activation-data>' ./scripts/install-runtime-fabric.sh
#   ./scripts/install-runtime-fabric.sh '<activation-data>'
#   ./scripts/install-runtime-fabric.sh --activation-file ./activation-data.txt
#
# Important:
# - Create the Runtime Fabric in Anypoint Runtime Manager first.
# - Copy the activation data from Runtime Manager.
# - Do not commit activation data to GitHub.
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

ACTIVATION_DATA="${RTF_ACTIVATION_DATA:-}"

parse_args() {
  if [[ $# -eq 1 && "$1" != "--activation-file" ]]; then
    ACTIVATION_DATA="$1"
  elif [[ $# -eq 2 && "$1" == "--activation-file" ]]; then
    if [[ ! -f "$2" ]]; then
      error "Activation file not found: $2"
      exit 1
    fi
    ACTIVATION_DATA="$(cat "$2")"
  elif [[ $# -gt 0 ]]; then
    error "Invalid arguments. Usage: RTF_ACTIVATION_DATA='<activation-data>' $0 OR $0 --activation-file ./activation-data.txt"
    exit 1
  fi
}

main() {
  parse_args "$@"

  require_cmd kubectl
  require_cmd rtfctl

  if [[ -z "${ACTIVATION_DATA}" ]]; then
    error "Runtime Fabric activation data is required. Set RTF_ACTIVATION_DATA, pass it as an argument, or use --activation-file."
    exit 1
  fi

  log "Current Kubernetes context: $(kubectl config current-context)"
  log "Validating Kubernetes nodes..."
  kubectl get nodes

  log "Validating cluster for Runtime Fabric installation..."
  rtfctl validate "${ACTIVATION_DATA}"

  log "Installing Runtime Fabric..."
  rtfctl install "${ACTIVATION_DATA}"

  log "Runtime Fabric namespace and pods:"
  kubectl get ns | grep -E '^rtf\s' || true
  kubectl get pods -n rtf || true

  log "Runtime Fabric status:"
  rtfctl status || true

  echo
  log "Next steps:"
  echo "  1. Verify Runtime Fabric status is Active in Anypoint Runtime Manager."
  echo "  2. Apply Mule license using ./scripts/apply-mule-license.sh /path/to/license.lic"
  echo "  3. Associate Runtime Fabric with your Anypoint environment."
  echo "  4. Apply manifests/rtf-nginx-ingress-template.yaml after adjusting host/domain."
}

main "$@"
