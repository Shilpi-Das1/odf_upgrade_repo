# Python Scripts

This directory contains all Python automation scripts for the ODF upgrade repository.

## Scripts

### 1. `create_jira_subtask.py`
Creates JIRA subtasks for ODF testing based on configuration files.

**Usage:**
```bash
python scripts/create_jira_subtask.py
python scripts/create_jira_subtask.py --config my_config.json
python scripts/create_jira_subtask.py --list-versions
```

**Documentation:** See [docs/JIRA_GUIDE.md](../docs/JIRA_GUIDE.md)

### 2. `fetch_jenkins_artifacts.py`
Fetches artifacts from Jenkins builds, parses test results, creates JIRA subtasks, and uploads to Google Drive.

**Usage:**
```bash
python scripts/fetch_jenkins_artifacts.py --build-number 123
python scripts/fetch_jenkins_artifacts.py --build-number 123 --due-date "17/Jun/26"
python scripts/fetch_jenkins_artifacts.py -b 456 -d "20/Dec/26" --resume
```

**Documentation:** See [docs/JENKINS_ARTIFACT_FETCHER_GUIDE.md](../docs/JENKINS_ARTIFACT_FETCHER_GUIDE.md)

### 3. `fetch_bastion_artifacts.py`
Fetches artifacts from a bastion machine via SSH/SCP, parses test results, and creates JIRA subtasks.

**Usage:**
```bash
python scripts/fetch_bastion_artifacts.py --ip 192.168.1.100
python scripts/fetch_bastion_artifacts.py --ip 192.168.1.100 --due-date "17/Jun/26"
python scripts/fetch_bastion_artifacts.py --ip 192.168.1.100 --key-file ~/.ssh/id_rsa --resume
```

**Documentation:** See [docs/BASTION_ARTIFACT_FETCHER_GUIDE.md](../docs/BASTION_ARTIFACT_FETCHER_GUIDE.md)

### 4. `jira_utils.py`
Shared utility module for JIRA operations used by fetch_jenkins_artifacts.py and fetch_bastion_artifacts.py.

**Features:**
- Parse test-summary.txt files
- Update subtask_config.json
- Create JIRA subtasks
- Add comments to JIRA
- Upload attachments to JIRA

### 5. `test_gdrive_connection.py`
Tests Google Drive API connection and credentials.

**Usage:**
```bash
python scripts/test_gdrive_connection.py
```

## Requirements

All scripts require Python 3.11+ and dependencies from `requirements.txt`:

```bash
pip install -r requirements.txt
```

## Configuration

Scripts use configuration files and environment variables from the project root:
- `.env` - Environment variables (credentials)
- `subtask_config.json` - JIRA subtask configuration
- `odf_version_mapping.json` - ODF version mappings
- `google_drive_service_account_creds.json` - Google Drive credentials (optional)

## Running Scripts

Always run scripts from the project root directory:

```bash
# From project root
python scripts/create_jira_subtask.py
python scripts/fetch_jenkins_artifacts.py --build-number 123
python scripts/test_gdrive_connection.py
```

Do not run scripts from within the scripts directory.