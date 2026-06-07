#!/bin/bash
################################################################################
# ODF Tier 1 and Tier 4a Test Execution Script
#
# Description:
#   Executes ODF Tier 1 and Tier 4a test suites after ODF deployment.
#   Clones ocs-upi-kvm repository, sets up environment, and runs tests.
#
# Usage:
#   bash run_tier1_tier4a.sh
#
# Prerequisites:
#   - var.ini file with configuration
#   - OpenShift cluster with ODF deployed
#   - Required files: pull-secret, auth.yaml, openstack-upi/auth/
#   - Python virtual environment at ~/venv/
#
# Environment Variables (from var.ini):
#   UPGRADE_OCS_CHANNEL    - OCS version to test
#   UPGRADE_OCS_IMAGE      - OCS registry image
#   OCP_VERSION            - OpenShift version
#   MUST_GATHER_IMAGE      - Must-gather image for diagnostics
#   AUTH_YAML              - Authentication YAML content
#
# Outputs:
#   - Tier 1 logs: ${LOG_DIR}/tier1_${OCS_VERSION}.log
#   - Tier 4a logs: ${LOG_DIR}/tier4a_${OCS_VERSION}.log
#   - Build info: ${LOG_DIR}/odf-build-info-after-tier*.log
#   - CRC logs: ${LOG_DIR}/crc_log_after_tier*.log
#   - Must-gather: ${LOG_DIR}/must-gather-${OCS_VERSION}.tar.gz
#
# Security:
#   - Pull secrets copied from ${PULL_SECRET_PATH} (not hardcoded)
#   - Auth files handled via variables
#   - No secrets logged or exposed
#
# Author: ODF Automation Team
# Version: 2.0 (Multi-environment support)
################################################################################

# Source common variables for multi-environment support
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common_vars.sh"

# Load variables from var.ini
if [ -f var.ini ]; then
    # shellcheck disable=SC1091
    source var.ini
else
    echo "ERROR: var.ini not found."
    exit 1
fi
mkdir -p ${LOG_DIR}
# Export for child processes
export PLATFORM="${PLATFORM:-powervm}"
export OCP_VERSION
export OCS_VERSION="${UPGRADE_OCS_CHANNEL}"  # Use upgrade channel as OCS_VERSION
export VAULT_SUPPORT="${VAULT_SUPPORT:-false}"
export FIPS_ENABLEMENT="${FIPS_ENABLEMENT:-false}"
export OCS_REGISTRY_IMAGE="${UPGRADE_OCS_IMAGE}"

cd ${BASE_DIR}
git clone https://github.com/shilpi-das1/ocs-upi-kvm
cd ocs-upi-kvm
git checkout "v${OCP_VERSION}.0"
git submodule update --init

mkdir -p ${BIN_DIR}
cp /usr/local/bin/oc ${BIN_DIR}/oc
cp -r ${OPENSTACK_AUTH_DIR} ${AUTH_DIR_PATH}
mkdir -p ${OCS_CI_DATA_DIR}
cp ${PULL_SECRET_PATH} ./src/ocs-ci
cp ${PULL_SECRET_PATH} ${PULL_SECRET_TXT}
cp ${PULL_SECRET_TXT} ${OCS_CI_DATA_DIR}/pull-secret

# Write auth.yaml from AUTH_YAML string
echo "$AUTH_YAML" > ${AUTH_YAML_PATH}
cp ${AUTH_YAML_PATH} ${OCS_CI_DATA_DIR}/

if [ "$UPGRADE_OCS_CHANNEL" == "4.14" ]; then
    cp ${REPO_DIR}/patches/bucket-policy-normalize-414.patch \
       ${OCS_UPI_DIR}/files/ocs-ci/
fi

# Create ocs-ci-conf.yaml using upgrade OCS values
cat > ${OCS_CI_CONF} << EOF
ENV_DATA:
  local_storage_allow_rotational_disks: true
  ocs_version: '${UPGRADE_OCS_CHANNEL}'
  number_of_storage_disks: 8

UPGRADE:
  ocp_arch: ppc64le

RUN:
  log_dir: ${OCS_CI_LOG_DIR}/${UPGRADE_OCS_CHANNEL}

DEPLOYMENT:
  ocs_registry_image: ${UPGRADE_OCS_IMAGE}
  skip_download_client: true
  optional_operators_image: quay.io/openshift-release-dev/ocp-release-nightly:iib-int-index-art-operators-${OCP_VERSION}
  ocs_csv_channel: stable-${UPGRADE_OCS_CHANNEL}

REPORTING:
  ocp_must_gather_image: ${MUST_GATHER_IMAGE}
EOF

cd scripts
bash setup-ocs-ci.sh 2>&1 | tee -a setup-ocs-ci.log

