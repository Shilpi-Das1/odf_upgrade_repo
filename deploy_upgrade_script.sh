#!/bin/bash
################################################################################
# ODF Deployment and Upgrade Script
#
# Description:
#   Deploys OpenShift Data Foundation (ODF) and performs upgrade operations.
#   Handles operator installation, storage cluster creation, and version upgrades.
#
# Usage:
#   bash deploy_upgrade_script.sh
#
# Prerequisites:
#   - var.ini file with OCS version configuration
#   - OpenShift cluster access (oc command configured)
#   - Pull secret at ${PULL_SECRET_PATH}
#   - local.sh script for storage configuration
#
# Environment Variables:
#   CURRENT_OCS_CHANNEL    - Current OCS channel version
#   UPGRADE_OCS_IMAGE      - OCS upgrade image URL
#   UPGRADE_OCS_CHANNEL    - Target OCS channel for upgrade
#   MUST_GATHER_IMAGE      - Must-gather image for diagnostics
#
# Outputs:
#   - Logs: ${LOG_DIR}/odf-before-upgrade.log
#   - Logs: ${LOG_DIR}/odf-after-upgrade.log
#
# Security:
#   - Uses ${PULL_SECRET_PATH} (not hardcoded)
#   - No secrets logged or exposed
#   - ICSP YAML stored at ${ICSP_YAML}
#
# Author: ODF Automation Team
# Version: 2.0 (Multi-environment support)
################################################################################

set -euo pipefail

# Source common variables for multi-environment support
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common_vars.sh"
mkdir -p ${LOG_DIR}

# Color codes
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
NC="\033[0m" # No Color

log() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
  echo -e "${YELLOW}[WAIT]${NC} $1"
}

error_exit() {
  echo -e "${RED}[ERROR]${NC} $1" && exit 1
}

# Check and load variables if missing
if [ -z "${CURRENT_OCS_CHANNEL:-}" ] || \
   [ -z "${UPGRADE_OCS_IMAGE:-}" ] || \
   [ -z "${UPGRADE_OCS_CHANNEL:-}" ]; then
    echo "Loading OCS vars from var.ini..."
    source var.ini
fi
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Namespace
metadata:
  labels:
    openshift.io/cluster-monitoring: "true"
  name: openshift-storage
spec: {}
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: openshift-storage-operatorgroup
  namespace: openshift-storage
spec:
  creationTimestamp: null
  targetNamespaces:
        - openshift-storage
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: odf-operator
  namespace: openshift-storage
spec:
  channel: stable-${CURRENT_OCS_CHANNEL}
  installPlanApproval: Automatic
  name: odf-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

