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
set -e

NAMESPACE="${1}"
INFERENCE_URL="${2}"

if [[ -z "${NAMESPACE}" || -z "${INFERENCE_URL}" ]]; then
  echo "Usage: $0 <namespace> <inference_url>"
  exit 1
fi

echo "Deploying Image Recognition App"
echo "  Namespace     : ${NAMESPACE}"
echo "  Inference URL : ${INFERENCE_URL}"
echo ""

# Create a temp overlay with the real values substituted
TMPDIR=$(mktemp -d)
cp -r "$(dirname $0)/overlays/student" "${TMPDIR}/"

sed -i.bak \
  -e "s|STUDENT_NAMESPACE_PLACEHOLDER|${NAMESPACE}|g" \
  -e "s|INFERENCE_URL_PLACEHOLDER|${INFERENCE_URL}|g" \
  "${TMPDIR}/student/kustomization.yaml"

# Apply
oc apply -k "${TMPDIR}/student/"

echo ""
echo "Waiting for deployments to become available..."
oc rollout status deployment/postgresql -n "${NAMESPACE}" --timeout=120s
oc rollout status deployment/backend    -n "${NAMESPACE}" --timeout=180s
oc rollout status deployment/frontend   -n "${NAMESPACE}" --timeout=60s

echo ""
ROUTE=$(oc get route image-rec-app -n "${NAMESPACE}" \
  -o jsonpath='https://{.spec.host}')
BACKEND_ROUTE=$(oc get route backend -n "${NAMESPACE}" \
  -o jsonpath='https://{.spec.host}')

echo "════════════════════════════════════════════"
echo " Deployment complete!"
echo "════════════════════════════════════════════"
echo " App URL    : ${ROUTE}"
echo " Backend URL: ${BACKEND_ROUTE}"
echo " Health     : ${BACKEND_ROUTE}/health"
echo "════════════════════════════════════════════"

# Clean up temp dir
rm -rf "${TMPDIR}"
