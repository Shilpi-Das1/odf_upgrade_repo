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
    git -C ${OCS_UPI_DIR}/src/ocs-ci apply \
    ${REPO_DIR}/patches/bucket-policy-normalize-414.patch
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

# Removing Debug pods
oc delete pod $(oc get pods | grep debug | grep Completed | awk '{print $1}')

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
    # Removing Debug pods
    oc delete pod $(oc get pods | grep debug | grep Completed | awk '{print $1}')
    bash ${REPO_DIR}/odf-build-info.sh | tee -a ${LOG_DIR}/odf-build-info-after-tier4a.log
    bash ${REPO_DIR}/check-crc.sh | tee -a ${LOG_DIR}/crc_log_after_tier4a.log
    
    echo ""
    echo "=========================================="
    echo "Checking cluster health after Tier 4a Waiting for 5 mins to stabalize cluster..."
    echo "=========================================="
    sleep 300
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
fi



echo ""
echo "=========================================="
echo "Generating Test Summary..."
echo "=========================================="

# Extract ODF build version from odf-after-upgrade.log
ODF_BUILD_VERSION=""
if [ -f "${LOG_DIR}/odf-after-upgrade.log" ]; then
    # Look for the pattern: #######  ODF build  #######
    # followed by the version number on the next line
    ODF_BUILD_VERSION=$(sed -n '/^#######  ODF build  #######$/{ n; p; }' "${LOG_DIR}/odf-after-upgrade.log" | head -1 | tr -d '[:space:]')
    if [ -n "${ODF_BUILD_VERSION}" ]; then
        echo "Extracted ODF Build Version: ${ODF_BUILD_VERSION}"
    else
        echo "Warning: Could not extract ODF build version from odf-after-upgrade.log"
    fi
else
    echo "Warning: odf-after-upgrade.log not found, cannot extract build version"
fi
echo ""
echo "=========================================="
echo "Collecting must-gather..."
echo "=========================================="
oc adm must-gather --image=${MUST_GATHER_IMAGE} --dest-dir=${LOG_DIR}/must-gather-${ODF_BUILD_VERSION}
tar -cvzf ${BASE_DIR}/must-gather-${ODF_BUILD_VERSION}.tar.gz ${LOG_DIR}/must-gather-${ODF_BUILD_VERSION}
rm -rf ${LOG_DIR}/must-gather-${ODF_BUILD_VERSION}

SUMMARY_FILE="${BASE_DIR}/test-summary-${ODF_BUILD_VERSION}.txt"
# Initialize summary file
echo "========================================" > ${SUMMARY_FILE}
echo "ODF Test Execution Summary" >> ${SUMMARY_FILE}
echo "Generated: $(date)" >> ${SUMMARY_FILE}
if [ -n "${ODF_BUILD_VERSION}" ]; then
    echo "ODF Build: ${ODF_BUILD_VERSION}" >> ${SUMMARY_FILE}
fi
echo "========================================" >> ${SUMMARY_FILE}
echo "" >> ${SUMMARY_FILE}

# Add ODF before upgrade log
if [ -f "${LOG_DIR}/odf-before-upgrade.log" ]; then
    echo "========================================" >> ${SUMMARY_FILE}
    if [ -n "${ODF_BUILD_VERSION}" ]; then
        echo "ODF Build: ${ODF_BUILD_VERSION} - Status Before Upgrade" >> ${SUMMARY_FILE}
    else
        echo "ODF Status Before Upgrade" >> ${SUMMARY_FILE}
    fi
    echo "========================================" >> ${SUMMARY_FILE}
    cat "${LOG_DIR}/odf-before-upgrade.log" >> ${SUMMARY_FILE}
    echo "" >> ${SUMMARY_FILE}
else
    echo "ODF before upgrade log not found: ${LOG_DIR}/odf-before-upgrade.log" >> ${SUMMARY_FILE}
    echo "" >> ${SUMMARY_FILE}
fi

# Add ODF after upgrade log
if [ -f "${LOG_DIR}/odf-after-upgrade.log" ]; then
    echo "========================================" >> ${SUMMARY_FILE}
    if [ -n "${ODF_BUILD_VERSION}" ]; then
        echo "ODF Build: ${ODF_BUILD_VERSION} - Status After Upgrade" >> ${SUMMARY_FILE}
    else
        echo "ODF Status After Upgrade" >> ${SUMMARY_FILE}
    fi
    echo "========================================" >> ${SUMMARY_FILE}
    cat "${LOG_DIR}/odf-after-upgrade.log" >> ${SUMMARY_FILE}
    echo "" >> ${SUMMARY_FILE}
else
    echo "ODF after upgrade log not found: ${LOG_DIR}/odf-after-upgrade.log" >> ${SUMMARY_FILE}
    echo "" >> ${SUMMARY_FILE}
fi

