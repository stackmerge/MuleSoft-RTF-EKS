#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# create-eks-cluster.sh
# -----------------------------------------------------------------------------
# Creates an AWS EKS cluster with one managed node group and 3 worker nodes.
#
# Usage:
#   ./scripts/create-eks-cluster.sh
#
# Optional environment variables:
#   AWS_REGION=ap-south-1
#   CLUSTER_NAME=mulesoft-eks-cluster
#   NODEGROUP_NAME=standard-workers
#   NODE_TYPE=t3.medium
#   NODES=3
#   NODES_MIN=3
#   NODES_MAX=3
#   K8S_VERSION=1.30
#
# Example:
#   AWS_REGION=us-east-1 CLUSTER_NAME=rtf-lab ./scripts/create-eks-cluster.sh
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

AWS_REGION="${AWS_REGION:-ap-south-1}"
CLUSTER_NAME="${CLUSTER_NAME:-mulesoft-eks-cluster}"
NODEGROUP_NAME="${NODEGROUP_NAME:-standard-workers}"
NODE_TYPE="${NODE_TYPE:-t3.medium}"
NODES="${NODES:-3}"
NODES_MIN="${NODES_MIN:-3}"
NODES_MAX="${NODES_MAX:-3}"
K8S_VERSION="${K8S_VERSION:-}"

main() {
  require_cmd aws
  require_cmd eksctl
  require_cmd kubectl

  log "Validating AWS identity..."
  aws sts get-caller-identity >/dev/null

  log "Creating EKS cluster '${CLUSTER_NAME}' in region '${AWS_REGION}'..."
  log "Node group: ${NODEGROUP_NAME}, node type: ${NODE_TYPE}, desired nodes: ${NODES}"

  local version_args=()
  if [[ -n "${K8S_VERSION}" ]]; then
    version_args+=(--version "${K8S_VERSION}")
  fi

  eksctl create cluster \
    --name "${CLUSTER_NAME}" \
    --region "${AWS_REGION}" \
    --nodegroup-name "${NODEGROUP_NAME}" \
    --node-type "${NODE_TYPE}" \
    --nodes "${NODES}" \
    --nodes-min "${NODES_MIN}" \
    --nodes-max "${NODES_MAX}" \
    --managed

  log "Updating kubeconfig..."
  aws eks update-kubeconfig \
    --region "${AWS_REGION}" \
    --name "${CLUSTER_NAME}"

  log "Validating Kubernetes nodes..."
  kubectl get nodes -o wide

  log "EKS cluster creation completed."
}

main "$@"
