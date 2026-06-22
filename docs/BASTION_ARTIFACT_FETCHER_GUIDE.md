# Bastion Artifact Fetcher and JIRA Integration Guide

## Overview

The `scripts/fetch_bastion_artifacts.py` script automates the process of:
1. Fetching artifacts from a bastion machine via SSH/SCP
2. Parsing test results from `test-summary.txt`
3. Updating JIRA subtask configuration
4. Creating JIRA subtasks
5. Adding test results as comments to JIRA
6. Uploading test-summary.txt and odf_tier_logs-*.tar.gz as JIRA attachments
7. Cleaning up downloaded artifacts

This script works on both **Linux** and **Windows** environments.

---

## Prerequisites

### 1. Python Environment
- Python 3.11 or higher
- Required packages (install via `pip install -r requirements.txt`):
  - `jira>=3.5.0`
  - `python-dotenv>=1.0.0`
  - `urllib3>=1.26.0`

### 2. SSH Access
- SSH private key file (e.g., `id_rsa`)
- Network access to bastion machine
- Proper permissions on the bastion machine

### 3. Environment Configuration
Create a `.env` file in the project root with JIRA credentials:

```bash
# JIRA Configuration
JIRA_SERVER=https://your-jira-instance.atlassian.net
JIRA_EMAIL=your-email@example.com
JIRA_API_TOKEN=your-jira-api-token
JIRA_PROJECT_KEY=YOUR_PROJECT_KEY
```

**Note:** Never commit the `.env` file or SSH keys to git!

### 4. SSH Private Key Setup

#### Option 1: Place in Repository Root (Recommended)
```
odf_upgrade_repo/
├── id_rsa              ← Place your SSH key here
├── .env
├── scripts/
│   └── fetch_bastion_artifacts.py
└── .gitignore          ← Protects id_rsa from being committed
```

**Set proper permissions:**
```bash
# Linux/Mac
chmod 600 id_rsa

# Windows (PowerShell as Administrator)
icacls id_rsa /inheritance:r
icacls id_rsa /grant:r "%USERNAME%:R"
```

#### Option 2: Use Custom Location
You can specify a custom SSH key location using the `--key-file` parameter.

### 5. Additional Files Required
- `subtask_config.json` or `examples/subtask_config.json.example` - JIRA subtask configuration template
- `odf_version_mapping.json` or `examples/odf_version_mapping.json.example` - Mapping of ODF versions to parent JIRA issues
- `scripts/create_jira_subtask.py` - Script for creating JIRA subtasks
- `scripts/jira_utils.py` - Shared JIRA utility functions

---

## How to Get API Tokens

### JIRA API Token
1. Go to https://id.atlassian.com/manage-profile/security/api-tokens
2. Click "Create API token"
3. Give it a label (e.g., "Bastion Integration")
4. Click "Create"
5. Copy the token immediately

---

## Usage

### Basic Command

```bash
python scripts/fetch_bastion_artifacts.py --ip <BASTION_IP>
```

### Parameters

- `--ip` (required): Bastion machine IP address
- `--remote-dir` (optional): Remote directory containing artifacts (default: `/root`)
- `--key-file` (optional): Path to SSH private key file (default: `id_rsa` in current directory)
- `--user` (optional): SSH username (default: `root`)
- `--due-date` or `-d` (optional): Due date for JIRA subtask in format `d/MMM/yy`
- `--resume` or `-r` (optional): Resume from previous run, skip already completed steps

### Examples

**Linux/Mac:**
```bash
# Basic usage (uses id_rsa in current directory)
python scripts/fetch_bastion_artifacts.py --ip 192.168.1.100

# With due date
python scripts/fetch_bastion_artifacts.py --ip 192.168.1.100 --due-date "17/Jun/26"

# Custom SSH key location
python scripts/fetch_bastion_artifacts.py --ip 192.168.1.100 --key-file ~/.ssh/my_key

# Custom remote directory
python scripts/fetch_bastion_artifacts.py --ip 192.168.1.100 --remote-dir /home/user/artifacts

# Custom SSH user
python scripts/fetch_bastion_artifacts.py --ip 192.168.1.100 --user admin

# Resume after failure
python scripts/fetch_bastion_artifacts.py --ip 192.168.1.100 --resume

# Full example with all options
python scripts/fetch_bastion_artifacts.py \
  --ip 192.168.1.100 \
  --remote-dir /home/user \
  --key-file ~/.ssh/id_rsa \
  --user admin \
  --due-date "20/Dec/26" \
  --resume
```

**Windows (PowerShell):**
```powershell
# Basic usage
python scripts/fetch_bastion_artifacts.py --ip 192.168.1.100

# With due date
python scripts/fetch_bastion_artifacts.py --ip 192.168.1.100 --due-date "17/Jun/26"

# Custom SSH key location
python scripts/fetch_bastion_artifacts.py --ip 192.168.1.100 --key-file C:\Users\YourName\.ssh\id_rsa

# Resume after failure
python scripts/fetch_bastion_artifacts.py --ip 192.168.1.100 --resume
```

