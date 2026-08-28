#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# deploy.sh — Deploy the Image Recognition App to a student namespace
#
# Usage (from inside the workbench JupyterLab terminal):
#   cd ~/lab-materials/notebooks/05-app
#   bash deploy.sh <namespace> <inference_url>
#
# Example:
#   bash deploy.sh student01 \
#     https://image-classifier-student01.apps.itz-t53413.hub01-lb.techzone.ibm.com
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

NAMESPACE="${1:-}"
INFERENCE_URL="${2:-}"

if [[ -z "${NAMESPACE}" || -z "${INFERENCE_URL}" ]]; then
  echo "Usage: bash $0 <namespace> <inference_url>"
  exit 1
fi

# The data-connection secret is named <namespace>-data-connection
SECRET_NAME="${NAMESPACE}-data-connection"

echo "══════════════════════════════════════════════════════"
echo " Deploying Image Recognition App"
echo "══════════════════════════════════════════════════════"
echo " Namespace      : ${NAMESPACE}"
echo " Inference URL  : ${INFERENCE_URL}"
echo " S3 secret      : ${SECRET_NAME}"
echo "══════════════════════════════════════════════════════"
echo ""

# ── Grant image-puller RBAC so the namespace can pull registry.redhat.io images
# that are cached via the OpenShift global pull secret (required for postgresql).
echo "Granting image-puller RBAC for openshift namespace images..."
oc policy add-role-to-user system:image-puller \
  "system:serviceaccount:${NAMESPACE}:default" \
  -n openshift 2>/dev/null || true

# ── Create a temp overlay dir with real values substituted ─────────────────
WORK_TMPDIR=$(mktemp -d)
trap "rm -rf ${WORK_TMPDIR}" EXIT

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "${WORK_TMPDIR}/base" "${WORK_TMPDIR}/student"
cp -r "${SCRIPT_DIR}/base/."             "${WORK_TMPDIR}/base/"
cp -r "${SCRIPT_DIR}/overlays/student/." "${WORK_TMPDIR}/student/"

KUST="${WORK_TMPDIR}/student/kustomization.yaml"
BASE_BACKEND="${WORK_TMPDIR}/base/backend.yaml"

# The overlay references '../../base'; in the temp dir it is at '../base'
sed -i "s|../../base|../base|g"                              "${KUST}"

# Derive the backend route hostname — pattern is backend-<namespace>.<cluster-domain>
CLUSTER_DOMAIN=$(echo "${INFERENCE_URL}" | sed 's|https://[^.]*\.\([^/]*\).*|\1|')
BACKEND_URL="https://backend-${NAMESPACE}.${CLUSTER_DOMAIN}"

# Substitute all placeholders (Linux sed — no backup extension needed)
sed -i "s|STUDENT_NAMESPACE_PLACEHOLDER|${NAMESPACE}|g"      "${KUST}"
sed -i "s|INFERENCE_URL_PLACEHOLDER|${INFERENCE_URL}|g"       "${KUST}"
sed -i "s|STUDENT_SECRET_NAME_PLACEHOLDER|${SECRET_NAME}|g"  "${KUST}"
sed -i "s|STUDENT_SECRET_PLACEHOLDER|${SECRET_NAME}|g"       "${BASE_BACKEND}"
# Inject the backend URL into the frontend HTML so the browser knows where to POST
sed -i "s|__BACKEND_URL__|${BACKEND_URL}|g"                  "${WORK_TMPDIR}/base/frontend.yaml"

echo "Backend URL injected into frontend: ${BACKEND_URL}"

echo "Applying manifests..."
oc apply -k "${WORK_TMPDIR}/student/" -n "${NAMESPACE}"

echo ""
echo "Waiting for PostgreSQL (up to 3 min)..."
oc rollout status deployment/postgresql -n "${NAMESPACE}" --timeout=180s

echo "Waiting for backend (up to 5 min — installs Python packages on first start)..."
oc rollout status deployment/backend -n "${NAMESPACE}" --timeout=300s

echo "Waiting for frontend (up to 2 min)..."
oc rollout status deployment/frontend -n "${NAMESPACE}" --timeout=120s

echo ""
ROUTE=$(oc get route image-rec-app -n "${NAMESPACE}" \
  -o jsonpath='https://{.spec.host}' 2>/dev/null || echo "Route not found")
BACKEND_ROUTE=$(oc get route backend -n "${NAMESPACE}" \
  -o jsonpath='https://{.spec.host}' 2>/dev/null || echo "Route not found")

echo "════════════════════════════════════════════════════"
echo " ✅ Deployment complete!"
echo "════════════════════════════════════════════════════"
echo " App URL     : ${ROUTE}"
echo " Backend URL : ${BACKEND_ROUTE}"
echo " Health      : ${BACKEND_ROUTE}/health"
echo "════════════════════════════════════════════════════"
