# ODF Upgrade Repository

Repository for ODF (OpenShift Data Foundation) upgrade testing and automation.

## 📚 Documentation

All documentation is in the [`docs/`](docs/) folder:
- **[Python Environment Setup](docs/PYTHON_ENV_GUIDE.md)** - Setup Python 3.11 for Windows & Linux
- **[Jira Integration Guide](docs/JIRA_GUIDE.md)** - Create Jira subtasks automatically

## 🚀 Quick Start

### 1. Setup Python Environment

**Windows:**
```cmd
activate_venv_bypass.bat
pip install -r requirements.txt
```

**Linux:**
```bash
source venv/bin/activate
pip install -r requirements.txt
```

### 2. Configure Jira

```bash
# Copy templates
copy .env.example .env                                              # Windows
copy subtask_config.json.example subtask_config.json               # Windows
copy odf_version_mapping.json.example odf_version_mapping.json     # Windows

cp .env.example .env                                                # Linux
cp subtask_config.json.example subtask_config.json                 # Linux
cp odf_version_mapping.json.example odf_version_mapping.json       # Linux

# Edit all three files with your project details
```

### 3. Create Jira Subtask

```bash
python create_jira_subtask.py
```

## 📁 Project Structure

```
odf_upgrade_repo/
├── docs/                          # 📚 All documentation
│   ├── README.md
│   ├── PYTHON_ENV_GUIDE.md
│   └── JIRA_GUIDE.md
├── create_jira_subtask.py         # 🎯 Main Jira automation script
├── odf_version_mapping.json       # 🗺️ ODF version to parent key mapping
├── subtask_config.json.example    # 📝 Configuration template
├── .env.example                   # 🔐 Credentials template
├── requirements.txt               # 📦 Python dependencies
├── setup_python_env.ps1           # 🪟 Windows setup
├── setup_python_env.sh            # 🐧 Linux setup
└── activate_venv_bypass.bat       # ⚡ Quick activation (Windows)
```

## 🔒 Security

**Files NOT in git (sensitive/project-specific data):**
- `.env` - Jira credentials
- `subtask_config.json` - Personal configuration
- `odf_version_mapping.json` - Project-specific version mappings
- `venv/` - Python virtual environment

**Use `.example` files as templates!**

## ✨ Features

### Jira Automation
- ✅ Automatic ODF version to parent key mapping
- ✅ Duplicate detection (prevents creating same subtask twice)
- ✅ Configurable via JSON file
- ✅ Supports all subtask fields (components, labels, due date, etc.)

### Python Environment
- ✅ Python 3.11 support
- ✅ Cross-platform (Windows & Linux)
- ✅ Easy setup scripts
- ✅ Virtual environment isolation

## 📖 Usage Examples

### Create Subtask for ODF 4.18
```json
// subtask_config.json
{
  "odf_version": "4.18",
  "summary": "ODF 4.18.30",
  "description": "Run tier1 and tier4a tests"
}
```

```bash
python create_jira_subtask.py
```

### List Available ODF Versions
```bash
python create_jira_subtask.py --list-versions
```

### List Jira Issue Types
```bash
python create_jira_subtask.py --list-issue-types
```

## 🛠️ Development

### Prerequisites
- Python 3.11
- Jira account with API access
- Jira API token

### Setup
1. Clone repository
2. Setup Python environment (see docs)
3. Configure credentials
4. Start automating!

## 📝 ODF Version Mapping

The script uses `odf_version_mapping.json` to map ODF versions to parent issue keys.

**Setup:**
```bash
# Copy the template
copy odf_version_mapping.json.example odf_version_mapping.json  # Windows
cp odf_version_mapping.json.example odf_version_mapping.json    # Linux

# Edit with your project's version mappings
```

**Example format:**
```json
{
  "4.18": "YOUR-PROJECT-123",
  "4.19": "YOUR-PROJECT-124"
}
```

## 🤝 Contributing

1. Keep sensitive data out of git
2. Update documentation when adding features
3. Test on both Windows and Linux
4. Follow existing code style

## 📄 License

Internal IBM project

## 💡 Need Help?

Check the [documentation](docs/) folder for detailed guides!
