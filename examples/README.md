# Example Configuration Files

This directory contains example configuration files that you should copy and customize for your environment.

## Files

### 1. `.env.example`
Example environment variables file containing credentials and configuration.

**Setup:**
```bash
# Copy to project root and rename
cp examples/.env.example .env

# Edit with your actual credentials
nano .env  # or use your preferred editor
```

**Contains:**
- Jenkins credentials (URL, username, API token)
- JIRA credentials (server, email, API token)
- Google Drive configuration (optional)

### 2. `subtask_config.json.example`
Example JIRA subtask configuration template.

**Setup:**
```bash
# Copy to project root and rename
cp examples/subtask_config.json.example subtask_config.json

# Edit with your project details
nano subtask_config.json
```

**Contains:**
- Parent issue key
- Subtask summary and description
- ODF version
- Due date
- Labels and other JIRA fields

### 3. `odf_version_mapping.json.example`
Example mapping of ODF versions to parent JIRA issue keys.

**Setup:**
```bash
# Copy to project root and rename
cp examples/odf_version_mapping.json.example odf_version_mapping.json

# Edit with your version mappings
nano odf_version_mapping.json
```

**Contains:**
- Mapping of ODF versions (e.g., "4.14", "4.15") to parent JIRA issue keys
- Used by scripts to automatically determine parent issues

## Important Notes

⚠️ **Never commit actual configuration files to git!**

The following files are in `.gitignore` and should NOT be committed:
- `.env` (contains sensitive credentials)
- `subtask_config.json` (may contain project-specific data)
- `odf_version_mapping.json` (may contain project-specific data)
- `google_drive_service_account_creds.json` (contains sensitive credentials)

## Quick Setup

Run these commands from the project root to set up all configuration files:

```bash
# Copy all example files
cp examples/.env.example .env
cp examples/subtask_config.json.example subtask_config.json
cp examples/odf_version_mapping.json.example odf_version_mapping.json

# Edit each file with your actual values
# Use your preferred text editor (nano, vim, code, etc.)
```

## Documentation

For detailed setup instructions, see:
- [docs/JIRA_GUIDE.md](../docs/JIRA_GUIDE.md) - JIRA configuration
- [docs/JENKINS_ARTIFACT_FETCHER_GUIDE.md](../docs/JENKINS_ARTIFACT_FETCHER_GUIDE.md) - Jenkins and Google Drive setup
- [docs/PYTHON_ENV_GUIDE.md](../docs/PYTHON_ENV_GUIDE.md) - Python environment setup