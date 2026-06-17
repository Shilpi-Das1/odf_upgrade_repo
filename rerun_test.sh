#!/bin/bash

################################################################################
# MASTER SCRIPT: ODF Rerun Test Automation
#
# This is the ONLY script need to run!
#
# Usage: bash rerun_test.sh
#
# What it does:
# 1. Reads ODF version from var.ini
# 2. Automatically runs environment setup (setup_environment.sh)
# 3. Executes all failed test cases from Tier 1 and Tier 4a
# 4. Generates execution summary
#
# Prerequisites:
# - var.ini file with UPGRADE_OCS_CHANNEL configured
# - Required files on server (see README.md)
################################################################################

# Source common variables for multi-environment support
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common_vars.sh"

# Source var.ini
if [ -f "var.ini" ]; then
    # Read file line by line to handle CRLF manually if needed or just source it
    source var.ini
else
    echo "var.ini not found!"
    exit 1
fi

# Ensure OCS_VERSION is set
if [ -z "$UPGRADE_OCS_CHANNEL" ]; then
    echo "Error: UPGRADE_OCS_CHANNEL not found in var.ini"
    exit 1
fi

# Clean variable - remove carriage returns and surrounding whitespace
UPGRADE_OCS_CHANNEL=$(echo "$UPGRADE_OCS_CHANNEL" | tr -d '\r' | xargs)
export OCS_VERSION=$UPGRADE_OCS_CHANNEL

echo "DEBUG: OCS_VERSION is '$OCS_VERSION'"

# Check if environment setup is needed
# This setup is required for ODF versions 4.14 to 4.20
SETUP_SCRIPT="$(pwd)/setup_environment.sh"

if [ -f "$SETUP_SCRIPT" ]; then
    echo "=========================================="
    echo "Step 1: Running Environment Setup"
    echo "=========================================="
    
    # Make setup script executable
    chmod +x "$SETUP_SCRIPT"
    
    # Automatically run the setup script
    echo "Executing: bash $SETUP_SCRIPT $OCS_VERSION"
    echo ""
    
    if bash "$SETUP_SCRIPT" "$OCS_VERSION"; then
        echo ""
        echo "=========================================="
        echo "Environment setup completed successfully!"
        echo "=========================================="
        echo ""
    else
        echo ""
        echo "ERROR: Environment setup failed!"
        echo "Please check the errors above and try again."
        exit 1
    fi
else
    echo "Warning: setup_environment.sh not found. Proceeding without environment setup."
fi

echo "=========================================="
echo "Step 2: Starting Test Execution"
echo "=========================================="
echo ""

# Set FILE_PATH to absolute current directory so it remains valid after cd
export FILE_PATH=$(pwd)
export RERUN_LOG_DIR="${LOG_DIR}/rerun-logs"
SUMMARY_FILE="${LOG_DIR}/rerun-logs/execution_summary.txt"
mkdir -p ${RERUN_LOG_DIR}
mkdir -p $FILE_PATH/patches

# Initialize Summary File
echo "Test Execution Summary" > "$SUMMARY_FILE"
echo "======================" >> "$SUMMARY_FILE"
echo "Test Case | Tier | Status" >> "$SUMMARY_FILE"

# Define Tiers to run
TIERS=("1" "4a")



# Clean up previous patch tracking
rm -f $FILE_PATH/patches/.applied_patches

# Activate Environment
source $BASE_DIR/venv/bin/activate
cd ${OCS_UPI_DIR}/src/ocs-ci

# Function to apply patch if test case requires it
apply_patch_if_needed() {
    local test_case=$1
    # Extract test name and remove parametrization (e.g., [5])
    local test_name=$(echo "$test_case" | awk -F '::' '{print $NF}' | sed 's/\[[^]]*\]$//')
    local patch_dir="$FILE_PATH/patches"
    local mapping_file="$patch_dir/test_patch_mapping.conf"
    local applied_marker="$patch_dir/.applied_patches"
    
    # Check if mapping file exists
    if [ ! -f "$mapping_file" ]; then
        return 0
    fi
    
    # Look for test name in mapping file (ignore comments and empty lines)
    local patch_file=$(grep -v "^#" "$mapping_file" | grep -v "^$" | grep "^${test_name}:" | cut -d':' -f2)
    
    if [ -n "$patch_file" ]; then
        # Check if patch already applied (using marker file instead of associative array)
        if [ -f "$applied_marker" ] && grep -q "^${patch_file}$" "$applied_marker" 2>/dev/null; then
            return 0  # Already applied, skip silently
        fi
        
        echo "→ Test case requires patch: $patch_file"
        local patch_path="$patch_dir/$patch_file"
        
        if [ -f "$patch_path" ]; then
            cd ${OCS_UPI_DIR}/src/ocs-ci/
            
            # Check if patch can be applied
            if git apply --check "$patch_path" 2>/dev/null; then
                git apply "$patch_path"
                echo "✓ Successfully applied patch: $patch_file"
                echo "$patch_file" >> "$applied_marker"
                cd - > /dev/null
                return 0
            else
                echo "⚠ Patch already applied or not applicable: $patch_file"
                echo "$patch_file" >> "$applied_marker"
                cd - > /dev/null
                return 0
            fi
        else
            echo "✗ Patch file not found: $patch_path"
            cd - > /dev/null
            return 1
        fi
    fi
    
    return 0
}

