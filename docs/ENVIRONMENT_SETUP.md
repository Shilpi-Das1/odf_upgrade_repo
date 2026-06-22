# Multi-Environment Configuration Guide

This document explains how the ODF upgrade scripts work across different environments (Jenkins and Bastion nodes).

## Overview

All scripts now use a centralized configuration file (`common_vars.sh`) that automatically detects the environment and sets appropriate paths. This allows the same scripts to run on both Jenkins and bastion nodes without modification.

## How It Works

### Automatic Environment Detection

The scripts use the `WORKSPACE` environment variable to detect the environment:

- **Jenkins**: `WORKSPACE` is automatically set by Jenkins (e.g., `/var/lib/jenkins/workspace/job-name`)
- **Bastion**: `WORKSPACE` is not set, so it defaults to `/root`

```bash
export BASE_DIR="${WORKSPACE:-/root}"
```

### Variable Hierarchy

All path variables follow this pattern:
```bash
export VARIABLE_NAME="${VARIABLE_NAME:-default_value}"
```

This means:
1. If the variable is already set in the environment, use that value
2. Otherwise, use the default value

## Configuration Variables

### Core Directories

| Variable | Default | Description |
|----------|---------|-------------|
| `BASE_DIR` | `${WORKSPACE:-/root}` | Base directory (auto-detected) |
| `REPO_DIR` | `${BASE_DIR}/odf_upgrade_repo` | Repository location |
| `OCS_UPI_DIR` | `${BASE_DIR}/ocs-upi-kvm` | OCS UPI KVM directory |
| `LOG_DIR` | `${BASE_DIR}/odf_tier_logs` | Log output directory |
| `BIN_DIR` | `${BASE_DIR}/bin` | Binary directory |
| `AUTH_DIR_PATH` | `${BASE_DIR}/auth` | Authentication directory |

### External Dependencies

| Variable | Default | Description |
|----------|---------|-------------|
| `OPENSTACK_AUTH_DIR` | `${BASE_DIR}/openstack-upi/auth` | OpenStack auth directory |
| `PULL_SECRET_PATH` | `${BASE_DIR}/.openshift/pull-secret` | OpenShift pull secret |
| `AUTH_YAML_PATH` | `${BASE_DIR}/auth.yaml` | Auth YAML file |

### Generated Files

| Variable | Default | Description |
|----------|---------|-------------|
| `OCS_CI_CONF` | `${BASE_DIR}/ocs-ci-conf.yaml` | OCS CI configuration |
| `PULL_SECRET_TXT` | `${BASE_DIR}/pull-secret.txt` | Pull secret copy |
| `ICSP_YAML` | `${BASE_DIR}/icsp.yaml` | Image content source policy |
| `OCS_CI_DATA_DIR` | `${OCS_UPI_DIR}/src/ocs-ci/data` | OCS CI data directory |
| `OCS_CI_LOG_DIR` | `${BASE_DIR}/logs-ocs-ci` | OCS CI log directory |

## Usage Examples

### Running on Bastion (Default)

No special configuration needed. Scripts will use `/root` as the base directory:

```bash
cd /root/odf_upgrade_repo
bash deploy_upgrade_script.sh
```

### Running on Jenkins

Jenkins automatically sets `WORKSPACE`, so scripts will use that:

```bash
# Jenkins sets: WORKSPACE=/var/lib/jenkins/workspace/odf-upgrade-job
# Scripts automatically use: BASE_DIR=/var/lib/jenkins/workspace/odf-upgrade-job
bash deploy_upgrade_script.sh
```

### Custom Environment

Override any variable before running scripts:

```bash
# Use custom base directory
export BASE_DIR=/custom/path
bash deploy_upgrade_script.sh

# Use custom log directory
export LOG_DIR=/var/logs/odf
bash run_tier1_tier4a.sh

# Override multiple variables
export BASE_DIR=/opt/odf
export LOG_DIR=/var/log/odf
export OCS_UPI_DIR=/opt/ocs-upi-kvm
bash rerun_test.sh
```

