# Python 3.11 Environment Setup Script for Windows
# This script helps set up Python 3.11 and create a virtual environment

param(
    [switch]$InstallPython,
    [switch]$CreateVenv,
    [switch]$Help
)

$PYTHON_VERSION = "3.11"
$VENV_NAME = "venv"
$PROJECT_DIR = $PSScriptRoot

function Show-Help {
    Write-Host @"
Python 3.11 Environment Setup Script for Windows

Usage:
    .\setup_python_env.ps1 [OPTIONS]

Options:
    -InstallPython    Check and guide Python 3.11 installation
    -CreateVenv       Create virtual environment with Python 3.11
    -Help             Show this help message

Examples:
    .\setup_python_env.ps1 -InstallPython
    .\setup_python_env.ps1 -CreateVenv
    .\setup_python_env.ps1 -InstallPython -CreateVenv

If no options provided, script will run in interactive mode.
"@
}

function Test-PythonInstalled {
    Write-Host "`n=== Checking for Python 3.11 ===" -ForegroundColor Cyan
    
    # Check for py launcher with 3.11
    try {
        $pyVersion = & py -3.11 --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Python 3.11 found: $pyVersion" -ForegroundColor Green
            return $true
        }
    } catch {
        Write-Host "✗ Python 3.11 not found via py launcher" -ForegroundColor Yellow
    }
    
    # Check for python3.11 command
    try {
        $python311Version = & python3.11 --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Python 3.11 found: $python311Version" -ForegroundColor Green
            return $true
        }
    } catch {
        Write-Host "✗ Python 3.11 not found via python3.11 command" -ForegroundColor Yellow
    }
    
    # List all available Python versions
    Write-Host "`nAvailable Python versions:" -ForegroundColor Yellow
    try {
        & py -0
    } catch {
        Write-Host "No Python versions found via py launcher" -ForegroundColor Red
    }
    
    return $false
}

function Install-PythonGuide {
    Write-Host "`n=== Python 3.11 Installation Guide ===" -ForegroundColor Cyan
    
    if (Test-PythonInstalled) {
        Write-Host "`nPython 3.11 is already installed!" -ForegroundColor Green
        return
    }
    
    Write-Host "`nPython 3.11 is not installed. Here are your options:" -ForegroundColor Yellow
    Write-Host "`n1. Download from Python.org (Recommended)"
    Write-Host "   - Visit: https://www.python.org/downloads/"
    Write-Host "   - Download Python 3.11.x (latest 3.11 version)"
    Write-Host "   - Run installer and CHECK 'Add Python to PATH'"
    
    Write-Host "`n2. Using Chocolatey (if installed)"
    Write-Host "   Run: choco install python311 -y"
    
    Write-Host "`n3. Using winget (Windows Package Manager)"
    Write-Host "   Run: winget install Python.Python.3.11"
    
    $choice = Read-Host "`nWould you like to open the Python download page? (y/n)"
    if ($choice -eq 'y' -or $choice -eq 'Y') {
        Start-Process "https://www.python.org/downloads/"
        Write-Host "`nOpening browser... Please download and install Python 3.11" -ForegroundColor Green
        Write-Host "After installation, restart PowerShell and run this script again." -ForegroundColor Yellow
    }
}