# Function to extract test summary
extract_summary() {
    local tier=$1
    local log_file=$2
    local build_info_file=$3
    local crc_log_file=$4
    
    echo "========================================" >> ${SUMMARY_FILE}
    if [ -n "${ODF_BUILD_VERSION}" ]; then
        echo "ODF Build: ${ODF_BUILD_VERSION} - Tier ${tier} Summary" >> ${SUMMARY_FILE}
    else
        echo "Tier ${tier} Summary" >> ${SUMMARY_FILE}
    fi
    echo "========================================" >> ${SUMMARY_FILE}
    echo "" >> ${SUMMARY_FILE}
    
    if [ -f "${log_file}" ]; then
        echo "Extracting summary from ${log_file}..." >> ${SUMMARY_FILE}
        echo "" >> ${SUMMARY_FILE}
        
        # Extract short test summary info section
        if grep -q "short test summary info" "${log_file}"; then
            echo "--- Test Results ---" >> ${SUMMARY_FILE}
            sed -n '/=* short test summary info =*/,/=.*=.*in.*=/p' "${log_file}" >> ${SUMMARY_FILE}
            echo "" >> ${SUMMARY_FILE}
        else
            echo "No test summary found in log file." >> ${SUMMARY_FILE}
            echo "" >> ${SUMMARY_FILE}
        fi
    else
        echo "Log file not found: ${log_file}" >> ${SUMMARY_FILE}
        echo "" >> ${SUMMARY_FILE}
    fi
    
    # Print ODF build info
    if [ -f "${build_info_file}" ]; then
        echo "========================================" >> ${SUMMARY_FILE}
        if [ -n "${ODF_BUILD_VERSION}" ]; then
            echo "ODF Build: ${ODF_BUILD_VERSION} - Build Info (After Tier ${tier})" >> ${SUMMARY_FILE}
        else
            echo "ODF Build Info (After Tier ${tier})" >> ${SUMMARY_FILE}
        fi
        echo "========================================" >> ${SUMMARY_FILE}
        cat "${build_info_file}" >> ${SUMMARY_FILE}
        echo "" >> ${SUMMARY_FILE}
    else
        echo "Build info file not found: ${build_info_file}" >> ${SUMMARY_FILE}
        echo "" >> ${SUMMARY_FILE}
    fi
    
    # Print CRC log
    if [ -f "${crc_log_file}" ]; then
        echo "========================================" >> ${SUMMARY_FILE}
        if [ -n "${ODF_BUILD_VERSION}" ]; then
            echo "ODF Build: ${ODF_BUILD_VERSION} - CRC Log (After Tier ${tier})" >> ${SUMMARY_FILE}
        else
            echo "CRC Log (After Tier ${tier})" >> ${SUMMARY_FILE}
        fi
        echo "========================================" >> ${SUMMARY_FILE}
        cat "${crc_log_file}" >> ${SUMMARY_FILE}
        echo "" >> ${SUMMARY_FILE}
    else
        echo "CRC log file not found: ${crc_log_file}" >> ${SUMMARY_FILE}
        echo "" >> ${SUMMARY_FILE}
    fi
}

# Extract Tier 1 summary
extract_summary "1" \
    "${LOG_DIR}/tier1_${UPGRADE_OCS_CHANNEL}.log" \
    "${LOG_DIR}/odf-build-info-after-tier1.log" \
    "${LOG_DIR}/crc_log_after_tier1.log"

# Extract Tier 4a summary
extract_summary "4a" \
    "${LOG_DIR}/tier4a_${UPGRADE_OCS_CHANNEL}.log" \
    "${LOG_DIR}/odf-build-info-after-tier4a.log" \
    "${LOG_DIR}/crc_log_after_tier4a.log"

# Add execution summary (rerun summary)
EXECUTION_SUMMARY="${LOG_DIR}/rerun-logs/execution_summary.txt"
if [ -f "${EXECUTION_SUMMARY}" ]; then
    echo "========================================" >> ${SUMMARY_FILE}
    if [ -n "${ODF_BUILD_VERSION}" ]; then
        echo "ODF Build: ${ODF_BUILD_VERSION} - Execution Summary (Rerun Summary)" >> ${SUMMARY_FILE}
    else
        echo "Execution Summary (Rerun Summary)" >> ${SUMMARY_FILE}
    fi
    echo "========================================" >> ${SUMMARY_FILE}
    cat "${EXECUTION_SUMMARY}" >> ${SUMMARY_FILE}
    echo "" >> ${SUMMARY_FILE}
else
    echo "Execution summary file not found: ${EXECUTION_SUMMARY}" >> ${SUMMARY_FILE}
    echo "" >> ${SUMMARY_FILE}
fi

echo "========================================" >> ${SUMMARY_FILE}
echo "End of Summary" >> ${SUMMARY_FILE}
echo "========================================" >> ${SUMMARY_FILE}

echo ""
echo "Creating tar.gz archive of odf_tier_logs..."
cd ${BASE_DIR}
tar -czf odf_tier_logs-${ODF_BUILD_VERSION}.tar.gz "${LOG_DIR}"
echo "Archive created: ${BASE_DIR}/odf_tier_logs-${ODF_BUILD_VERSION}.tar.gz"

# Display summary to console
echo ""
echo "=========================================="
echo "Test Summary Generated"
echo "=========================================="
cat ${SUMMARY_FILE}
echo "=========================================="

echo ""
echo "=========================================="
echo "All tasks completed successfully!"
echo "=========================================="
echo "Summary file: ${SUMMARY_FILE}"
echo "Logs archive: ${BASE_DIR}/odf_tier_logs-${ODF_BUILD_VERSION}.tar.gz"
echo "Must-gather: ${BASE_DIR}/must-gather-${ODF_BUILD_VERSION}.tar.gz"
echo "=========================================="
