#!/bin/bash
# Python 3.11 Environment Setup Script for Linux
# This script helps set up Python 3.11 and create a virtual environment

set -e

PYTHON_VERSION="3.11"
VENV_NAME="venv"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

show_help() {
    cat << EOF
Python 3.11 Environment Setup Script for Linux

Usage:
    bash setup_python_env.sh [OPTIONS]

Options:
    --install-python    Check and install Python 3.11
    --create-venv       Create virtual environment with Python 3.11
    --help              Show this help message

Examples:
    bash setup_python_env.sh --install-python
    bash setup_python_env.sh --create-venv
    bash setup_python_env.sh --install-python --create-venv

If no options provided, script will run in interactive mode.
EOF
}

print_header() {
    echo -e "${CYAN}"
    cat << "EOF"
╔════════════════════════════════════════════════════════════╗
║   Python 3.11 Environment Setup for Linux                 ║
║   Project: ODF Upgrade Repository                         ║
╚════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
    elif [ -f /etc/redhat-release ]; then
        OS="rhel"
    else
        OS="unknown"
    fi
    echo -e "${CYAN}Detected OS: ${OS} ${OS_VERSION}${NC}"
}

test_python_installed() {
    echo -e "\n${CYAN}=== Checking for Python 3.11 ===${NC}"
    
    if command -v python3.11 &> /dev/null; then
        PYTHON_VERSION_OUTPUT=$(python3.11 --version)
        echo -e "${GREEN}✓ Python 3.11 found: ${PYTHON_VERSION_OUTPUT}${NC}"
        return 0
    else
        echo -e "${YELLOW}✗ Python 3.11 not found${NC}"
        return 1
    fi
}

install_python_ubuntu_debian() {
    echo -e "\n${CYAN}Installing Python 3.11 on Ubuntu/Debian...${NC}"
    
    # Check if deadsnakes PPA is needed
    if ! apt-cache show python3.11 &> /dev/null; then
        echo -e "${YELLOW}Adding deadsnakes PPA...${NC}"
        sudo add-apt-repository ppa:deadsnakes/ppa -y
    fi
    
    sudo apt update
    sudo apt install -y python3.11 python3.11-venv python3.11-dev python3-pip
    
    echo -e "${GREEN}✓ Python 3.11 installed successfully!${NC}"
}

install_python_rhel_centos() {
    echo -e "\n${CYAN}Installing Python 3.11 on RHEL/CentOS...${NC}"
    
    if command -v dnf &> /dev/null; then
        sudo dnf install -y python3.11 python3.11-devel python3.11-pip
    else
        sudo yum install -y python3.11 python3.11-devel python3.11-pip
    fi
    
    echo -e "${GREEN}✓ Python 3.11 installed successfully!${NC}"
}

install_python_fedora() {
    echo -e "\n${CYAN}Installing Python 3.11 on Fedora...${NC}"
    
    sudo dnf install -y python3.11 python3.11-devel python3.11-pip
    
    echo -e "${GREEN}✓ Python 3.11 installed successfully!${NC}"
}

install_python_from_source() {
    echo -e "\n${CYAN}Installing Python 3.11 from source...${NC}"
    echo -e "${YELLOW}This may take several minutes...${NC}"
    
    # Install build dependencies
    if command -v apt-get &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y build-essential zlib1g-dev libncurses5-dev \
            libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev \
            libsqlite3-dev wget libbz2-dev
    elif command -v yum &> /dev/null; then
        sudo yum groupinstall -y "Development Tools"
        sudo yum install -y zlib-devel bzip2-devel openssl-devel \
            ncurses-devel sqlite-devel readline-devel tk-devel \
            gdbm-devel libffi-devel
    fi
    
    # Download and build Python 3.11
    cd /tmp
    PYTHON_MINOR_VERSION="3.11.9"
    wget https://www.python.org/ftp/python/${PYTHON_MINOR_VERSION}/Python-${PYTHON_MINOR_VERSION}.tgz
    tar -xf Python-${PYTHON_MINOR_VERSION}.tgz
    cd Python-${PYTHON_MINOR_VERSION}
    ./configure --enable-optimizations
    make -j $(nproc)
    sudo make altinstall
    
    cd "$PROJECT_DIR"
    rm -rf /tmp/Python-${PYTHON_MINOR_VERSION}*
    
    echo -e "${GREEN}✓ Python 3.11 installed successfully!${NC}"
}