**Date Format Notes:**
- Always use 3-letter month abbreviations (Jan, Feb, Mar, Apr, May, Jun, Jul, Aug, Sep, Oct, Nov, Dec)
- Day can be 1 or 2 digits (5 or 05 both work)
- Year should be 2 digits (26 for 2026, 27 for 2027)
- Always enclose the date in quotes

---

## Workflow Details

### Step 1: Fetch Artifacts from Bastion
The script connects to the bastion machine via SSH/SCP and downloads artifacts matching these patterns:
- `test-summary*.txt` (e.g., `test-summary-4.21.9-1.txt`)
- `must-gather*.tar.gz` (e.g., `must-gather-4.21.9-1.tar.gz`)
- `odf_tier_logs*.tar.gz` (e.g., `odf_tier_logs-4.21.9-1.tar.gz`)

**Artifacts are saved to:** `bastion_artifacts/` directory

### Step 2: Parse test-summary.txt
The script looks for `test-summary*.txt` in the downloaded artifacts and parses it to extract:

- **ODF Build Version** (e.g., `4.21.9-1`)
- **ODF Version** (e.g., `4.21`)
- **Summary** (e.g., `ODF 4.21.9`)
- **Test Result Sections** (all headers and their content)

#### Expected test-summary.txt Format

```
========================================
ODF Build: 4.21.9-1 - Status Before Upgrade
========================================
Some content here...

========================================
ODF Build: 4.21.9-1 - Status After Upgrade
========================================
Some content here...

========================================
ODF Build: 4.21.9-1 - Tier 1 Summary
========================================
Some content here...

... (more sections)
```

### Step 3: Update subtask_config.json
The script updates (or creates) `subtask_config.json` with:

```json
{
  "odf_version": "4.21",
  "summary": "ODF 4.21.9",
  "due_date": "17/Jun/26",
  ... (other existing fields)
}
```

### Step 4: Create JIRA Subtask
The script runs `scripts/create_jira_subtask.py` which:
- Reads the updated `subtask_config.json`
- Maps ODF version to parent JIRA issue (using `odf_version_mapping.json`)
- Creates a new subtask (or finds existing one with same summary)
- Returns the subtask key (e.g., `CSOP-1234`)

### Step 5: Add Comments to JIRA
Each section from `test-summary.txt` is added as a separate comment to the JIRA subtask.

**Comment Format:**
```
{code}
========================================
ODF Build: 4.21.9-1 - Status Before Upgrade
========================================
Some content here...
{code}
```

### Step 6: Upload Attachments
- The complete `test-summary*.txt` file is uploaded as an attachment
- The `odf_tier_logs*.tar.gz` file is uploaded as an attachment (if found)

### Step 7: Cleanup
The `bastion_artifacts/` directory and all downloaded files are deleted to save disk space.

---

## Output Example

```
✓ Connected to JIRA: https://your-jira-instance.atlassian.net
✓ Bastion connection configured: root@192.168.1.100
✓ Using SSH key: id_rsa

============================================================
Fetching artifacts from bastion machine
============================================================

  Fetching: test-summary*.txt
  ✓ Downloaded: test-summary-4.21.9-1.txt

  Fetching: must-gather*.tar.gz
  ✓ Downloaded: must-gather-4.21.9-1.tar.gz

  Fetching: odf_tier_logs*.tar.gz
  ✓ Downloaded: odf_tier_logs-4.21.9-1.tar.gz

✓ Downloaded 3 artifact(s) from bastion

============================================================
Parsing test-summary.txt
============================================================
✓ ODF Build: 4.21.9-1
✓ ODF Version: 4.21
✓ Summary: ODF 4.21.9
✓ Found 9 section(s)

============================================================
Updating subtask_config.json
============================================================
✓ Updated subtask_config.json:
  - odf_version: 4.21
  - summary: ODF 4.21.9
  - due_date: 17/Jun/26

============================================================
Creating JIRA subtask
============================================================
✓ Subtask created successfully: CSOP-1234

============================================================
Adding comments to JIRA subtask CSOP-1234
============================================================
  Adding comment 1/9: ODF Build: 4.21.9-1 - Status Before Upgrade...
  ✓ Comment added
  ... (8 more comments)
✓ Added 9 comment(s) to CSOP-1234

============================================================
Uploading attachment to JIRA subtask CSOP-1234
============================================================
✓ Uploaded test-summary-4.21.9-1.txt to CSOP-1234

============================================================
Uploading attachment to JIRA subtask CSOP-1234
============================================================
✓ Uploaded odf_tier_logs-4.21.9-1.tar.gz to CSOP-1234

============================================================
Cleaning up artifacts
============================================================
✓ Deleted bastion_artifacts

============================================================
✓ Process completed successfully!
============================================================
JIRA Subtask: CSOP-1234
URL: https://your-jira-instance.atlassian.net/browse/CSOP-1234
============================================================
```

