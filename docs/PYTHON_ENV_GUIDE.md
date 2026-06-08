# Python 3.11 Environment Setup Guide
**Complete guide for Windows and Linux**

---

## 📋 Table of Contents
1. [Quick Start](#quick-start)
2. [Windows Setup](#windows-setup)
3. [Linux Setup](#linux-setup)
4. [Daily Usage](#daily-usage)
5. [Troubleshooting](#troubleshooting)

---

## Quick Start

### Windows
```cmd
# 1. Install Python 3.11 from https://www.python.org/downloads/
# 2. Create virtual environment
py -3.11 -m venv venv

# 3. Activate (easiest method)
activate_venv_bypass.bat

# 4. Install dependencies
python -m pip install --upgrade pip
pip install -r requirements.txt
```

### Linux
```bash
# 1. Install Python 3.11
sudo add-apt-repository ppa:deadsnakes/ppa -y
sudo apt update
sudo apt install -y python3.11 python3.11-venv python3.11-dev

# 2. Create virtual environment
python3.11 -m venv venv

# 3. Activate
source venv/bin/activate

# 4. Install dependencies
python -m pip install --upgrade pip
pip install -r requirements.txt
```

---

## Windows Setup

### Step 1: Install Python 3.11

#### Option A: Download from Python.org (Recommended)
1. Visit: https://www.python.org/downloads/
2. Download Python 3.11.x (latest 3.11 version)
3. Run installer and **CHECK "Add Python 3.11 to PATH"**
4. Click "Install Now"
5. Restart your terminal

#### Option B: Using winget
```powershell
winget install Python.Python.3.11
```

#### Verify Installation
```powershell
py -3.11 --version
# Should show: Python 3.11.x
```

### Step 2: Create Virtual Environment
```powershell
# Navigate to your project directory
cd C:\Users\ShilpiDas\Desktop\Projects\Fork_upgrade_repo\upsteam\odf_upgrade_repo

# Create virtual environment
py -3.11 -m venv venv
```

### Step 3: Activate Virtual Environment

**Method 1: Using Batch File (Easiest - No Permission Issues)**
```cmd
activate_venv_bypass.bat
```

**Method 2: Using CMD**
```cmd
venv\Scripts\activate.bat
```

**Method 3: Using PowerShell (requires one-time setup)**
```powershell
# First time only - run as Administrator:
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Then activate:
.\venv\Scripts\Activate.ps1
```

### Step 4: Install Dependencies
```bash
# Upgrade pip
python -m pip install --upgrade pip

# Install requirements
pip install -r requirements.txt

# Verify
python --version  # Should show Python 3.11.x
pip list
```

---

## Linux Setup

### Step 1: Install Python 3.11

#### Ubuntu/Debian
```bash
# Add repository
sudo add-apt-repository ppa:deadsnakes/ppa -y
sudo apt update

# Install Python 3.11
sudo apt install -y python3.11 python3.11-venv python3.11-dev
```

#### RHEL/CentOS/Fedora
```bash
# Fedora
sudo dnf install -y python3.11 python3.11-devel

# RHEL/CentOS
sudo yum install -y python3.11 python3.11-devel
```

#### Verify Installation
```bash
python3.11 --version
# Should show: Python 3.11.x
```

### Step 2: Create Virtual Environment
```bash
# Navigate to your project directory
cd ~/path/to/odf_upgrade_repo

# Create virtual environment
python3.11 -m venv venv
```

### Step 3: Activate Virtual Environment
```bash
source venv/bin/activate
```

You should see `(venv)` at the start of your prompt.

### Step 4: Install Dependencies
```bash
# Upgrade pip
python -m pip install --upgrade pip

# Install requirements
pip install -r requirements.txt

# Verify
python --version  # Should show Python 3.11.x
pip list
```

---

## Daily Usage

### Activating the Environment

**Windows:**
```cmd
# Easiest method (batch file)
activate_venv_bypass.bat

# Or using CMD
venv\Scripts\activate.bat

# Or using PowerShell (after fixing execution policy)
.\venv\Scripts\Activate.ps1
```

**Linux:**
```bash
source venv/bin/activate
```

### Deactivating the Environment
```bash
deactivate
```

### Common Commands
```bash
# Check Python version
python --version

# Check pip version
pip --version

# Install a package
pip install package-name

# Install specific version
pip install package-name==1.2.3

# List installed packages
pip list

# Save current packages to requirements.txt
pip freeze > requirements.txt

# Install from requirements.txt
pip install -r requirements.txt

# Uninstall a package
pip uninstall package-name

# Search for a package
pip search package-name
```

---

## Troubleshooting

### Windows Issues

**Problem: "py -3.11" command not found**
- **Solution:** Reinstall Python 3.11 and check "Add to PATH" during installation
- Restart your terminal after installation

**Problem: "running scripts is disabled" in PowerShell**
- **Solution 1:** Use `activate_venv_bypass.bat` instead (no permission issues)
- **Solution 2:** Use CMD instead of PowerShell
- **Solution 3:** Fix execution policy (run as Administrator):
  ```powershell
  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
  ```

**Problem: Wrong Python version in virtual environment**
- **Solution:** Delete and recreate:
  ```powershell
  Remove-Item -Recurse -Force venv
  py -3.11 -m venv venv
  ```

**Problem: Multiple Python versions causing confusion**
- **Solution:** Always use `py -3.11` to specifically target Python 3.11
- Check all versions: `py -0`

### Linux Issues

**Problem: "python3.11: command not found"**
- **Solution:** Install Python 3.11 using your package manager
- Verify with: `which python3.11`

**Problem: "No module named venv"**
- **Solution:** Install venv package:
  ```bash
  sudo apt install python3.11-venv  # Ubuntu/Debian
  ```

**Problem: Permission denied errors**
- **Solution:** Use virtual environments (don't modify system Python)
- Don't use `sudo` with pip inside virtual environment

**Problem: Missing development headers**
- **Solution:** Install dev package:
  ```bash
  sudo apt install python3.11-dev  # Ubuntu/Debian
  sudo dnf install python3.11-devel  # Fedora/RHEL
  ```

### General Issues

**Problem: pip install fails with SSL errors**
- **Solution:** Upgrade pip:
  ```bash
  python -m pip install --upgrade pip
  ```

**Problem: Package conflicts**
- **Solution:** Create a fresh virtual environment:
  ```bash
  # Windows
  Remove-Item -Recurse -Force venv
  py -3.11 -m venv venv
  
  # Linux
  rm -rf venv
  python3.11 -m venv venv
  ```

**Problem: How to check if environment is activated?**
- **Solution:** Look for `(venv)` at the start of your command prompt
- Or check: `which python` (Linux) or `where python` (Windows)

---

## Files Reference

### Essential Files
- **PYTHON_ENV_GUIDE.md** (this file) - Complete setup guide
- **requirements.txt** - Python package dependencies
- **activate_venv_bypass.bat** - Windows activation script (no permission issues)

### Automation Scripts (Optional)
- **setup_python_env.ps1** - Windows automated setup
- **setup_python_env.sh** - Linux automated setup

### Helper Scripts (Optional)
- **activate_venv.ps1** - PowerShell activation helper
- **activate_venv.sh** - Linux activation helper

---

## Best Practices

1. **Always use virtual environments** - Never install packages globally
2. **Keep requirements.txt updated** - Run `pip freeze > requirements.txt` after installing packages
3. **Use specific versions** - Pin package versions in requirements.txt for reproducibility
4. **Activate before working** - Always activate the virtual environment before running code
5. **One environment per project** - Don't share virtual environments between projects
6. **Don't commit venv/** - Add `venv/` to `.gitignore`
7. **Document dependencies** - Keep requirements.txt in version control

---

## Quick Reference Card

| Task | Windows | Linux |
|------|---------|-------|
| Install Python 3.11 | Download from python.org | `sudo apt install python3.11` |
| Create venv | `py -3.11 -m venv venv` | `python3.11 -m venv venv` |
| Activate | `activate_venv_bypass.bat` | `source venv/bin/activate` |
| Deactivate | `deactivate` | `deactivate` |
| Install packages | `pip install -r requirements.txt` | `pip install -r requirements.txt` |
| Check Python | `python --version` | `python --version` |
| List packages | `pip list` | `pip list` |

---

## Need More Help?

- Python Official Docs: https://docs.python.org/3.11/
- Virtual Environments Guide: https://docs.python.org/3/tutorial/venv.html
- pip Documentation: https://pip.pypa.io/en/stable/

---

**You're all set! Happy coding! 🎉**