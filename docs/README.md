# Documentation

This folder contains all documentation for the ODF Upgrade Repository.

## 📚 Available Guides

### Python Environment Setup
- **[PYTHON_ENV_GUIDE.md](PYTHON_ENV_GUIDE.md)** - Complete guide for setting up Python 3.11 environment on Windows and Linux

### Jira Integration
- **[JIRA_GUIDE.md](JIRA_GUIDE.md)** - Complete guide for creating Jira subtasks with ODF version mapping

## 🚀 Quick Links

### Python Setup
```bash
# Windows
setup\activate_venv_bypass.bat
pip install -r requirements.txt

# Linux
source venv/bin/activate
pip install -r requirements.txt
```

### Jira Subtask Creation
```bash
# Create subtask
python scripts/create_jira_subtask.py

# List ODF versions
python scripts/create_jira_subtask.py --list-versions

# List issue types
python scripts/create_jira_subtask.py --list-issue-types
```

## 📁 Project Structure

```
odf_upgrade_repo/
├── docs/                          # Documentation (this folder)
│   ├── README.md                  # This file
│   ├── PYTHON_ENV_GUIDE.md        # Python setup guide
│   └── JIRA_GUIDE.md              # Jira integration guide
├── scripts/
│   ├── create_jira_subtask.py     # Main Jira script
│   ├── fetch_jenkins_artifacts.py # Jenkins artifact fetcher
│   └── test_gdrive_connection.py  # Google Drive test script
├── examples/
│   ├── .env.example                   # Credentials template
│   ├── subtask_config.json.example    # Configuration template
│   └── odf_version_mapping.json.example  # Version mapping template
├── setup/
│   ├── setup_python_env.ps1           # Windows setup script
│   ├── setup_python_env.sh            # Linux setup script
│   └── activate_venv_bypass.bat       # Windows activation helper
├── odf_version_mapping.json       # ODF version to parent key mapping
├── requirements.txt               # Python dependencies
```

## 🔒 Security

- `.env` - Contains sensitive credentials (NOT in git)
- `subtask_config.json` - May contain personal data (NOT in git)
- Use `.example` files as templates

## 📖 Getting Started

1. **Setup Python Environment**
   - Read: [PYTHON_ENV_GUIDE.md](PYTHON_ENV_GUIDE.md)
   - Run setup scripts

2. **Configure Jira**
   - Read: [JIRA_GUIDE.md](JIRA_GUIDE.md)
   - Copy `examples/.env.example` to `.env`
   - Copy `examples/subtask_config.json.example` to `subtask_config.json`
   - Fill in your credentials and configuration

3. **Start Using**
   - Create Jira subtasks
   - Automate your workflow

## 💡 Need Help?

- Check the specific guide for detailed instructions
- All guides include troubleshooting sections
- Examples are provided for common use cases