LOG_FILE="${LOG_DIR}/tier1_${OCS_VERSION}.log"
LOG_FILE_ERR="${LOG_DIR}/tier1_${OCS_VERSION}.err"
nohup ./test-ocs-ci.sh --tier 1 > >(tee -a "$LOG_FILE") 2> >(tee -a "$LOG_FILE_ERR" >&2) &
TIER1_PID=$!
echo "Tier 1 tests started with PID: $TIER1_PID"
wait $TIER1_PID
TIER1_EXIT_CODE=$?
echo "Tier 1 tests completed with exit code: $TIER1_EXIT_CODE"

echo "Sleeping 10 mins "
sleep 600


bash ${REPO_DIR}/odf-build-info.sh | tee -a ${LOG_DIR}/odf-build-info-after-tier1.log
bash ${REPO_DIR}/check-crc.sh | tee -a ${LOG_DIR}/crc_log_after_tier1.log


# Get StorageCluster phase
storageClusterPhase=$(oc get storagecluster ocs-storagecluster -n openshift-storage -o jsonpath='{.status.phase}')

# Get Ceph health status
health=$(oc get cephcluster -n openshift-storage -o jsonpath='{.items[0].status.ceph.health}')
echo "  StorageCluster Phase: $storageClusterPhase"
echo "  CephCluster Health: $health"

if [[ "$storageClusterPhase" == "Ready" && "$health" == "HEALTH_OK" ]]; then
    echo "StorageCluster is Ready and Ceph cluster is healthy. Running tier4a..."
    LOG_FILE_4a="${LOG_DIR}/tier4a_${OCS_VERSION}.log"
    LOG_FILE_4a_ERR="${LOG_DIR}/tier4a_${OCS_VERSION}.err"
    nohup ./test-ocs-ci.sh --tier 4a > >(tee -a "$LOG_FILE_4a") 2> >(tee -a "$LOG_FILE_4a_ERR" >&2) &
    TIER4A_PID=$!
    echo "Tier 4a tests started with PID: $TIER4A_PID"
    wait $TIER4A_PID
    TIER4A_EXIT_CODE=$?
    echo "Tier 4a tests completed with exit code: $TIER4A_EXIT_CODE"
    bash ${REPO_DIR}/odf-build-info.sh | tee -a ${LOG_DIR}/odf-build-info-after-tier4a.log
    bash ${REPO_DIR}/check-crc.sh | tee -a ${LOG_DIR}/crc_log_after_tier4a.log
    
    echo ""
    echo "=========================================="
    echo "Checking cluster health after Tier 4a..."
    echo "=========================================="
    
    # Re-check StorageCluster phase after tier 4a
    storageClusterPhaseAfter=$(oc get storagecluster ocs-storagecluster -n openshift-storage -o jsonpath='{.status.phase}')
    healthAfter=$(oc get cephcluster -n openshift-storage -o jsonpath='{.items[0].status.ceph.health}')
    
    echo "  StorageCluster Phase: $storageClusterPhaseAfter"
    echo "  CephCluster Health: $healthAfter"
    
    if [[ "$storageClusterPhaseAfter" == "Ready" && "$healthAfter" == "HEALTH_OK" ]]; then
        echo ""
        echo "=========================================="
        echo "Cluster is healthy. Running rerun tests..."
        echo "=========================================="
        
        cd ${REPO_DIR}
        bash rerun_test.sh 2>&1 | tee -a ${LOG_DIR}/rerun_test_${OCS_VERSION}.log
        RERUN_EXIT_CODE=$?
        echo "Rerun tests completed with exit code: $RERUN_EXIT_CODE"
    else
        echo ""
        echo "WARNING: Cluster not healthy after Tier 4a tests"
        echo "  StorageCluster Phase: $storageClusterPhaseAfter"
        echo "  CephCluster Health: $healthAfter"
        echo "Skipping rerun tests due to unhealthy cluster state"
    fi
    
    echo ""
    echo "=========================================="
    echo "Collecting must-gather..."
    echo "=========================================="
    oc adm must-gather --image=${MUST_GATHER_IMAGE} --dest-dir=${LOG_DIR}/must-gather-${OCS_VERSION}
    tar -cvzf ${LOG_DIR}/must-gather-${OCS_VERSION}.tar.gz ${LOG_DIR}/must-gather-${OCS_VERSION}
    if [[ "$storageClusterPhase" == "Ready" && "$health" == "HEALTH_OK" ]]; then
        echo "StorageCluster is Ready and Ceph cluster is healthy. After tier4a Rerun tests"
        bash rerun_test.sh
    fi
else
    echo "Cluster not in a healthy state:"
    echo "  StorageCluster Phase: $storageClusterPhase"
    echo "  CephCluster Health: $health"
    oc adm must-gather --image=${MUST_GATHER_IMAGE} --dest-dir=${LOG_DIR}/must-gather-${OCS_VERSION}
    tar -cvzf ${LOG_DIR}/must-gather-${OCS_VERSION}.tar.gz ${LOG_DIR}/must-gather-${OCS_VERSION}
    exit 1
fi