install_python_guide() {
    echo -e "\n${CYAN}=== Python 3.11 Installation Guide ===${NC}"
    
    if test_python_installed; then
        echo -e "\n${GREEN}Python 3.11 is already installed!${NC}"
        return 0
    fi
    
    detect_os
    
    echo -e "\n${YELLOW}Python 3.11 is not installed. Installation options:${NC}"
    echo "1. Install via package manager (recommended)"
    echo "2. Install from source (if package not available)"
    echo "3. Skip installation"
    
    read -p "Enter your choice (1-3): " choice
    
    case $choice in
        1)
            case $OS in
                ubuntu|debian)
                    install_python_ubuntu_debian
                    ;;
                rhel|centos)
                    install_python_rhel_centos
                    ;;
                fedora)
                    install_python_fedora
                    ;;
                *)
                    echo -e "${YELLOW}Unsupported OS for automatic installation.${NC}"
                    echo -e "${YELLOW}Please install Python 3.11 manually or choose option 2.${NC}"
                    return 1
                    ;;
            esac
            ;;
        2)
            install_python_from_source
            ;;
        3)
            echo -e "${YELLOW}Skipping installation...${NC}"
            return 1
            ;;
        *)
            echo -e "${RED}Invalid choice. Exiting...${NC}"
            return 1
            ;;
    esac
    
    # Verify installation
    if test_python_installed; then
        return 0
    else
        echo -e "${RED}✗ Installation verification failed${NC}"
        return 1
    fi
}

create_virtual_environment() {
    echo -e "\n${CYAN}=== Creating Virtual Environment ===${NC}"
    
    if ! test_python_installed; then
        echo -e "${RED}✗ Python 3.11 is not installed. Please install it first.${NC}"
        echo -e "${YELLOW}Run: bash setup_python_env.sh --install-python${NC}"
        return 1
    fi
    
    VENV_PATH="${PROJECT_DIR}/${VENV_NAME}"
    
    if [ -d "$VENV_PATH" ]; then
        echo -e "${YELLOW}Virtual environment already exists at: ${VENV_PATH}${NC}"
        read -p "Do you want to recreate it? (y/n): " choice
        if [ "$choice" != "y" ] && [ "$choice" != "Y" ]; then
            echo -e "${GREEN}Keeping existing virtual environment.${NC}"
            return 0
        fi
        echo -e "${YELLOW}Removing existing virtual environment...${NC}"
        rm -rf "$VENV_PATH"
    fi
    
    echo -e "${CYAN}Creating virtual environment with Python 3.11...${NC}"
    
    if python3.11 -m venv "$VENV_PATH"; then
        echo -e "${GREEN}✓ Virtual environment created successfully!${NC}"
        
        echo -e "\n${CYAN}To activate the virtual environment, run:${NC}"
        echo -e "  ${GREEN}source venv/bin/activate${NC}"
        
        # Check if requirements.txt exists
        if [ -f "${PROJECT_DIR}/requirements.txt" ]; then
            echo -e "\n${CYAN}Found requirements.txt. After activating the environment, install dependencies with:${NC}"
            echo -e "  ${GREEN}pip install -r requirements.txt${NC}"
        fi
        
        return 0
    else
        echo -e "${RED}✗ Failed to create virtual environment${NC}"
        return 1
    fi
}

show_environment_info() {
    echo -e "\n${CYAN}=== Environment Information ===${NC}"
    
    echo -e "\nProject Directory: ${PROJECT_DIR}"
    echo -e "Virtual Environment: ${VENV_NAME}"
    
    if [ -d "${PROJECT_DIR}/${VENV_NAME}" ]; then
        echo -e "Virtual Environment Status: ${GREEN}✓ Exists${NC}"
    else
        echo -e "Virtual Environment Status: ${YELLOW}✗ Not created${NC}"
    fi
    
    echo -e "\n${CYAN}System Python Versions:${NC}"
    for py_cmd in python python3 python3.11; do
        if command -v $py_cmd &> /dev/null; then
            echo -e "  $py_cmd: $($py_cmd --version 2>&1)"
        fi
    done
}

# Main execution
print_header

INSTALL_PYTHON=false
CREATE_VENV=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --install-python)
            INSTALL_PYTHON=true
            shift
            ;;
        --create-venv)
            CREATE_VENV=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

if [ "$INSTALL_PYTHON" = false ] && [ "$CREATE_VENV" = false ]; then
    # Interactive mode
    echo -e "\n${YELLOW}Running in interactive mode...${NC}"
    show_environment_info
    
    echo -e "\n${CYAN}What would you like to do?${NC}"
    echo "1. Check/Install Python 3.11"
    echo "2. Create Virtual Environment"
    echo "3. Both"
    echo "4. Exit"
    
    read -p "Enter your choice (1-4): " choice
    
    case $choice in
        1)
            install_python_guide
            ;;
        2)
            create_virtual_environment
            ;;
        3)
            if install_python_guide; then
                create_virtual_environment
            fi
            ;;
        4)
            echo -e "${YELLOW}Exiting...${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice. Exiting...${NC}"
            exit 1
            ;;
    esac
else
    # Command-line mode
    if [ "$INSTALL_PYTHON" = true ]; then
        install_python_guide
    fi
    
    if [ "$CREATE_VENV" = true ]; then
        create_virtual_environment
    fi
fi

echo -e "\n${GREEN}=== Setup Complete ===${NC}"
echo -e "${CYAN}For more information, see PYTHON_SETUP.md${NC}"

# Made with Bob
