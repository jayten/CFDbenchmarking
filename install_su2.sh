#!/bin/bash
#
# SU2 with MPICH Installation Script
# -----------------------------------
# This script installs a specific version of SU2 CFD software with a specific MPICH version
# Compatible with both Linux (Ubuntu/Debian) and MacOS
#
# Usage: ./install_su2.sh
#

# Exit on error
set -e

# Configuration variables
MPICH_VERSION="4.0.3"
INSTALL_DIR="$HOME/su2_install"
MPICH_INSTALL_DIR="$INSTALL_DIR/mpich"
SU2_INSTALL_DIR="$INSTALL_DIR/SU2"
NUM_CORES=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)

# Print script header
echo "============================================="
echo "SU2 Installation Script with MPICH $MPICH_VERSION"
echo "============================================="
echo "Installation directories:"
echo "  MPICH: $MPICH_INSTALL_DIR"
echo "  SU2:   $SU2_INSTALL_DIR"
echo "Using $NUM_CORES cores for compilation"
echo "============================================="

# Create installation directory
mkdir -p "$INSTALL_DIR"

# Detect OS
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS_TYPE="linux"
    echo "Detected Linux operating system"
    
    # Install dependencies for Linux
    echo "Installing dependencies..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y build-essential make gfortran wget git python3-pip python3-dev
    elif command -v yum &> /dev/null; then
        sudo yum -y update
        sudo yum -y groupinstall "Development Tools"
        sudo yum -y install gcc gcc-c++ gcc-gfortran make wget git python3-pip python3-devel
    else
        echo "Error: Unsupported package manager. Please install the required dependencies manually."
        exit 1
    fi
    
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS_TYPE="macos"
    echo "Detected MacOS operating system"
    
    # Check if Homebrew is installed
    if ! command -v brew &> /dev/null; then
        echo "Homebrew not found. Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    
    # Install dependencies for MacOS
    echo "Installing dependencies..."
    brew install gcc make wget git python3
else
    echo "Error: Unsupported operating system: $OSTYPE"
    exit 1
fi

# Install Python dependencies
echo "Installing Python dependencies..."
pip3 install --user meson ninja

# Install MPICH
echo "============================================="
echo "Installing MPICH $MPICH_VERSION..."
echo "============================================="
cd "$INSTALL_DIR"
wget -nc "https://www.mpich.org/static/downloads/$MPICH_VERSION/mpich-$MPICH_VERSION.tar.gz"
tar -xf "mpich-$MPICH_VERSION.tar.gz"
cd "mpich-$MPICH_VERSION"

# Configure and install MPICH
./configure --prefix="$MPICH_INSTALL_DIR"
make -j "$NUM_CORES"
make install
cd "$INSTALL_DIR"

# Add MPICH binaries to the PATH temporarily for building SU2
export PATH="$MPICH_INSTALL_DIR/bin:$PATH"

# Install SU2
echo "============================================="
echo "Installing SU2..."
echo "============================================="
cd "$INSTALL_DIR"
if [ ! -d "SU2" ]; then
    git clone https://github.com/su2code/SU2.git
fi
cd SU2

# Setup environment variables for compilation
export CC="$MPICH_INSTALL_DIR/bin/mpicc"
export CXX="$MPICH_INSTALL_DIR/bin/mpicxx"

# Use Python to run meson.py (handling both Linux and MacOS paths)
python3 ./meson.py build --prefix="$SU2_INSTALL_DIR" -Dcustom-mpi=true
# Run ninja for building
python3 -m ninja -C build install

echo "============================================="
echo "Creating utility scripts..."
echo "============================================="

# Create a bash_aliases file with SU2 convenience functions
ALIASES_FILE="$HOME/.su2_aliases"
cat > "$ALIASES_FILE" << EOF
# SU2 convenience functions
su2() {
  "$MPICH_INSTALL_DIR/bin/mpiexec" -n \$1 "$SU2_INSTALL_DIR/bin/SU2_CFD" \$2
}

su2back() {
  nohup "$MPICH_INSTALL_DIR/bin/mpiexec" -n \$1 "$SU2_INSTALL_DIR/bin/SU2_CFD" \$2 &
}

su2dry() {
  "$SU2_INSTALL_DIR/bin/SU2_CFD" -d \$1
}
EOF

# Add source to .bashrc or .bash_profile if not already there
SOURCE_LINE="[ -f $ALIASES_FILE ] && . $ALIASES_FILE"

# Check for different shell config files and update accordingly
for SHELL_RC in "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.zshrc"; do
    if [ -f "$SHELL_RC" ]; then
        if ! grep -q "$ALIASES_FILE" "$SHELL_RC"; then
            echo "$SOURCE_LINE" >> "$SHELL_RC"
        fi
    fi
done

# Source the aliases file for the current session
source "$ALIASES_FILE"

echo "============================================="
echo "Installation complete!"
echo "============================================="
echo "SU2 has been installed to: $SU2_INSTALL_DIR"
echo "MPICH has been installed to: $MPICH_INSTALL_DIR"
echo ""
echo "Usage examples:"
echo "  su2 4 config.cfg     # Run SU2 with 4 cores"
echo "  su2back 8 config.cfg # Run SU2 in background with 8 cores"
echo "  su2dry config.cfg    # Perform a dry run"
echo ""
echo "Please restart your terminal or run 'source $ALIASES_FILE'"
echo "to use the su2, su2back, and su2dry commands."
echo "============================================="
