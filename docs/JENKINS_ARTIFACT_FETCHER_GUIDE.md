# Jenkins Artifact Fetcher and JIRA Integration Guide

## Overview

The `scripts/fetch_jenkins_artifacts.py` script automates the process of:
1. Fetching artifacts from Jenkins builds
2. Parsing test results from `test-summary.txt`
3. Updating JIRA subtask configuration
4. Creating JIRA subtasks
5. Adding test results as comments to JIRA
6. Uploading test-summary.txt and odf_tier_logs-*.tar.gz as JIRA attachments
7. **Uploading must-gather to Google Drive** (optional) in version-specific folders
8. Cleaning up downloaded artifacts

This script works on both **Linux** and **Windows** environments.

---

## Prerequisites

### 1. Python Environment
- Python 3.11 or higher
- Required packages (install via `pip install -r requirements.txt`):
  - `jira>=3.5.0`
  - `python-dotenv>=1.0.0`
  - `requests>=2.28.0`
  - `google-auth>=2.16.0`
  - `google-auth-oauthlib>=1.0.0`
  - `google-auth-httplib2>=0.1.0`
  - `google-api-python-client>=2.80.0`

### 2. Environment Configuration
Create a `.env` file in the project root with the following credentials:

```bash
# Jenkins Configuration
JENKINS_URL=https://your-jenkins-server.com/job/your-job-path
JENKINS_USER=your-jenkins-username
JENKINS_API_TOKEN=your-jenkins-api-token

# JIRA Configuration
JIRA_SERVER=https://your-jira-instance.atlassian.net
JIRA_EMAIL=your-email@example.com
JIRA_API_TOKEN=your-jira-api-token
JIRA_PROJECT_KEY=YOUR_PROJECT_KEY

# Google Drive Configuration (Optional)
GOOGLE_DRIVE_PARENT_FOLDER_ID=17TvbLfm--fvpeBbnQvAnXeLBYrKC650y
GOOGLE_DRIVE_CREDENTIALS_FILE=google_drive_service_account_creds.json
```

**Note:** Never commit the `.env` file or `google_drive_service_account_creds.json` to git!

### 3. Additional Files Required
- `subtask_config.json` or `examples/subtask_config.json.example` - JIRA subtask configuration template
- `odf_version_mapping.json` or `examples/odf_version_mapping.json.example` - Mapping of ODF versions to parent JIRA issues
- `scripts/create_jira_subtask.py` - Script for creating JIRA subtasks
- `google_drive_service_account_creds.json` - Google Drive service account credentials (optional)

---

## How to Get API Tokens