function New-VirtualEnvironment {
    Write-Host "`n=== Creating Virtual Environment ===" -ForegroundColor Cyan
    
    if (-not (Test-PythonInstalled)) {
        Write-Host "✗ Python 3.11 is not installed. Please install it first." -ForegroundColor Red
        Write-Host "Run: .\setup_python_env.ps1 -InstallPython" -ForegroundColor Yellow
        return
    }
    
    $venvPath = Join-Path $PROJECT_DIR $VENV_NAME
    
    if (Test-Path $venvPath) {
        Write-Host "Virtual environment already exists at: $venvPath" -ForegroundColor Yellow
        $choice = Read-Host "Do you want to recreate it? (y/n)"
        if ($choice -ne 'y' -and $choice -ne 'Y') {
            Write-Host "Keeping existing virtual environment." -ForegroundColor Green
            return
        }
        Write-Host "Removing existing virtual environment..." -ForegroundColor Yellow
        Remove-Item -Recurse -Force $venvPath
    }
    
    Write-Host "Creating virtual environment with Python 3.11..." -ForegroundColor Cyan
    
    try {
        # Try py launcher first
        & py -3.11 -m venv $venvPath
        if ($LASTEXITCODE -ne 0) {
            throw "py launcher failed"
        }
    } catch {
        try {
            # Fallback to python3.11 command
            & python3.11 -m venv $venvPath
            if ($LASTEXITCODE -ne 0) {
                throw "python3.11 command failed"
            }
        } catch {
            Write-Host "✗ Failed to create virtual environment" -ForegroundColor Red
            Write-Host "Error: $_" -ForegroundColor Red
            return
        }
    }
    
    Write-Host "✓ Virtual environment created successfully!" -ForegroundColor Green
    Write-Host "`nTo activate the virtual environment, run:" -ForegroundColor Cyan
    Write-Host "  .\venv\Scripts\Activate.ps1" -ForegroundColor White
    
    Write-Host "`nIf you get an execution policy error, run:" -ForegroundColor Yellow
    Write-Host "  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser" -ForegroundColor White
    
    # Check if requirements.txt exists
    $requirementsPath = Join-Path $PROJECT_DIR "requirements.txt"
    if (Test-Path $requirementsPath) {
        Write-Host "`nFound requirements.txt. After activating the environment, install dependencies with:" -ForegroundColor Cyan
        Write-Host "  pip install -r requirements.txt" -ForegroundColor White
    }
}

function Show-EnvironmentInfo {
    Write-Host "`n=== Environment Information ===" -ForegroundColor Cyan
    
    Write-Host "`nProject Directory: $PROJECT_DIR" -ForegroundColor White
    Write-Host "Virtual Environment: $VENV_NAME" -ForegroundColor White
    
    if (Test-Path (Join-Path $PROJECT_DIR $VENV_NAME)) {
        Write-Host "Virtual Environment Status: ✓ Exists" -ForegroundColor Green
    } else {
        Write-Host "Virtual Environment Status: ✗ Not created" -ForegroundColor Yellow
    }
    
    Write-Host "`nSystem Python Versions:" -ForegroundColor White
    try {
        & py -0
    } catch {
        Write-Host "No Python versions found" -ForegroundColor Red
    }
}

# Main execution
Write-Host @"
╔════════════════════════════════════════════════════════════╗
║   Python 3.11 Environment Setup for Windows               ║
║   Project: ODF Upgrade Repository                         ║
╚════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

if ($Help) {
    Show-Help
    exit 0
}

if (-not $InstallPython -and -not $CreateVenv) {
    # Interactive mode
    Write-Host "`nRunning in interactive mode..." -ForegroundColor Yellow
    Show-EnvironmentInfo
    
    Write-Host "`nWhat would you like to do?" -ForegroundColor Cyan
    Write-Host "1. Check/Install Python 3.11"
    Write-Host "2. Create Virtual Environment"
    Write-Host "3. Both"
    Write-Host "4. Exit"
    
    $choice = Read-Host "`nEnter your choice (1-4)"
    
    switch ($choice) {
        "1" { Install-PythonGuide }
        "2" { New-VirtualEnvironment }
        "3" { 
            Install-PythonGuide
            if (Test-PythonInstalled) {
                New-VirtualEnvironment
            }
        }
        "4" { 
            Write-Host "Exiting..." -ForegroundColor Yellow
            exit 0
        }
        default {
            Write-Host "Invalid choice. Exiting..." -ForegroundColor Red
            exit 1
        }
    }
} else {
    # Command-line mode
    if ($InstallPython) {
        Install-PythonGuide
    }
    
    if ($CreateVenv) {
        New-VirtualEnvironment
    }
}

Write-Host "`n=== Setup Complete ===" -ForegroundColor Green
Write-Host "For more information, see PYTHON_SETUP.md" -ForegroundColor Cyan

# Made with Bob