---

## Troubleshooting

### Error: "SSH key file not found"
**Solution:** 
- Ensure `id_rsa` file exists in the current directory, or
- Specify custom path with `--key-file` parameter

### Error: "Permission denied (publickey)"
**Solutions:**
1. Verify SSH key has correct permissions:
   ```bash
   chmod 600 id_rsa  # Linux/Mac
   ```
2. Ensure the public key is added to bastion's `~/.ssh/authorized_keys`
3. Test SSH connection manually:
   ```bash
   ssh -i id_rsa root@192.168.1.100
   ```

### Error: "No artifacts downloaded from bastion machine"
**Solutions:**
1. Verify artifacts exist on bastion machine:
   ```bash
   ssh -i id_rsa root@192.168.1.100 "ls -la /root/test-summary*.txt"
   ```
2. Check remote directory path with `--remote-dir`
3. Ensure you have read permissions on the files

### Error: "Missing JIRA credentials"
**Solution:** Ensure your `.env` file contains `JIRA_SERVER`, `JIRA_EMAIL`, and `JIRA_API_TOKEN`.

### Error: "Failed to connect to JIRA"
**Solutions:**
- Verify JIRA server URL is correct
- Check if JIRA API token is valid
- Ensure your JIRA email is correct
- Check network connectivity

### Error: "test-summary*.txt not found in artifacts"
**Solutions:**
- Verify the file exists on bastion machine
- Check if the filename matches the pattern `test-summary*.txt`
- Ensure the file was downloaded successfully

### Warning: "odf_tier_logs*.tar.gz not found in artifacts"
**Behavior:** This is a warning, not an error. The script will continue without uploading tier logs.

### Resume Feature
If the script fails partway through, use `--resume` to skip already completed steps:
```bash
python scripts/fetch_bastion_artifacts.py --ip 192.168.1.100 --resume
```

This will:
- Skip downloading if artifacts already exist locally
- Skip adding comments if they already exist in JIRA
- Skip uploading attachments if they already exist in JIRA

---

## Platform-Specific Notes

### Windows
- Use PowerShell or Command Prompt
- Requires OpenSSH client (included in Windows 10/11)
- Paths use backslashes (`\`) but Python handles this automatically
- The script creates `bastion_artifacts\` directory

### Linux/Mac
- Use Terminal or Bash
- SSH/SCP commands are native
- Paths use forward slashes (`/`)
- The script creates `bastion_artifacts/` directory

---

## File Structure

```
project-root/
├── scripts/
│   ├── fetch_bastion_artifacts.py    # Main script
│   ├── create_jira_subtask.py        # JIRA subtask creation
│   └── jira_utils.py                 # Shared JIRA utilities
├── examples/
│   ├── .env.example                  # Credentials template
│   ├── subtask_config.json.example   # JIRA config template
│   └── odf_version_mapping.json.example  # Version mapping template
├── id_rsa                        # SSH private key (DO NOT COMMIT)
├── subtask_config.json           # JIRA configuration (auto-updated)
├── odf_version_mapping.json      # ODF version to parent mapping
├── .env                          # Credentials (DO NOT COMMIT)
├── requirements.txt              # Python dependencies
├── bastion_artifacts/            # Temporary (auto-deleted)
│   ├── test-summary-4.21.9-1.txt
│   ├── must-gather-4.21.9-1.tar.gz
│   └── odf_tier_logs-4.21.9-1.tar.gz
└── docs/
    └── BASTION_ARTIFACT_FETCHER_GUIDE.md  # This file
```

---

## Security Best Practices

1. **Never commit `.env` file** - It contains sensitive credentials
2. **Never commit SSH keys** - They provide server access
3. **Set proper key permissions** - `chmod 600 id_rsa` on Linux/Mac
4. **Use API tokens** - Never use passwords directly
5. **Rotate tokens regularly** - Change API tokens periodically
6. **Limit token permissions** - Use tokens with minimal required permissions
7. **Keep tokens secure** - Don't share tokens via email or chat

---

## Comparison with Jenkins Fetcher

| Feature | Bastion Fetcher | Jenkins Fetcher |
|---------|----------------|-----------------|
| Source | Bastion machine via SSH | Jenkins server via API |
| Authentication | SSH key | Jenkins API token |
| Artifacts | SCP download | HTTP download |
| Google Drive | ❌ Not supported | ✅ Supported |
| Resume | ✅ Supported | ✅ Supported |
| JIRA Integration | ✅ Full support | ✅ Full support |

---

## Support

For issues or questions:
1. Check this documentation
2. Review error messages carefully
3. Verify all prerequisites are met
4. Check `.env` file configuration
5. Test SSH connection manually
6. Ensure network connectivity to bastion and JIRA

---

## Version History

- **v1.0** - Initial release with bastion artifact fetching and JIRA integration
- **v1.1** - Refactored to use shared `jira_utils.py` module

---

**Made with Bob** 🤖