### Jenkins API Token
1. Log in to Jenkins
2. Click on your username (top right)
3. Click "Configure"
4. Scroll to "API Token" section
5. Click "Add new Token"
6. Give it a name and click "Generate"
7. Copy the token (you won't see it again!)

### JIRA API Token
1. Go to https://id.atlassian.com/manage-profile/security/api-tokens
2. Click "Create API token"
3. Give it a label (e.g., "Jenkins Integration")
4. Click "Create"
5. Copy the token immediately

### Google Drive Service Account (Optional)

#### Step 1: Create Google Cloud Project
1. Open: https://console.cloud.google.com/
2. Click **Select Project** → **New Project**
3. Enter project name (e.g., "ODF-Drive-Uploader")
4. Click **Create**
5. Select the newly created project

#### Step 2: Enable Google Drive API
1. Go to **APIs & Services** → **Library**
2. Search: **Google Drive API**
3. Click on it → Click **Enable**

#### Step 3: Create Service Account
1. Go to **APIs & Services** → **Credentials**
2. Click **Create Credentials** → **Service Account**
3. Enter name (e.g., "drive-uploader")
4. Click **Create & Continue**
5. Skip roles (click **Continue**)
6. Click **Done**

#### Step 4: Generate JSON Key
1. Click on your service account (from the list)
2. Go to **Keys** tab
3. Click **Add Key** → **Create New Key**
4. Select **JSON** format
5. Click **Create** (file downloads automatically)
6. Rename the downloaded file to `google_drive_service_account_creds.json`
7. Place it in the project root directory

#### Step 5: Share Google Drive Folder
1. Open the JSON credentials file
2. Find the `client_email` field (looks like: `drive-uploader@project-id.iam.gserviceaccount.com`)
3. Go to your Google Drive folder (the parent folder where you want to upload files)
4. Right-click → **Share**
5. Add the service account email
6. Give it **Editor** permissions
7. Click **Send**

**Important:**
- Never commit the credentials JSON file to git! It's already in `.gitignore`.
- The service account email must have access to the Google Drive folder

---

## Usage

### Basic Command

```bash
python scripts/fetch_jenkins_artifacts.py --build-number <BUILD_NUMBER> --due-date "<DUE_DATE>"
```

### Parameters

- `--build-number` or `-b` (required): Jenkins build number to fetch artifacts from
- `--due-date` or `-d` (optional): Due date for JIRA subtask in format `d/MMM/yy`
  - **Format:** `d/MMM/yy` (day/month/year)
  - **Examples:**
    - `17/Jun/26` (June 17, 2026)
    - `5/Jan/27` (January 5, 2027)
    - `25/Dec/26` (December 25, 2026)
  - **Month abbreviations:** Jan, Feb, Mar, Apr, May, Jun, Jul, Aug, Sep, Oct, Nov, Dec

### Examples

**Linux/Mac:**
```bash
# Full format
python scripts/fetch_jenkins_artifacts.py --build-number 123 --due-date "17/Jun/26"

# Short format
python scripts/fetch_jenkins_artifacts.py -b 456 -d "20/Dec/26"

# More examples with different dates
python scripts/fetch_jenkins_artifacts.py -b 789 -d "5/Jan/27"
python scripts/fetch_jenkins_artifacts.py -b 100 -d "25/Mar/26"
```

**Windows (PowerShell):**
```powershell
# Full format
python scripts/fetch_jenkins_artifacts.py --build-number 123 --due-date "17/Jun/26"

# Short format
python scripts/fetch_jenkins_artifacts.py -b 456 -d "20/Dec/26"
```

**Windows (Command Prompt):**
```cmd
# Full format
python scripts/fetch_jenkins_artifacts.py --build-number 123 --due-date "17/Jun/26"

# Short format
python scripts/fetch_jenkins_artifacts.py -b 456 -d "20/Dec/26"
```

**Date Format Notes:**
- Always use 3-letter month abbreviations (Jan, Feb, Mar, Apr, May, Jun, Jul, Aug, Sep, Oct, Nov, Dec)
- Day can be 1 or 2 digits (5 or 05 both work)
- Year should be 2 digits (26 for 2026, 27 for 2027)
- Always enclose the date in quotes

---

## Workflow Details

### Step 1: Fetch Artifacts from Jenkins
The script connects to Jenkins using the provided credentials and downloads all artifacts from the specified build number.

**Artifacts are saved to:** `jenkins_artifacts/` directory

### Step 2: Parse test-summary.txt
The script looks for `test-summary.txt` in the downloaded artifacts and parses it to extract:

- **ODF Build Version** (e.g., `4.20.14-6`)
- **ODF Version** (e.g., `4.20`)
- **Summary** (e.g., `ODF 4.20.14`)
- **Test Result Sections** (all headers and their content)

#### Expected test-summary.txt Format

```
========================================
ODF Build: 4.20.14-6 - Status Before Upgrade
========================================
Some content here...

========================================
ODF Build: 4.20.14-6 - Status After Upgrade
========================================
Some content here...

========================================
ODF Build: 4.20.14-6 - Tier 1 Summary
========================================
Some content here...

... (more sections)
```

**Supported Headers:**
- Status Before Upgrade
- Status After Upgrade
- Tier 1 Summary
- Build Info (After Tier 1)
- CRC Log (After Tier 1)
- Tier 4a Summary
- Build Info (After Tier 4a)
- CRC Log (After Tier 4a)
- Execution Summary (Rerun Summary)

**Note:** Not all headers need to be present. The script handles missing sections gracefully.

### Step 3: Update subtask_config.json
The script updates (or creates) `subtask_config.json` with:

```json
{
  "odf_version": "4.20",
  "summary": "ODF 4.20.14",
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
ODF Build: 4.20.14-6 - Status Before Upgrade
========================================
Some content here...
{code}
```

This creates **up to 9 comments** (one per section found in test-summary.txt).

### Step 6: Upload Attachment
The complete `test-summary.txt` file is uploaded as an attachment to the JIRA subtask.

### Step 7: Cleanup
The `jenkins_artifacts/` directory and all downloaded files are deleted to save disk space.

---

## Output Example

```
============================================================
Fetching artifacts from Jenkins build #123
============================================================
✓ Found 3 artifact(s)
  Downloading: test-summary.txt... ✓ Saved to jenkins_artifacts/test-summary.txt
  Downloading: build-log.txt... ✓ Saved to jenkins_artifacts/build-log.txt
  Downloading: results.xml... ✓ Saved to jenkins_artifacts/results.xml

============================================================
Parsing test-summary.txt
============================================================
✓ ODF Build: 4.20.14-6
✓ ODF Version: 4.20
✓ Summary: ODF 4.20.14
✓ Found 9 section(s)

============================================================
Updating subtask_config.json
============================================================
✓ Updated subtask_config.json:
  - odf_version: 4.20
  - summary: ODF 4.20.14
  - due_date: 17/Jun/26

============================================================
Creating JIRA subtask
============================================================
✓ Connected to Jira: https://your-jira-instance.atlassian.net
✓ ODF Version 4.20 → Parent Issue: CSOP-546
✓ Found parent issue: CSOP-546 - ODF 4.20 Testing
✓ Subtask created successfully: CSOP-1234

============================================================
Adding comments to JIRA subtask CSOP-1234
============================================================
  Adding comment 1/9: ODF Build: 4.20.14-6 - Status Before Upgrade...
  ✓ Comment added
  Adding comment 2/9: ODF Build: 4.20.14-6 - Status After Upgrade...
  ✓ Comment added
  ... (7 more comments)
✓ Added 9 comment(s) to CSOP-1234

============================================================
Uploading attachment to JIRA subtask CSOP-1234
============================================================
✓ Uploaded test-summary.txt to CSOP-1234

============================================================
Cleaning up artifacts
============================================================
✓ Deleted jenkins_artifacts

============================================================
✓ Process completed successfully!
============================================================
JIRA Subtask: CSOP-1234
URL: https://your-jira-instance.atlassian.net/browse/CSOP-1234
============================================================
```

---

## Troubleshooting

### Error: "Missing Jenkins credentials"
**Solution:** Ensure your `.env` file contains `JENKINS_URL`, `JENKINS_USER`, and `JENKINS_API_TOKEN`.

### Error: "Missing JIRA credentials"
**Solution:** Ensure your `.env` file contains `JIRA_SERVER`, `JIRA_EMAIL`, and `JIRA_API_TOKEN`.

### Error: "Failed to connect to Jira"
**Solutions:**
- Verify JIRA server URL is correct
- Check if JIRA API token is valid
- Ensure your JIRA email is correct
- Check network connectivity

### Error: "Failed to fetch artifacts from Jenkins"
**Solutions:**
- Verify Jenkins URL is correct
- Check if build number exists
- Ensure Jenkins API token is valid
- Check network connectivity
- Verify you have permissions to access the Jenkins job

### Error: "SSL: CERTIFICATE_VERIFY_FAILED" or "self-signed certificate"
**Solution:** The script automatically handles self-signed certificates by disabling SSL verification. This is normal for internal Jenkins servers. The warning is suppressed automatically.

**Note:** SSL verification is disabled for Jenkins connections to support self-signed certificates commonly used in internal/corporate environments.

### Error: "test-summary.txt not found in artifacts"
**Solutions:**
- Verify the build has completed successfully
- Check if the build actually generated test-summary.txt
- Ensure the artifact name is exactly "test-summary.txt"

### Error: "Could not extract ODF Build version"
**Solutions:**
- Verify test-summary.txt has the correct format
- Check if headers contain "ODF Build: X.Y.Z-N" pattern
- Ensure the file is not corrupted

### Error: "Unknown ODF version"
**Solutions:**
- Check if `odf_version_mapping.json` exists
- Verify the ODF version is mapped in the file
- Add the version mapping if missing

### Warning: "Subtask with summary already exists"
**Behavior:** The script will use the existing subtask instead of creating a new one. Comments and attachments will still be added.

---

## Platform-Specific Notes

### Windows
- Use PowerShell or Command Prompt
- Paths use backslashes (`\`) but Python handles this automatically
- The script creates `jenkins_artifacts\` directory

### Linux/Mac
- Use Terminal or Bash
- Paths use forward slashes (`/`)
- The script creates `jenkins_artifacts/` directory
- Ensure Python 3 is available as `python` or `python3`

---

## File Structure

```
project-root/
├── scripts/
│   ├── fetch_jenkins_artifacts.py    # Main script
│   ├── create_jira_subtask.py        # JIRA subtask creation
│   └── test_gdrive_connection.py     # Google Drive test script
├── examples/
│   ├── .env.example                  # Credentials template
│   ├── subtask_config.json.example   # JIRA config template
│   └── odf_version_mapping.json.example  # Version mapping template
├── setup/
│   ├── setup_python_env.ps1          # Windows setup script
│   ├── setup_python_env.sh           # Linux setup script
│   └── activate_venv_bypass.bat      # Windows activation helper
├── subtask_config.json           # JIRA configuration (auto-updated)
├── odf_version_mapping.json      # ODF version to parent mapping
├── .env                          # Credentials (DO NOT COMMIT)
├── requirements.txt              # Python dependencies
├── jenkins_artifacts/            # Temporary (auto-deleted)
│   └── test-summary.txt
└── docs/
    └── JENKINS_ARTIFACT_FETCHER_GUIDE.md  # This file
```

---

## Security Best Practices

1. **Never commit `.env` file** - It contains sensitive credentials
2. **Use API tokens** - Never use passwords directly
3. **Rotate tokens regularly** - Change API tokens periodically
4. **Limit token permissions** - Use tokens with minimal required permissions
5. **Keep tokens secure** - Don't share tokens via email or chat

---

## Integration with CI/CD

This script can be integrated into CI/CD pipelines:

### Jenkins Pipeline Example
```groovy
stage('Create JIRA Subtask') {
    steps {
        script {
            sh """
                python scripts/fetch_jenkins_artifacts.py \
                    --build-number ${BUILD_NUMBER} \
                    --due-date "17/Jun/26"
            """
        }
    }
}
```

### GitHub Actions Example
```yaml
- name: Create JIRA Subtask
  run: |
    python scripts/fetch_jenkins_artifacts.py \
      --build-number ${{ github.run_number }} \
      --due-date "17/Jun/26"
  env:
    JENKINS_URL: ${{ secrets.JENKINS_URL }}
    JENKINS_USER: ${{ secrets.JENKINS_USER }}
    JENKINS_API_TOKEN: ${{ secrets.JENKINS_API_TOKEN }}
    JIRA_SERVER: ${{ secrets.JIRA_SERVER }}
    JIRA_EMAIL: ${{ secrets.JIRA_EMAIL }}
    JIRA_API_TOKEN: ${{ secrets.JIRA_API_TOKEN }}
```

---

## Support

For issues or questions:
1. Check this documentation
2. Review error messages carefully
3. Verify all prerequisites are met
4. Check `.env` file configuration
5. Ensure network connectivity to Jenkins and JIRA

---

## Version History

- **v1.0** - Initial release with Jenkins artifact fetching and JIRA integration