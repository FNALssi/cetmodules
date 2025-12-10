#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- OS Detection ---
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [[ "$ID" == "ubuntu" ]]; then
        PACKAGE_MANAGER="apt-get"
        BUILD_DEPS="build-essential"
    elif [[ "$ID" == "almalinux" ]]; then
        PACKAGE_MANAGER="dnf"
        BUILD_DEPS="gcc-c++"
    else
        echo "Unsupported operating system: $ID"
        exit 1
    fi
else
    echo "/etc/os-release not found. Cannot determine operating system."
    exit 1
fi

# --- System Dependency Installation ---
echo "Updating package lists..."
sudo $PACKAGE_MANAGER update -y

echo "Installing system dependencies..."
sudo $PACKAGE_MANAGER install -y git doxygen graphviz python3-venv $BUILD_DEPS

# --- Python Environment Setup ---
echo "Setting up Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

echo "Installing Python packages (CMake, Sphinx, etc.)..."
pip install cmake sphinx sphinxcontrib-moderncmakedomain sphinx-design sphinx-toolbox sphinxcontrib-jquery

# --- Catch2 Installation ---
echo "Cloning and installing Catch2..."
git clone https://github.com/catchorg/Catch2.git
cd Catch2
cmake -S . -B build -DBUILD_TESTING=OFF
sudo cmake --build build --target install
cd ..
rm -rf Catch2

# --- cetmodules Build and Test ---
echo "Cloning, building, and testing cetmodules..."
git clone https://github.com/FNALssi/cetmodules.git
cd cetmodules
cmake -S . -B build -DBUILD_DOCS=ON
cmake --build build
ctest --test-dir build

# --- Documentation Build ---
echo "Building cetmodules documentation..."
cmake --build build --target doc-cetmodules-reference
cd ..

# --- Completion ---
echo ""
echo "----------------------------------------------------"
echo "Development environment setup for cetmodules is complete!"
echo "To activate the Python virtual environment, run:"
echo "source venv/bin/activate"
echo "----------------------------------------------------"
