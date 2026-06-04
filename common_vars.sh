#!/bin/bash
################################################################################
# Common Variables for ODF Upgrade Scripts
# 
# This file provides centralized configuration for all ODF upgrade scripts.
# It automatically detects the environment (Jenkins vs Bastion) and sets
# appropriate paths.
#
# Usage in scripts:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "${SCRIPT_DIR}/common_vars.sh"
#
# Environment Detection:
#   - Jenkins: Uses $WORKSPACE (e.g., /var/lib/jenkins/workspace/job-name)
#   - Bastion: Falls back to /root
#   - Custom: Override any variable via environment before sourcing
#
################################################################################

# Base directory - automatically detects Jenkins ($WORKSPACE) or bastion (/root)
export BASE_DIR="${WORKSPACE:-/root}"

# Repository directory (where these scripts are located)
# On Jenkins: $WORKSPACE/odf_upgrade_repo
# On Bastion: /root/odf_upgrade_repo
export REPO_DIR="${REPO_DIR:-${BASE_DIR}/odf_upgrade_repo}"

# Working directories (relative to BASE_DIR)
export OCS_UPI_DIR="${OCS_UPI_DIR:-${BASE_DIR}/ocs-upi-kvm}"
export LOG_DIR="${LOG_DIR:-${BASE_DIR}/odf_tier_logs}"
export BIN_DIR="${BIN_DIR:-${BASE_DIR}/bin}"
export AUTH_DIR_PATH="${AUTH_DIR_PATH:-${BASE_DIR}/auth}"

# External dependencies (configurable for different environments)
export OPENSTACK_AUTH_DIR="${OPENSTACK_AUTH_DIR:-${BASE_DIR}/openstack-upi/auth}"

# Pull secret path - supports both Jenkins and Bastion environments
# Priority order:
#   1. PULL_SECRET_PATH (if already set)
#   2. PULL_SECRET_FILE (Jenkins environment variable, if file exists)
#   3. ${WORKSPACE}/deploy/data/pull-secret.txt (Jenkins workspace path)
#   4. ${BASE_DIR}/.openshift/pull-secret (Bastion default)
if [ -z "${PULL_SECRET_PATH:-}" ]; then
  if [ -n "${PULL_SECRET_FILE:-}" ] && [ -f "${PULL_SECRET_FILE}" ]; then
    # Use PULL_SECRET_FILE if it's set and the file exists
    export PULL_SECRET_PATH="${PULL_SECRET_FILE}"
  elif [ -n "${WORKSPACE:-}" ] && [ -f "${WORKSPACE}/deploy/data/pull-secret.txt" ]; then
    # Jenkins workspace path (handles case where PULL_SECRET_FILE contains unexpanded variable)
    export PULL_SECRET_PATH="${WORKSPACE}/deploy/data/pull-secret.txt"
  else
    # Bastion default
    export PULL_SECRET_PATH="${BASE_DIR}/.openshift/pull-secret"
  fi
else
  export PULL_SECRET_PATH="${PULL_SECRET_PATH}"
fi

export AUTH_YAML_PATH="${AUTH_YAML_PATH:-${BASE_DIR}/auth.yaml}"

# Generated/temporary files
export OCS_CI_CONF="${OCS_CI_CONF:-${BASE_DIR}/ocs-ci-conf.yaml}"
export PULL_SECRET_TXT="${PULL_SECRET_TXT:-${BASE_DIR}/pull-secret.txt}"
export ICSP_YAML="${ICSP_YAML:-${BASE_DIR}/icsp.yaml}"
export OCS_CI_DATA_DIR="${OCS_CI_DATA_DIR:-${OCS_UPI_DIR}/src/ocs-ci/data}"

# Log directory for ocs-ci runs
export OCS_CI_LOG_DIR="${OCS_CI_LOG_DIR:-${BASE_DIR}/logs-ocs-ci}"

################################################################################
# Debug output (uncomment for troubleshooting)
################################################################################
# echo "=== Common Variables Loaded ==="
# echo "BASE_DIR: ${BASE_DIR}"
# echo "REPO_DIR: ${REPO_DIR}"
# echo "OCS_UPI_DIR: ${OCS_UPI_DIR}"
# echo "LOG_DIR: ${LOG_DIR}"
# echo "==============================="