### Testing Different Configurations

```bash
# Test with Jenkins-like environment
export WORKSPACE=/tmp/test-workspace
bash deploy_upgrade_script.sh

# Test with custom paths
export BASE_DIR=/tmp/test
export PULL_SECRET_PATH=/tmp/test/pull-secret
bash setup_environment.sh 4.18
```

## Modified Scripts

The following scripts have been updated to use configurable variables:

1. **common_vars.sh** (NEW) - Central configuration file
2. **deploy_upgrade_script.sh** - Deployment and upgrade script
3. **rerun_test.sh** - Test rerun automation
4. **run_tier1_tier4a.sh** - Tier 1 and 4a test execution
5. **setup_environment.sh** - Environment setup

## Migration from Hardcoded Paths

### Before (Hardcoded)
```bash
mkdir -p /root/odf_tier_logs
cp /root/.openshift/pull-secret /root/ocs-upi-kvm/src/ocs-ci/
```

### After (Configurable)
```bash
mkdir -p ${LOG_DIR}
cp ${PULL_SECRET_PATH} ${OCS_CI_DATA_DIR}/
```

## Troubleshooting

### Debug Mode

Uncomment the debug section in `common_vars.sh` to see which paths are being used:

```bash
# In common_vars.sh, uncomment:
echo "=== Common Variables Loaded ==="
echo "BASE_DIR: ${BASE_DIR}"
echo "REPO_DIR: ${REPO_DIR}"
echo "OCS_UPI_DIR: ${OCS_UPI_DIR}"
echo "LOG_DIR: ${LOG_DIR}"
echo "==============================="
```

### Verify Configuration

Check what values will be used:

```bash
source common_vars.sh
echo "BASE_DIR: ${BASE_DIR}"
echo "LOG_DIR: ${LOG_DIR}"
echo "OCS_UPI_DIR: ${OCS_UPI_DIR}"
```

### Common Issues

**Issue**: Scripts can't find files
- **Solution**: Ensure external dependencies (pull-secret, auth.yaml) are in the correct location or override the path variables

**Issue**: Permission denied
- **Solution**: Ensure the user has write permissions to `BASE_DIR` and subdirectories

**Issue**: Wrong directory used
- **Solution**: Check if `WORKSPACE` is set unexpectedly. Unset it or override `BASE_DIR`

## Best Practices

1. **Don't hardcode paths** - Always use the variables from `common_vars.sh`
2. **Test both environments** - Verify scripts work on both Jenkins and bastion
3. **Document custom overrides** - If you override variables, document why
4. **Use relative paths** - When possible, use paths relative to `BASE_DIR`
5. **Check prerequisites** - Ensure external files exist before running scripts

## Environment-Specific Setup

### Jenkins Pipeline Example

```groovy
pipeline {
    agent any
    environment {
        // Jenkins automatically sets WORKSPACE
        // Scripts will use it as BASE_DIR
        PULL_SECRET_PATH = credentials('openshift-pull-secret')
        AUTH_YAML_PATH = credentials('auth-yaml')
    }
    stages {
        stage('Deploy') {
            steps {
                sh 'bash deploy_upgrade_script.sh'
            }
        }
    }
}
```

### Bastion Node Setup

```bash
# Ensure required files are in place
ls -la /root/.openshift/pull-secret
ls -la /root/auth.yaml
ls -la /root/openstack-upi/auth/

# Run scripts normally
cd /root/odf_upgrade_repo
bash deploy_upgrade_script.sh
```

## Summary

✅ **Single source of truth** - All paths defined in `common_vars.sh`  
✅ **Auto-detection** - Automatically works on Jenkins and bastion  
✅ **Flexible** - Override any variable for custom setups  
✅ **Backward compatible** - Works on bastion without changes  
✅ **Maintainable** - Easy to update paths in one place