# Patches Directory

This directory contains Git patch files that fix specific test cases for ODF versions 4.14 to 4.20.

## Available Patches

### 001-noobaa-postgres-config.patch
**Test Case**: `test_noobaa_postgres_cm_post_ocs_upgrade`  
**File Modified**: `ocs_ci/ocs/constants.py`  
**Change**: Adds `pg_stat_statements.track = all` configuration line after `shared_preload_libraries = 'pg_stat_statements'`  
**Reason**: Required for proper NooBaa PostgreSQL configuration validation in the test

### 002-selinux-relabel-test-rename.patch
**Test Case**: `test_selinux_relabel_for_existing_pvc`  
**File Modified**: `tests/cross_functional/kcs/test_selinux_relabel_solution.py`  
**Change**: Renames function from `deprecated_test_selinux_relabel_for_existing_pvc` to `test_selinux_relabel_for_existing_pvc`  
**Reason**: Removes the deprecated prefix to enable test execution

## How Patches Work

1. **Automatic Application**: Patches are automatically applied by `rerun_test.sh` when the corresponding test case is about to run
2. **Conditional**: Only applied when needed - not all patches are applied upfront
3. **One-time**: Each patch is applied only once per test run, tracked via associative array
4. **Non-blocking**: If a patch fails to apply (already applied or code changed), the script continues

## Adding New Patches

To add a new patch for a test case:

1. **Create the patch file**:
   ```bash
   cd ~/ocs-upi-kvm/src/ocs-ci/
   # Make your changes
   git diff > /path/to/odf_upgrade_repo/patches/00X-description.patch
   ```

2. **Add mapping** in `test_patch_mapping.conf`:
   ```
   test_name:00X-description.patch
   ```

3. **Document the patch** in this README

## Patch Naming Convention

- Format: `XXX-short-description.patch`
- XXX: Three-digit number (001, 002, etc.)
- Use hyphens for spaces in description
- Keep description concise but meaningful

## Troubleshooting

**Patch fails to apply**:
- Check if the patch was already applied: `cd ~/ocs-upi-kvm/src/ocs-ci/ && git status`
- Verify the target file exists and matches the expected version
- The script will log warnings but continue execution

**Test still fails after patch**:
- Manually verify the patch was applied: `git diff` in ocs-ci directory
- Check if the file content matches what the patch expects
- Review test execution logs in `rerun-logs/` directory