for TIER in "${TIERS[@]}"; do
    echo "----------------------------------------"
    echo "Starting process for Tier $TIER"
    
    export TIER_NO=$TIER
    TEST_CASE_DIR="$FILE_PATH/Rerun-Test-Cases/ODF $OCS_VERSION"
    
    # Determine pattern based on Tier
    if [ "$TIER" == "1" ]; then
        PATTERN="tier*1*.log"
    else
        PATTERN="tier*4a*.log"
    fi
    
    # Find Log File
    FILENAME=$(find "$TEST_CASE_DIR" -maxdepth 1 -name "$PATTERN" | head -n 1)

    if [ -z "$FILENAME" ]; then
        echo "No log file found for Tier $TIER in $TEST_CASE_DIR"
        continue # Skip to next tier
    fi

    echo "Using Log File: $FILENAME"

    # Extract Failed Tests
    if grep -qE "FAILED|ERROR" "$FILENAME" && grep -q "::" "$FILENAME"; then
        echo "Detected log file. Extracting failed test cases..."
        grep -E "FAILED|ERROR" "$FILENAME" | grep -oE "[^[:space:]]+::[^[:space:]]+" > "${FILENAME}.extracted"
        INPUT_FILE="${FILENAME}.extracted"
    else
        INPUT_FILE="$FILENAME"
    fi

    echo "Reading tests from: $INPUT_FILE"

    while IFS= read -r TEST_CASE
    do
        
        
        # Apply patch if this test case requires it
        apply_patch_if_needed "$TEST_CASE"
        
        str=$(oc get cephcluster -n openshift-storage | grep -o HEALTH_OK)
        echo "Processing: $TEST_CASE"

        if [ "$str" = "HEALTH_OK" ];then
            LOG_FILE_NAME=$(awk -F '::' '{print $NF}'<<<"$TEST_CASE" | tr -d '[:space:]')
            size=${#LOG_FILE_NAME}
            if [[ $size -gt 5 ]]; then
                echo "Running Test: $TEST_CASE"
                
                # Executing COMMAND
                nohup run-ci -m "tier$TIER_NO" --ocs-version $OCS_VERSION --ocsci-conf=conf/ocsci/production_powervs_upi.yaml --ocsci-conf conf/ocsci/lso_enable_rotational_disks.yaml --ocsci-conf ${OCS_CI_CONF} --cluster-name "ocstest" --cluster-path ${BASE_DIR}/ --collect-logs $TEST_CASE | tee ${RERUN_LOG_DIR}/$LOG_FILE_NAME.log 2>&1
                
                # Capture Exit Code of run-ci (first command in pipe)
                EXIT_CODE=${PIPESTATUS[0]}
                
                # Analyze Log File for detailed status
                CURRENT_LOG="${RERUN_LOG_DIR}/$LOG_FILE_NAME.log"
                
                # Check for Pytest summary patterns to identify status
                if grep -qE "={2,}.*[0-9]+ error.*={2,}" "$CURRENT_LOG"; then
                    STATUS="Error"
                elif grep -qE "={2,}.*[0-9]+ failed.*={2,}" "$CURRENT_LOG"; then
                    STATUS="Fail"
                elif grep -qE "={2,}.*[0-9]+ skipped.*={2,}" "$CURRENT_LOG"; then
                    STATUS="Skipped"
                elif grep -qE "={2,}.*[0-9]+ deselected.*={2,}" "$CURRENT_LOG"; then
                    STATUS="Deselect"
                elif [ $EXIT_CODE -eq 0 ]; then
                    STATUS="Pass"
                else
                    STATUS="Fail"
                fi
                
                echo "$TEST_CASE | Tier $TIER | $STATUS" >> "$SUMMARY_FILE"
                
                escaped_pattern=$(echo "$TEST_CASE" | sed 's/[[]/\\[/g; s/[]]/\\]/g; s/\//\\\//g')
                # sed -i "/$escaped_pattern$/d" "$INPUT_FILE" 

                echo "sleep 10 seconds before next test execution"
                sleep 10 
            else 
                echo "Skipping invalid test case name length"
            fi
        else
            echo "exit due to ceph health issue"
            echo "Failed at: $TEST_CASE"
            exit 1
        fi
    done < <(cat < "$INPUT_FILE")

done

echo ""
echo "Execution Completed."
echo "Summary:"
cat "$SUMMARY_FILE"
