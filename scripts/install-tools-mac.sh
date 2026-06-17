#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# install-tools-mac.sh
# -----------------------------------------------------------------------------
# Installs required local tools on macOS for MuleSoft Runtime Fabric on AWS EKS:
# - AWS CLI v2
# - eksctl
# - kubectl
# - Helm
# - rtfctl
#
# Usage:
#   ./scripts/install-tools-mac.sh
#
# Notes:
# - Requires macOS.
# - Requires sudo for AWS CLI installer and moving rtfctl into PATH.
# - Homebrew is required. This script does not install Homebrew automatically.
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

require_macos() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    error "This script is intended for macOS only."
    exit 1
  fi
}

require_homebrew() {
  if ! command -v brew >/dev/null 2>&1; then
    error "Homebrew is not installed. Install it from https://brew.sh and rerun this script."
    exit 1
  fi
}

install_aws_cli() {
  if command -v aws >/dev/null 2>&1; then
    log "AWS CLI already installed: $(aws --version 2>&1)"
    return
  fi

  log "Installing AWS CLI v2..."
  tmp_pkg="/tmp/AWSCLIV2.pkg"
  curl -fsSL "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "$tmp_pkg"
  sudo installer -pkg "$tmp_pkg" -target /
  rm -f "$tmp_pkg"

  log "AWS CLI installed: $(aws --version 2>&1)"
}

install_eksctl() {
  if command -v eksctl >/dev/null 2>&1; then
    log "eksctl already installed: $(eksctl version)"
    return
  fi

  log "Installing eksctl..."
  brew tap aws/tap
  brew install aws/tap/eksctl
  log "eksctl installed: $(eksctl version)"
}

install_kubectl() {
  if command -v kubectl >/dev/null 2>&1; then
    log "kubectl already installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
    return
  fi

  log "Installing kubectl..."
  brew install kubectl
  log "kubectl installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
}

install_helm() {
  if command -v helm >/dev/null 2>&1; then
    log "Helm already installed: $(helm version --short)"
    return
  fi

  log "Installing Helm..."
  brew install helm
  log "Helm installed: $(helm version --short)"
}

install_rtfctl() {
  if command -v rtfctl >/dev/null 2>&1; then
    log "rtfctl already installed."
    rtfctl version 2>/dev/null || rtfctl -h >/dev/null || true
    return
  fi

  local install_dir="/usr/local/bin"
  if [[ -d "/opt/homebrew/bin" && ":$PATH:" == *":/opt/homebrew/bin:"* ]]; then
    install_dir="/opt/homebrew/bin"
  fi

  log "Installing rtfctl to ${install_dir}..."
  curl -fsSL "https://anypoint.mulesoft.com/runtimefabric/api/download/rtfctl-darwin/latest" -o /tmp/rtfctl
  chmod +x /tmp/rtfctl
  sudo mv /tmp/rtfctl "${install_dir}/rtfctl"

  # Remove quarantine attribute if present.
  xattr -d com.apple.quarantine "${install_dir}/rtfctl" 2>/dev/null || true

  log "rtfctl installed at: $(command -v rtfctl)"
}

main() {
  require_macos
  require_homebrew

  install_aws_cli
  install_eksctl
  install_kubectl
  install_helm
  install_rtfctl

  echo
  log "Tool installation completed."
  echo "Run the following to validate AWS access:"
  echo "  aws sts get-caller-identity"
}

main "$@"
