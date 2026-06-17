#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# Script Name  : apply-rtf-nginx-ingress-template.sh
# Purpose      : Generate and apply MuleSoft Runtime Fabric NGINX ingress
#                template on an existing Runtime Fabric Kubernetes namespace.
# Platform     : AWS EKS / Kubernetes
# Prerequisites: kubectl, active kubeconfig context, Runtime Fabric installed
# -----------------------------------------------------------------------------

# -----------------------------
# Configurable variables
# -----------------------------

# Kubernetes namespace where Runtime Fabric is installed.
RTF_NAMESPACE="${RTF_NAMESPACE:-rtf}"

# Runtime Fabric ingress template name.
INGRESS_TEMPLATE_NAME="${INGRESS_TEMPLATE_NAME:-rtf-nginx-ingress-template}"

# Runtime Fabric ingress class name.
# IMPORTANT: Runtime Fabric templates use the rtf- prefix.
INGRESS_CLASS_NAME="${INGRESS_CLASS_NAME:-rtf-nginx}"

# Domain used by Mule application endpoints.
# Example: rtf.muleaceacademy.com
RTF_DOMAIN="${RTF_DOMAIN:-rtf.example.com}"

# Placeholder app host used by the template.
# Runtime Fabric replaces placeholders during Mule application deployment.
RTF_APP_HOST="${RTF_APP_HOST:-app-name.${RTF_DOMAIN}}"

# Output manifest file path.
MANIFEST_FILE="${MANIFEST_FILE:-manifests/rtf-nginx-ingress-template.yaml}"

# NGINX timeout and payload settings.
PROXY_CONNECT_TIMEOUT="${PROXY_CONNECT_TIMEOUT:-60}"
PROXY_SEND_TIMEOUT="${PROXY_SEND_TIMEOUT:-300}"
PROXY_READ_TIMEOUT="${PROXY_READ_TIMEOUT:-300}"
PROXY_BODY_SIZE="${PROXY_BODY_SIZE:-20m}"

# TLS settings.
# Set ENABLE_TLS=true only after you create a TLS secret in the Runtime Fabric namespace.
ENABLE_TLS="${ENABLE_TLS:-false}"
TLS_SECRET_NAME="${TLS_SECRET_NAME:-rtf-wildcard-tls}"

# Control script behavior.
# Set GENERATE_ONLY=true to create the YAML without applying it.
GENERATE_ONLY="${GENERATE_ONLY:-false}"

# Set DRY_RUN=true to validate the generated manifest without applying it.
DRY_RUN="${DRY_RUN:-false}"

# -----------------------------
# Helper functions
# -----------------------------

info() {
  echo "[INFO] $*"
}

warn() {
  echo "[WARN] $*"
}

error() {
  echo "[ERROR] $*" >&2
  exit 1
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    error "Required command '$1' is not installed or not available in PATH."
  fi
}

# -----------------------------
# Pre-checks
# -----------------------------

require_command kubectl

CURRENT_CONTEXT="$(kubectl config current-context 2>/dev/null || true)"
if [[ -z "${CURRENT_CONTEXT}" ]]; then
  error "No active kubectl context found. Run aws eks update-kubeconfig first."
fi

info "Using Kubernetes context: ${CURRENT_CONTEXT}"

if ! kubectl get namespace "${RTF_NAMESPACE}" >/dev/null 2>&1; then
  error "Namespace '${RTF_NAMESPACE}' was not found. Install Runtime Fabric before applying the ingress template."
fi

mkdir -p "$(dirname "${MANIFEST_FILE}")"

# -----------------------------
# Generate manifest
# -----------------------------

info "Generating Runtime Fabric NGINX ingress template: ${MANIFEST_FILE}"

cat > "${MANIFEST_FILE}" <<YAML
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${INGRESS_TEMPLATE_NAME}
  namespace: ${RTF_NAMESPACE}
  annotations:
    # NGINX-specific annotations.
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "${PROXY_CONNECT_TIMEOUT}"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "${PROXY_SEND_TIMEOUT}"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "${PROXY_READ_TIMEOUT}"
    nginx.ingress.kubernetes.io/proxy-body-size: "${PROXY_BODY_SIZE}"
YAML

if [[ "${ENABLE_TLS}" == "true" ]]; then
  cat >> "${MANIFEST_FILE}" <<YAML
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
YAML
fi

cat >> "${MANIFEST_FILE}" <<YAML
spec:
  # Runtime Fabric uses the rtf- prefix to identify this ingress object
  # as a template. The actual NGINX ingress controller uses class "nginx".
  ingressClassName: ${INGRESS_CLASS_NAME}
YAML

if [[ "${ENABLE_TLS}" == "true" ]]; then
  cat >> "${MANIFEST_FILE}" <<YAML
  tls:
    - hosts:
        - "*.${RTF_DOMAIN}"
      secretName: ${TLS_SECRET_NAME}
YAML
fi

cat >> "${MANIFEST_FILE}" <<YAML
  rules:
    - host: ${RTF_APP_HOST}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                # Placeholder value used by Runtime Fabric during Mule app deployment.
                name: service-name
                port:
                  # Placeholder value used by Runtime Fabric during Mule app deployment.
                  name: service-port
YAML

info "Manifest generated successfully."

# -----------------------------
# Validate or apply manifest
# -----------------------------

if [[ "${GENERATE_ONLY}" == "true" ]]; then
  info "GENERATE_ONLY=true. Skipping kubectl apply."
  info "Generated file: ${MANIFEST_FILE}"
  exit 0
fi

if [[ "${DRY_RUN}" == "true" ]]; then
  info "DRY_RUN=true. Validating manifest using kubectl server-side dry run."
  kubectl apply --dry-run=server -f "${MANIFEST_FILE}"
  info "Dry run completed successfully."
  exit 0
fi

info "Applying Runtime Fabric NGINX ingress template..."
kubectl apply -f "${MANIFEST_FILE}"

info "Ingress template applied."

info "Current Runtime Fabric ingress resources:"
kubectl get ingress -n "${RTF_NAMESPACE}" || true

cat <<SUMMARY

Next steps:
1. Confirm your NGINX ingress controller has an AWS LoadBalancer DNS name:
   kubectl get svc ingress-nginx-controller -n ingress-nginx

2. Create wildcard DNS pointing to the NGINX LoadBalancer DNS name:
   *.${RTF_DOMAIN} -> <NGINX LoadBalancer DNS>

3. Deploy a Mule application to Runtime Fabric and test the generated endpoint.

SUMMARY
