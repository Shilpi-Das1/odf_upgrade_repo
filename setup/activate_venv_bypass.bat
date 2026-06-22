@echo off
REM Alternative activation script that bypasses PowerShell execution policy
REM This is a Windows batch file that activates the Python virtual environment

echo ========================================
echo Python Virtual Environment Activation
echo ========================================
echo.

if not exist "venv\Scripts\activate.bat" (
    echo ERROR: Virtual environment not found!
    echo Please create it first with: py -3.11 -m venv venv
    pause
    exit /b 1
)

echo Activating virtual environment...
call venv\Scripts\activate.bat

echo.
echo Virtual environment activated!
echo.
echo Python version:
python --version
echo.
echo Pip version:
pip --version
echo.
echo To deactivate, type: deactivate
echo.

@REM Made with Bob
