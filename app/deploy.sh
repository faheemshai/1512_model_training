#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# deploy.sh — Deploy the Image Recognition App to a student namespace
#
# Usage:
#   ./deploy.sh <student_namespace> <inference_url>
#
# Example:
#   ./deploy.sh student01 https://image-classifier-student01.apps.itz-t53413.hub01-lb.techzone.ibm.com
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

NAMESPACE="${1:-}"
INFERENCE_URL="${2:-}"

if [[ -z "${NAMESPACE}" || -z "${INFERENCE_URL}" ]]; then
  echo "Usage: $0 <namespace> <inference_url>"
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

# Create a temp overlay dir with real values substituted
TMPDIR=$(mktemp -d)
trap "rm -rf ${TMPDIR}" EXIT

# Recreate the expected directory structure:
#   TMPDIR/
#     base/         ← copy of 05-app/base
#     student/      ← copy of 05-app/overlays/student  (references ../../base → ../base)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "${TMPDIR}/base" "${TMPDIR}/student"
cp -r "${SCRIPT_DIR}/base/."             "${TMPDIR}/base/"
cp -r "${SCRIPT_DIR}/overlays/student/." "${TMPDIR}/student/"

KUST="${TMPDIR}/student/kustomization.yaml"
BASE_BACKEND="${TMPDIR}/base/backend.yaml"

# The overlay uses '../../base' but in tmpdir it is at '../base' — fix path
sed -i "s|../../base|../base|g" "${KUST}"

# Linux-compatible sed substitutions
sed -i "s|STUDENT_NAMESPACE_PLACEHOLDER|${NAMESPACE}|g"       "${KUST}"
sed -i "s|INFERENCE_URL_PLACEHOLDER|${INFERENCE_URL}|g"        "${KUST}"
sed -i "s|STUDENT_SECRET_NAME_PLACEHOLDER|${SECRET_NAME}|g"   "${KUST}"
# Replace placeholder in base backend.yaml
sed -i "s|STUDENT_SECRET_PLACEHOLDER|${SECRET_NAME}|g"        "${BASE_BACKEND}"

echo "Applying manifests to namespace ${NAMESPACE}..."
oc apply -k "${TMPDIR}/student/" -n "${NAMESPACE}"

echo ""
echo "Waiting for PostgreSQL..."
oc rollout status deployment/postgresql -n "${NAMESPACE}" --timeout=180s

echo "Waiting for backend..."
oc rollout status deployment/backend -n "${NAMESPACE}" --timeout=300s

echo "Waiting for frontend..."
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
