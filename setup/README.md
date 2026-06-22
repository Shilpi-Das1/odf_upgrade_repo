# Python Environment Setup Scripts

This directory contains scripts to set up the Python virtual environment for the ODF upgrade repository.

## Scripts

### 1. `setup_python_env.sh` (Linux/Mac)
Sets up Python virtual environment on Linux/Mac systems.

**Usage:**
```bash
bash setup/setup_python_env.sh
```

### 2. `setup_python_env.ps1` (Windows PowerShell)
Sets up Python virtual environment on Windows systems.

**Usage:**
```powershell
.\setup\setup_python_env.ps1
```

### 3. `activate_venv_bypass.bat` (Windows)
Activates the virtual environment on Windows, bypassing execution policy restrictions.

**Usage:**
```cmd
setup\activate_venv_bypass.bat
```

## What These Scripts Do

1. Check for Python 3.11+ installation
2. Create a virtual environment in `venv/` directory
3. Upgrade pip to the latest version
4. Install all dependencies from `requirements.txt`
5. Verify the installation

## Requirements

- Python 3.11 or higher
- pip (Python package installer)
- Internet connection (for downloading packages)

## After Setup

Once the environment is set up, activate it:

**Linux/Mac:**
```bash
source venv/bin/activate
```

**Windows (PowerShell):**
```powershell
.\venv\Scripts\Activate.ps1
```

**Windows (Command Prompt):**
```cmd
venv\Scripts\activate.bat
```

## Troubleshooting

If you encounter permission issues on Windows:
1. Run PowerShell as Administrator
2. Execute: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`
3. Run the setup script again

For more details, see [docs/PYTHON_ENV_GUIDE.md](../docs/PYTHON_ENV_GUIDE.md)