#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# install-nginx-ingress.sh
# -----------------------------------------------------------------------------
# Installs NGINX Ingress Controller on EKS using Helm.
# This is the recommended simple ingress option for Runtime Fabric labs.
#
# Usage:
#   ./scripts/install-nginx-ingress.sh
#
# Optional environment variables:
#   INGRESS_NAMESPACE=ingress-nginx
#   INGRESS_RELEASE_NAME=ingress-nginx
#   INGRESS_CLASS=nginx
#   SERVICE_TYPE=LoadBalancer
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

INGRESS_NAMESPACE="${INGRESS_NAMESPACE:-ingress-nginx}"
INGRESS_RELEASE_NAME="${INGRESS_RELEASE_NAME:-ingress-nginx}"
INGRESS_CLASS="${INGRESS_CLASS:-nginx}"
SERVICE_TYPE="${SERVICE_TYPE:-LoadBalancer}"

main() {
  require_cmd kubectl
  require_cmd helm

  log "Current Kubernetes context: $(kubectl config current-context)"

  log "Adding/updating ingress-nginx Helm repository..."
  helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx >/dev/null 2>&1 || true
  helm repo update

  log "Installing/upgrading NGINX Ingress Controller..."
  helm upgrade --install "${INGRESS_RELEASE_NAME}" ingress-nginx/ingress-nginx \
    --namespace "${INGRESS_NAMESPACE}" \
    --create-namespace \
    --set controller.service.type="${SERVICE_TYPE}" \
    --set controller.ingressClassResource.name="${INGRESS_CLASS}" \
    --set controller.ingressClass="${INGRESS_CLASS}"

  log "Waiting for ingress controller rollout..."
  kubectl rollout status deployment/"${INGRESS_RELEASE_NAME}"-controller \
    -n "${INGRESS_NAMESPACE}" \
    --timeout=300s

  log "Ingress controller pods:"
  kubectl get pods -n "${INGRESS_NAMESPACE}"

  log "Ingress controller service:"
  kubectl get svc -n "${INGRESS_NAMESPACE}"

  echo
  log "If EXTERNAL-IP is pending, wait 1-3 minutes and rerun:"
  echo "  kubectl get svc -n ${INGRESS_NAMESPACE}"
}

main "$@"
