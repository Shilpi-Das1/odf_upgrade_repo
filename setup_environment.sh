#!/bin/bash
################################################################################
# ODF Environment Setup Script
#
# Description:
#   Sets up the ocs-upi-kvm testing environment for ODF versions 4.14-4.21.
#   Clones repository, initializes submodules, and copies required configuration.
#
# Usage:
#   bash setup_environment.sh <ODF_VERSION>
#
# Arguments:
#   ODF_VERSION    - ODF version to set up (e.g., 4.18, 4.19, 4.20)
#
# Prerequisites:
#   - Git installed and configured
#   - Internet connectivity for cloning repositories
#   - Required files at configured paths:
#     * ${PULL_SECRET_PATH} - OpenShift pull secret
#     * ${AUTH_YAML_PATH} - Authentication YAML
#     * ${OPENSTACK_AUTH_DIR} - OpenStack auth directory
#     * /usr/local/bin/oc - OpenShift CLI binary
#
# Outputs:
#   - Cloned repository: ${OCS_UPI_DIR}
#   - Backup of existing: ${BASE_DIR}/aocs-upi-kvm/
#   - Setup log: ${OCS_UPI_DIR}/scripts/setup-ocs-ci.log
#
# Security:
#   - Pull secrets copied from ${PULL_SECRET_PATH} (not hardcoded)
#   - Auth files handled via variables
#   - No secrets logged or exposed
#   - Only file paths printed, not contents
#
# Author: ODF Automation Team
# Version: 2.0 (Multi-environment support)
################################################################################

set -e  # Exit on error

# Source common variables for multi-environment support
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common_vars.sh"

ODF_VERSION=$1

if [ -z "$ODF_VERSION" ]; then
    echo "Error: ODF_VERSION not provided"
    echo "Usage: $0 <ODF_VERSION>"
    exit 1
fi

echo "=========================================="
echo "Setting up environment for ODF $ODF_VERSION"
echo "=========================================="

# Navigate to base directory
cd ${BASE_DIR}

# Backup existing ocs-upi-kvm directory if it exists
if [ -d "ocs-upi-kvm" ]; then
    echo "Backing up existing ocs-upi-kvm to aocs-upi-kvm..."
    mv ocs-upi-kvm/ aocs-upi-kvm/
fi

# Clone the repository
echo "Cloning ocs-upi-kvm repository..."
git clone https://github.com/shilpi-das1/ocs-upi-kvm

cd ocs-upi-kvm/
git checkout 4.22-changes
# Extract major.minor version (e.g., 4.14, 4.18, 4.19, 4.20, 4.21)
VERSION_NUM=$(echo "$ODF_VERSION" | grep -oE '[0-9]+\.[0-9]+')

echo "ODF version $ODF_VERSION detected"
echo "Using latest code for all ODF versions (no branch checkout)"

# Initialize and update submodules
echo "Initializing and updating submodules..."
git submodule update --init

# Copy required files
echo "Copying required files..."

# Copy oc binary
if [ -f "/usr/local/bin/oc" ]; then
    mkdir -p ${BIN_DIR}
    cp /usr/local/bin/oc ${BIN_DIR}
    echo "Copied oc binary to ${BIN_DIR}"
else
    echo "Warning: /usr/local/bin/oc not found"
fi

# Copy auth directory
if [ -d "${OPENSTACK_AUTH_DIR}" ]; then
    cp -r ${OPENSTACK_AUTH_DIR} ${AUTH_DIR_PATH}
    echo "Copied auth directory"
else
    echo "Warning: ${OPENSTACK_AUTH_DIR} not found"
fi

mkdir -p ${OCS_CI_DATA_DIR}
echo "Created ${OCS_CI_DATA_DIR} directory"

# Navigate back to base directory
cd ${BASE_DIR}

# Copy auth.yaml
if [ -f "${AUTH_YAML_PATH}" ]; then
    cp ${AUTH_YAML_PATH} ${OCS_CI_DATA_DIR}/
    echo "Copied auth.yaml"
else
    echo "Warning: ${AUTH_YAML_PATH} not found"
fi

# Copy pull-secret
if [ -f "${PULL_SECRET_PATH}" ]; then
    cp ${PULL_SECRET_PATH} ${OCS_UPI_DIR}/src/ocs-ci
    cp ${PULL_SECRET_PATH} ${PULL_SECRET_TXT}
    echo "Copied pull-secret files"
else
    echo "Warning: ${PULL_SECRET_PATH} not found"
fi

echo ""
echo "=========================================="
echo "Environment setup completed successfully!"
echo "=========================================="
echo "You can now run the rerun_test.sh script"

echo "Rerun setup script"
cd ${OCS_UPI_DIR}/scripts
bash setup-ocs-ci.sh 2>&1 | tee -a setup-ocs-ci.log
