# ODF Rerun Test Automation - Setup Guide

## Overview
This repository contains automation scripts for rerunning failed ODF (OpenShift Data Foundation) test cases across different ODF versions (4.14 to 4.20).

**✨ NEW: Multi-Environment Support** - Scripts now work on both Jenkins and bastion nodes automatically! See [ENVIRONMENT_SETUP.md](ENVIRONMENT_SETUP.md) for details.

## Prerequisites
- Access to the target server
- Git installed
- Required directories and files (paths are now configurable - see [ENVIRONMENT_SETUP.md](ENVIRONMENT_SETUP.md)):
  - `/usr/local/bin/oc`
  - OpenStack auth directory (default: `${BASE_DIR}/openstack-upi/auth/`)
  - Auth YAML file (default: `${BASE_DIR}/auth.yaml`)
  - OpenShift pull secret (default: `${BASE_DIR}/.openshift/pull-secret`)
  - Binary directory (default: `${BASE_DIR}/bin/`)
  - Python virtual environment at `~/venv/`

## Quick Start 

### Step 1: Configure var.ini

Ensure your `var.ini` file contains the correct ODF version:

```ini
UPGRADE_OCS_CHANNEL=4.17
```

Replace `4.17` with your target ODF version (4.14, 4.15, 4.16, 4.17, 4.18, 4.19, 4.20 or 4.21).

### Step 2: Run the Script

On your target server, execute:

```bash
cd ~/odf_upgrade_repo/
bash rerun_test.sh
```

**That's it!** The script will automatically:
1. ✅ Read the ODF version from `var.ini`
2. ✅ Run environment setup (`setup_environment.sh`)
3. ✅ Initialize submodules and copy configuration files
4. ✅ **Apply code patches conditionally** when specific test cases are detected
5. ✅ Execute all failed test cases from Tier 1 and Tier 4a
6. ✅ Generate execution summary

---

## Patch Management

### Overview

Some test cases require code modifications to run properly across different ODF versions (4.14 to 4.20). The automation system includes a **conditional patch management** feature that automatically applies necessary fixes before running specific test cases.

### How It Works

1. **Automatic Detection**: Before each test case runs, the script checks if it requires a patch
2. **Conditional Application**: Patches are applied **only when needed** - not all patches are applied upfront
3. **One-time Application**: Each patch is applied only once per test run, even if multiple tests need it
4. **Non-blocking**: If a patch fails (already applied or code changed), the script continues

### Supported Test Cases

| Test Case | Patch | Description |
|-----------|-------|-------------|
| `test_noobaa_postgres_cm_post_ocs_upgrade` | 001 | Adds PostgreSQL configuration line |
| `test_selinux_relabel_for_existing_pvc` | 002 | Removes deprecated function prefix |

### Patch Files Location

All patches are stored in the `patches/` directory:
```
patches/
├── noobaa-postgres-config.patch
├── selinux-relabel-test-rename.patch
├── test_patch_mapping.conf
└── README.md
```

### Adding New Patches

See [patches/README.md](patches/README.md) for detailed instructions on creating and adding new patches.

---

## Detailed Information

### What Happens During Environment Setup (Automatic)

## File Structure

```
odf_upgrade_repo/
├── common_vars.sh            # ⭐ NEW: Central configuration for all paths
├── setup_environment.sh      # Environment setup script
├── rerun_test.sh             # Main test execution script
├── deploy_upgrade_script.sh  # Deployment and upgrade script
├── run_tier1_tier4a.sh       # Tier 1 and 4a test execution
├── var.ini                   # Configuration file
├── ENVIRONMENT_SETUP.md      # ⭐ NEW: Multi-environment configuration guide
├── patches/                  # Code patches directory
│   ├── test_patch_mapping.conf
│   └── *.patch files
├── Rerun-Test-Cases/         # Test case logs directory
│   ├── ODF 4.14/
│   ├── ODF 4.15/
│   ├── ODF 4.16/
│   ├── ODF 4.17/
│   ├── ODF 4.18/
│   ├── ODF 4.19/
│   └── ODF 4.20/
├── rerun-logs/               # Generated test execution logs
└── execution_summary.txt     # Test execution summary
```

## What the Setup Script Does

1. **Backs up existing environment**: Moves `ocs-upi-kvm/` to `aocs-upi-kvm/`
2. **Clones repository**: Fresh clone of `ocs-upi-kvm`
3. **Version-specific checkout**:
   - ODF 4.14-4.18: Checks out `v4.18.0` branch
   - ODF 4.19-4.20: Uses latest code
4. **Initializes submodules**: Updates all required submodules
5. **Copies configuration files**:
   - `oc` binary to `${BIN_DIR}`
   - Auth directory from `${OPENSTACK_AUTH_DIR}`
   - `auth.yaml` to ocs-ci data directory
   - Pull secrets to required locations

**Note**: All paths are now configurable. See [ENVIRONMENT_SETUP.md](ENVIRONMENT_SETUP.md) for customization options.

## Multi-Environment Support

### Running on Jenkins
Scripts automatically detect Jenkins environment via `$WORKSPACE` variable:
```bash
# Jenkins automatically sets WORKSPACE
# Scripts use it as BASE_DIR
bash deploy_upgrade_script.sh
```

### Running on Bastion
Scripts default to `/root` when `$WORKSPACE` is not set:
```bash
cd /root/odf_upgrade_repo
bash rerun_test.sh
```

### Custom Paths
Override any path variable:
```bash
export BASE_DIR=/custom/path
export LOG_DIR=/var/logs/odf
bash run_tier1_tier4a.sh
```

For complete details, see [ENVIRONMENT_SETUP.md](ENVIRONMENT_SETUP.md).

## Troubleshooting

### Setup Script Fails
- Ensure you have internet connectivity to clone from GitHub
- Verify all prerequisite files exist (paths are configurable - see [ENVIRONMENT_SETUP.md](ENVIRONMENT_SETUP.md))
- Check you have write permissions to `${BASE_DIR}`

### Rerun Test Script Fails
- Ensure environment setup was completed successfully
- Verify `var.ini` has the correct ODF version
- Check that the virtual environment exists at `~/venv/`
- Ensure test case log files exist in the appropriate directory

### Ceph Health Issues
The script checks for `HEALTH_OK` status before running each test. If Ceph is not healthy, the script will exit. Check cluster health with:
```bash
oc get cephcluster -n openshift-storage
```

### Patch Application Issues

**Patch fails to apply**:
- Check if patch was already applied: `cd ~/ocs-upi-kvm/src/ocs-ci/ && git status`
- The script will show a warning but continue execution
- Review patch application logs in the test execution output

**Test fails even after patch**:
- Manually verify patch was applied: `cd ~/ocs-upi-kvm/src/ocs-ci/ && git diff`
- Check test execution logs in `rerun-logs/` directory
- See `patches/README.md` for detailed patch information

## Version-Specific Notes

### ODF 4.14 - 4.18
- Uses stable `v4.18.0` branch
- Tested and validated for these versions

### ODF 4.19 - 4.20
- Uses latest code from main branch
- Supports newer features and fixes

## Output Files

- **execution_summary.txt**: Summary of all test executions with status
- **rerun-logs/*.log**: Detailed logs for each test case execution

## Support

For issues or questions, refer to:
- [ocs-upi-kvm repository](https://github.com/ocp-power-automation/ocs-upi-kvm)
- [ocs-ci repository](https://github.com/red-hat-storage/ocs-ci)
