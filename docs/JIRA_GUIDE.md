# Jira Subtask Creation Guide

Complete guide for creating Jira subtasks with automatic ODF version mapping.

---

## 📋 Table of Contents
1. [Quick Start](#quick-start)
2. [Setup](#setup)
3. [Configuration](#configuration)
4. [Usage](#usage)
5. [ODF Version Mapping](#odf-version-mapping)
6. [Examples](#examples)
7. [Troubleshooting](#troubleshooting)

---

## Quick Start

### 1. Setup (One-time)

**Install dependencies:**
```bash
pip install -r requirements.txt
```

**Configure credentials:**
```bash
# Copy template
copy .env.example .env  # Windows
cp .env.example .env    # Linux

# Edit .env with your details:
# - JIRA_SERVER (e.g., https://your-company.atlassian.net)
# - JIRA_EMAIL (your Jira email)
# - JIRA_API_TOKEN (get from https://id.atlassian.com/manage-profile/security/api-tokens)
# - JIRA_PROJECT_KEY (e.g., CSOP)
```

### 2. Copy Template Files (First Time Only)

```bash
# Windows
copy subtask_config.json.example subtask_config.json
copy odf_version_mapping.json.example odf_version_mapping.json

# Linux
cp subtask_config.json.example subtask_config.json
cp odf_version_mapping.json.example odf_version_mapping.json
```

### 3. Configure Version Mapping

**Edit `odf_version_mapping.json` with your project's mappings:**
```json
{
  "4.16": "YOUR-PROJECT-457",
  "4.17": "YOUR-PROJECT-514",
  "4.18": "YOUR-PROJECT-546"
}
```

### 4. Create Subtask

**Edit `subtask_config.json`:**
```json
{
  "odf_version": "4.16",
  "summary": "ODF 4.16.25",
  "description": "Run tier1 and tier4a",
  "components": ["Bug"],
  "labels": ["odf"],
  "due_date": "17/Jun/26",
  "fix_versions": ["ODF v4.x.z"]
}
```

**Run:**
```bash
python create_jira_subtask.py
```

Done! ✅

---

## Setup

### Prerequisites
- Python 3.11 environment activated
- Jira account with API access
- Jira API token (get from: https://id.atlassian.com/manage-profile/security/api-tokens)

### Installation Steps

See [Quick Start](#quick-start) section above for complete setup instructions.

**Summary:**
1. Activate virtual environment
2. Install dependencies: `pip install -r requirements.txt`
3. Copy template files (.env, subtask_config.json, odf_version_mapping.json)
4. Configure all three files with your project details
5. Run: `python create_jira_subtask.py`

---

## Configuration

### Configuration File Format

**Method 1: Using ODF Version (Recommended)**
```json
{
  "odf_version": "4.18",
  "summary": "Task title",
  "description": "Task description",
  "components": ["Backend", "API"],
  "reporter": "user@example.com",
  "labels": ["bug", "urgent"],
  "due_date": "15/Jan/26",
  "fix_versions": ["v4.18.0"]
}
```

**Method 2: Using Manual Parent Key**
```json
{
  "parent_key": "CSOP-546",
  "summary": "Task title",
  "description": "Task description"
}
```

### Field Reference

| Field | Type | Required | Description | Example |
|-------|------|----------|-------------|---------|
| `odf_version` | string | ✅* | ODF version (4.14-4.21) | `"4.18"` |
| `parent_key` | string | ✅* | Manual parent key | `"CSOP-546"` |
| `summary` | string | ✅ | Subtask title | `"Fix login bug"` |
| `description` | string | ✅ | Detailed description | `"Users cannot..."` |
| `components` | array | ❌ | Component names | `["Backend"]` |
| `reporter` | string | ❌ | Reporter email | `"user@example.com"` |
| `labels` | array | ❌ | Labels | `["bug", "urgent"]` |
| `due_date` | string | ❌ | Date (d/MMM/yy) | `"15/Jan/26"` |
| `fix_versions` | array | ❌ | Version names | `["v4.18.0"]` |

*Either `odf_version` OR `parent_key` is required (not both)

---

## Usage

### Basic Commands

```bash
# Create subtask with default config
python create_jira_subtask.py

# Use custom config file
python create_jira_subtask.py --config my_config.json

# List available ODF versions
python create_jira_subtask.py --list-versions

# Show help
python create_jira_subtask.py --help
```

---

## ODF Version Mapping

The script uses `odf_version_mapping.json` to automatically map ODF versions to parent issue keys.

**Setup:**
```bash
# Copy the template
copy odf_version_mapping.json.example odf_version_mapping.json  # Windows
cp odf_version_mapping.json.example odf_version_mapping.json    # Linux

# Edit with your project's mappings
```

**Example format:**
```json
{
  "4.14": "YOUR-PROJECT-123",
  "4.15": "YOUR-PROJECT-124",
  "4.16": "YOUR-PROJECT-125"
}
```

**To add new versions:** Edit `odf_version_mapping.json` and add new entries

---

## Examples

### Example 1: Bug Fix for ODF 4.18

**File: `bug_4.18.json`**
```json
{
  "odf_version": "4.18",
  "summary": "Fix timeout in storage provisioning",
  "description": "Storage provisioning times out after 5 minutes. Increase timeout to 10 minutes and add retry logic.",
  "components": ["Storage", "Backend"],
  "labels": ["bug", "critical"],
  "due_date": "20/Jan/26",
  "fix_versions": ["v4.18.1"]
}
```

**Run:**
```bash
python create_jira_subtask.py --config bug_4.18.json
```

**Result:** Creates subtask under CSOP-546 (ODF 4.18 parent)

---

### Example 2: Feature for ODF 4.19

**File: `feature_4.19.json`**
```json
{
  "odf_version": "4.19",
  "summary": "Add support for encrypted storage class",
  "description": "Implement RBD storage class with encryption support:\n- Add encryption configuration\n- Update API endpoints\n- Add documentation",
  "components": ["Storage", "API", "Documentation"],
  "labels": ["feature", "enhancement"],
  "due_date": "1/Feb/26",
  "fix_versions": ["v4.19.0"]
}
```

**Run:**
```bash
python create_jira_subtask.py --config feature_4.19.json
```

**Result:** Creates subtask under CSOP-665 (ODF 4.19 parent)

---

### Example 3: Using Manual Parent Key

**File: `custom_task.json`**
```json
{
  "parent_key": "CSOP-900",
  "summary": "Update API documentation",
  "description": "Update REST API documentation for new endpoints",
  "components": ["Documentation"],
  "labels": ["documentation"]
}
```

**Run:**
```bash
python create_jira_subtask.py --config custom_task.json
```

---

### Example 4: Minimal Configuration

**File: `minimal.json`**
```json
{
  "odf_version": "4.18",
  "summary": "Quick task",
  "description": "Simple task description"
}
```

---

## Troubleshooting

### Error: "Missing Jira credentials"
**Solution:** Check `.env` file has all required fields:
- JIRA_SERVER
- JIRA_EMAIL
- JIRA_API_TOKEN

### Error: "Failed to connect to Jira"
**Solutions:**
1. Verify Jira server URL (include https://)
2. Check API token is correct
3. Ensure email matches Jira account
4. Test internet connection

### Error: "Unknown ODF version"
**Solution:** Check available versions:
```bash
python create_jira_subtask.py --list-versions
```

### Error: "Parent issue not found"
**Solutions:**
1. Verify parent key is correct
2. Check you have permission to view the issue
3. Ensure issue exists in Jira

### Error: "Configuration file not found"
**Solution:** Check file path and name:
```bash
# Windows
dir subtask_config.json

# Linux
ls -la subtask_config.json
```

### Error: "Invalid JSON"
**Solution:** Validate JSON syntax:
```bash
python -m json.tool subtask_config.json
```

Common JSON issues:
- Missing commas between fields
- Trailing commas (not allowed)
- Single quotes instead of double quotes
- Unquoted strings

### Warning: "Reporter not found"
**Solution:** Use exact email or username from Jira

### Warning: "Invalid date format"
**Solution:** Use format d/MMM/yy
- Correct: `"15/Jan/26"`, `"1/Dec/25"`
- Wrong: `"2026-01-15"`, `"Jan 15, 2026"`

---

## Best Practices

### 1. Organize by ODF Version
```
configs/
├── odf_4.18/
│   ├── bug_fix_1.json
│   └── feature_1.json
├── odf_4.19/
│   └── enhancement_1.json
└── odf_4.21/
    └── upgrade_task.json
```

### 2. Use Descriptive Filenames
```
bug_4.18_storage_timeout.json
feature_4.19_encryption.json
doc_4.21_installation.json
```

### 3. Create Templates
```bash
cp subtask_config.json templates/bug_template.json
cp subtask_config.json templates/feature_template.json
```

### 4. Version Control
Add configs to git (but NOT .env):
```bash
git add subtask_config.json
git add configs/*.json
git commit -m "Add subtask configurations"
```

### 5. Validate Before Running
```bash
python -m json.tool subtask_config.json
```

---

## Files Reference

### Essential Files
- **create_jira_subtask.py** - Main script
- **subtask_config.json** - Default configuration
- **odf_version_mapping.json** - ODF version to parent key mapping
- **.env** - Your credentials (DO NOT COMMIT)
- **.env.example** - Template for credentials
- **JIRA_GUIDE.md** - This guide

### Supporting Files
- **requirements.txt** - Python dependencies
- **.gitignore** - Protects sensitive files

---

## Security Notes

1. **Never commit `.env`** - Contains sensitive API tokens
2. **Keep tokens secure** - Treat like passwords
3. **Rotate tokens regularly** - Generate new tokens periodically
4. **Use project-specific tokens** - When possible
5. **Check `.gitignore`** - Ensure `.env` is excluded

---

## Quick Reference Card

| Task | Command |
|------|---------|
| Create subtask | `python create_jira_subtask.py` |
| Custom config | `python create_jira_subtask.py --config file.json` |
| List versions | `python create_jira_subtask.py --list-versions` |
| Show help | `python create_jira_subtask.py --help` |
| Validate JSON | `python -m json.tool config.json` |

**Minimal config:**
```json
{
  "odf_version": "4.18",
  "summary": "Title",
  "description": "Description"
}
```

---

## Additional Resources

- Python Setup: See `PYTHON_ENV_GUIDE.md`
- Jira API Docs: https://developer.atlassian.com/cloud/jira/platform/rest/v3/
- Get API Token: https://id.atlassian.com/manage-profile/security/api-tokens

---

**Happy automating! 🚀**