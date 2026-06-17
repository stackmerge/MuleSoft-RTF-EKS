#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# uninstall-rtf-and-eks.sh
# -----------------------------------------------------------------------------
# Uninstalls MuleSoft Runtime Fabric, removes NGINX ingress, and deletes the EKS
# cluster created for this use case.
#
# Usage:
#   ./scripts/uninstall-rtf-and-eks.sh
#
# Optional environment variables:
#   AWS_REGION=ap-south-1
#   CLUSTER_NAME=mulesoft-eks-cluster
#   INGRESS_NAMESPACE=ingress-nginx
#   INGRESS_RELEASE_NAME=ingress-nginx
#   SKIP_RTF_UNINSTALL=false
#   SKIP_INGRESS_UNINSTALL=false
#   SKIP_CLUSTER_DELETE=false
#   AUTO_APPROVE=false
#
# Important:
# - Delete Mule apps/API gateways from Anypoint Runtime Manager first.
# - Delete Runtime Fabric from Runtime Manager first.
# - This script deletes cloud resources and can impact workloads.
# -----------------------------------------------------------------------------

log() {
  echo "[INFO] $*"
}

warn() {
  echo "[WARN] $*"
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

AWS_REGION="${AWS_REGION:-ap-south-1}"
CLUSTER_NAME="${CLUSTER_NAME:-mulesoft-eks-cluster}"
INGRESS_NAMESPACE="${INGRESS_NAMESPACE:-ingress-nginx}"
INGRESS_RELEASE_NAME="${INGRESS_RELEASE_NAME:-ingress-nginx}"
SKIP_RTF_UNINSTALL="${SKIP_RTF_UNINSTALL:-false}"
SKIP_INGRESS_UNINSTALL="${SKIP_INGRESS_UNINSTALL:-false}"
SKIP_CLUSTER_DELETE="${SKIP_CLUSTER_DELETE:-false}"
AUTO_APPROVE="${AUTO_APPROVE:-false}"

confirm() {
  if [[ "${AUTO_APPROVE}" == "true" ]]; then
    return
  fi

  echo
  warn "This will uninstall Runtime Fabric resources and delete EKS cluster '${CLUSTER_NAME}' in region '${AWS_REGION}'."
  warn "Confirm that Mule apps/API gateways and Runtime Fabric were deleted from Anypoint Runtime Manager."
  read -r -p "Type DELETE to continue: " answer
  if [[ "${answer}" != "DELETE" ]]; then
    error "Aborted."
    exit 1
  fi
}

main() {
  require_cmd aws
  require_cmd eksctl
  require_cmd kubectl
  require_cmd helm

  confirm

  log "Updating kubeconfig for cluster '${CLUSTER_NAME}'..."
  aws eks update-kubeconfig \
    --region "${AWS_REGION}" \
    --name "${CLUSTER_NAME}" || warn "Could not update kubeconfig. Cluster may already be deleted."

  if [[ "${SKIP_RTF_UNINSTALL}" != "true" ]]; then
    if command -v rtfctl >/dev/null 2>&1; then
      log "Attempting Runtime Fabric uninstall using rtfctl..."
      rtfctl uninstall || warn "rtfctl uninstall failed or Runtime Fabric was already removed. Continue with cleanup."
    else
      warn "rtfctl not found. Skipping rtfctl uninstall."
    fi

    log "Deleting rtf namespace if it exists..."
    kubectl delete namespace rtf --ignore-not-found=true || true
  else
    warn "Skipping Runtime Fabric uninstall because SKIP_RTF_UNINSTALL=true"
  fi

  if [[ "${SKIP_INGRESS_UNINSTALL}" != "true" ]]; then
    log "Uninstalling NGINX ingress Helm release if present..."
    helm uninstall "${INGRESS_RELEASE_NAME}" -n "${INGRESS_NAMESPACE}" || warn "Ingress release not found or already removed."

    log "Deleting ingress namespace if it exists..."
    kubectl delete namespace "${INGRESS_NAMESPACE}" --ignore-not-found=true || true
  else
    warn "Skipping ingress uninstall because SKIP_INGRESS_UNINSTALL=true"
  fi

  log "Checking for remaining LoadBalancer services..."
  kubectl get svc -A | grep LoadBalancer || true

  if [[ "${SKIP_CLUSTER_DELETE}" != "true" ]]; then
    log "Deleting EKS cluster '${CLUSTER_NAME}' in region '${AWS_REGION}'..."
    eksctl delete cluster \
      --name "${CLUSTER_NAME}" \
      --region "${AWS_REGION}" \
      --wait
  else
    warn "Skipping cluster deletion because SKIP_CLUSTER_DELETE=true"
  fi

  log "Teardown completed."
}

main "$@"