log "Waiting for odf Operator to be ready..."
for i in {1..30}; do
  CSV=$(oc -n openshift-storage get subscription odf-operator -o jsonpath='{.status.installedCSV}' 2>/dev/null || true)
  PHASE=$(oc -n openshift-storage get csv "$CSV" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Pending")
  [[ "$PHASE" == "Succeeded" ]] && log "openshift-storage." && break
  warn "ODF CSV status: $PHASE, retrying in 30s..."
  sleep 30
done

cat <<EOF | oc apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: openshift-local-storage
EOF

oc annotate namespace openshift-local-storage openshift.io/node-selector=''
oc annotate namespace openshift-local-storage workload.openshift.io/allowed='management'

cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: local-storage
  namespace: openshift-local-storage
spec:
  targetNamespaces:
    - openshift-local-storage
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: local-storage-operator
  namespace: openshift-local-storage
spec:
  channel: stable
  installPlanApproval: Automatic
  name: local-storage-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

# Wait for Local Storage Operator to be ready ---
log "Waiting for Local Storage Operator to be ready..."
for i in {1..30}; do
  CSV=$(oc -n openshift-local-storage get subscription local-storage-operator -o jsonpath='{.status.installedCSV}' 2>/dev/null || true)
  PHASE=$(oc -n openshift-local-storage get csv "$CSV" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Pending")
  [[ "$PHASE" == "Succeeded" ]] && log "Local Storage Operator is installed." && break
  warn "Local Storage CSV status: $PHASE, retrying in 30s..."
  sleep 30
done

# Check if Local Storage Operator installation succeeded
CSV=$(oc -n openshift-local-storage get subscription local-storage-operator -o jsonpath='{.status.installedCSV}' 2>/dev/null || true)
PHASE=$(oc -n openshift-local-storage get csv "$CSV" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Pending")
if [[ "$PHASE" != "Succeeded" ]]; then
  error_exit "Local Storage Operator failed to install. Final status: $PHASE"
fi

bash local.sh

log "Waiting for pv to be Ready..."
for i in {1..30}; do
  PHASE=$(oc get pv -n openshift-storage -o jsonpath='{.items[*].status.phase}' 2>/dev/null || echo "NotFound")
  if [[ "$PHASE" == "Available Available Available" ]]; then
    log "pv is Available."
    break
  fi
  warn "PV status: $PHASE, retrying in 30s..."
  sleep 30
done

# Check if PVs are available
PHASE=$(oc get pv -n openshift-storage -o jsonpath='{.items[*].status.phase}' 2>/dev/null || echo "NotFound")
if [[ "$PHASE" != "Available Available Available" ]]; then
  error_exit "PVs failed to become Available. Final status: $PHASE"
fi
# Enable console plugin 

oc patch console.v1.operator.openshift.io/cluster  -n None -p '[{"op": "add", "path": "/spec/plugins", "value": [odf-console]}]' --type json

sleep 60

#label all nodes  ---
oc label node worker-0 cluster.ocs.openshift.io/openshift-storage=''
oc label node worker-1 cluster.ocs.openshift.io/openshift-storage=''
oc label node worker-2 cluster.ocs.openshift.io/openshift-storage=''

# --- Step 11: create storage-system 

if [[ "$CURRENT_OCS_CHANNEL" == *"4.19"* || "$CURRENT_OCS_CHANNEL" == *"4.20"* || "$CURRENT_OCS_CHANNEL" == *"4.21"* ]]; then
  echo "Skipping StorageSystem creation for OCS channel: $CURRENT_OCS_CHANNEL"
else
  cat <<EOF | oc apply -f -
apiVersion: odf.openshift.io/v1alpha1
kind: StorageSystem
metadata:
  name: ocs-storagecluster-storagesystem
  namespace: openshift-storage
spec:
  kind: storagecluster.ocs.openshift.io/v1
  name: ocs-storagecluster
  namespace: openshift-storage
EOF
fi
# --- Step 11: create storage-cluster  ---
cat <<EOF | oc apply -f - 
apiVersion: ocs.openshift.io/v1
kind: StorageCluster
metadata:
  name: ocs-storagecluster
  namespace: openshift-storage
  annotations:
    cluster.ocs.openshift.io/local-devices: "true"
spec:
  manageNodes: false
  monDataDirHostPath: /var/lib/rook
  enableCephTools: true
  flexibleScaling: true
  resourceProfile: balanced
  managedResources:
    cephBlockPools:
      defaultStorageClass: true
    cephFileSystems:
      defaultStorageClass: false
  storageDeviceSets:
    - name: ocs-deviceset-localblock
      count: 3
      replica: 1
      portable: false
      dataPVCTemplate:
        spec:
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 100Gi
          storageClassName: localblock
          volumeMode: Block
EOF

sleep 300

log "Waiting for StorageCluster to be Ready..."
for i in {1..30}; do
  PHASE=$(oc get storagecluster ocs-storagecluster -n openshift-storage -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
  if [[ "$PHASE" == "Ready" ]]; then
    log "StorageCluster is Ready."
    break
  fi
  warn "StorageCluster status: $PHASE, retrying in 30s..."
  sleep 30
done


bash odf-build-info.sh | tee -a ${LOG_DIR}/odf-before-upgrade.log

oc patch operatorhub.config.openshift.io/cluster \
  --type=merge -p='{"spec":{"sources":[{"disabled":true,"name":"redhat-operators"}]}}'

cat <<EOF | oc apply -f - 
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  labels:
    ocs-operator-internal: 'true'
  name: redhat-operators
  namespace: openshift-marketplace
spec:
  displayName: Openshift Data Foundation
  icon:
    base64data: ""
    mediatype: image/svg+xml
  image: $UPGRADE_OCS_IMAGE
  priority: 100
  publisher: Red Hat
  sourceType: grpc
  updateStrategy:
    registryPoll:
      interval: 15m
EOF

# --- Step 4: Mirror registries with ICSP ---
log "Creating ImageContentSourcePolicy..."

cat <<EOF | oc apply -f - 
apiVersion: operator.openshift.io/v1alpha1
kind: ImageContentSourcePolicy
metadata:
  name: brew-registry
spec:
  repositoryDigestMirrors:
  - mirrors: [brew.registry.redhat.io]
    source: registry.redhat.io
  - mirrors: [brew.registry.redhat.io]
    source: registry.stage.redhat.io
  - mirrors: [brew.registry.redhat.io]
    source: registry.connect.redhat.com
EOF

oc image extract --filter-by-os linux/ppc64le --registry-config ${PULL_SECRET_PATH} $UPGRADE_OCS_IMAGE --confirm --path /icsp.yaml:${BASE_DIR}
oc create -f ${ICSP_YAML}

# --- Wait for CatalogSource readiness ---
wait_for_catalogsource_ready() {
  local name=$1
  log "Waiting for CatalogSource '$name' to be ready..."
  for i in {1..30}; do
    POD=$(oc -n openshift-marketplace get pods -l "olm.catalogSource=$name" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
    STATUS=$(oc -n openshift-marketplace get pod "$POD" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Pending")
    [[ "$STATUS" == "Running" ]] && log "CatalogSource '$name' is ready." && return
    warn "$name status: $STATUS, retrying in 20s..."
    sleep 20
  done
  error_exit "Timeout waiting for CatalogSource '$name'."
}

oc patch subscription odf-operator \
  -n openshift-storage \
  --type=merge \
  -p "{\"spec\": {\"channel\": \"stable-${UPGRADE_OCS_CHANNEL}\"}}"

sleep 900

log "Waiting for StorageCluster to be Ready..."
for i in {1..30}; do
  PHASE=$(oc get storagecluster ocs-storagecluster -n openshift-storage -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
  if [[ "$PHASE" == "Ready" ]]; then
    log "StorageCluster is Ready."
    break
  fi
  warn "StorageCluster status: $PHASE, retrying in 30s..."
  sleep 30
done

# Verify upgrade version matches expected channel
log "Verifying ODF upgrade version..."
odf_csv=$(oc get csv -n openshift-storage -o name | grep odf-operator)
if [ -z "$odf_csv" ]; then
  error_exit "ODF CSV not found in openshift-storage namespace"
fi

current_full_version=$(oc get "$odf_csv" -n openshift-storage -o jsonpath='{.metadata.labels.full_version}')
if [ -z "$current_full_version" ]; then
  error_exit "Unable to retrieve ODF version from CSV"
fi

# Extract major.minor version (e.g., 4.22 from 4.22.0-90)
current_version=$(echo "$current_full_version" | cut -d'.' -f1,2)

log "Current ODF version: $current_full_version (Channel: $current_version)"
log "Expected upgrade channel: $UPGRADE_OCS_CHANNEL"

if [[ "$current_version" != "$UPGRADE_OCS_CHANNEL" ]]; then
  error_exit "Upgrade was unsuccessful. Expected version: $UPGRADE_OCS_CHANNEL, Current version: $current_version"
fi

log "Version verification successful: ODF upgraded to channel $current_version"

bash odf-build-info.sh | tee -a ${LOG_DIR}/odf-after-upgrade.log

bash buffer_io_disabled.sh

