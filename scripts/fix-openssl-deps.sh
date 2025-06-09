#!/usr/bin/env bash
#
# OpenSSL Dependencies Resolution Script
# Fixes compilation issues for Rust packages requiring OpenSSL
#
# This script detects your platform and installs the necessary
# dependencies for building software that links against OpenSSL

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1" >&2; }
log_warning() { echo -e "${YELLOW}[!]${NC} $1"; }

# Detect the package manager and distribution
detect_system() {
    if command -v apt-get &>/dev/null; then
        echo "debian"
    elif command -v dnf &>/dev/null; then
        echo "fedora"
    elif command -v yum &>/dev/null; then
        echo "rhel"
    elif command -v pacman &>/dev/null; then
        echo "arch"
    elif command -v zypper &>/dev/null; then
        echo "suse"
    elif command -v apk &>/dev/null; then
        echo "alpine"
    elif command -v pkg &>/dev/null && [[ -d "/data/data/com.termux" ]]; then
        echo "termux"
    else
        echo "unknown"
    fi
}

# Install dependencies based on the system
install_dependencies() {
    local system=$1
    
    log_info "Installing OpenSSL development dependencies for $system..."
    
    case "$system" in
        debian)
            log_info "Using apt-get to install dependencies..."
            sudo apt-get update
            sudo apt-get install -y \
                pkg-config \
                libssl-dev \
                build-essential \
                cmake
            ;;
            
        fedora)
            log_info "Using dnf to install dependencies..."
            sudo dnf install -y \
                pkg-config \
                openssl-devel \
                gcc \
                gcc-c++ \
                make \
                cmake
            ;;
            
        rhel)
            log_info "Using yum to install dependencies..."
            sudo yum install -y \
                pkg-config \
                openssl-devel \
                gcc \
                gcc-c++ \
                make \
                cmake
            ;;
            
        arch)
            log_info "Using pacman to install dependencies..."
            sudo pacman -Sy --needed --noconfirm \
                pkg-config \
                openssl \
                base-devel \
                cmake
            ;;
            
        suse)
            log_info "Using zypper to install dependencies..."
            sudo zypper install -y \
                pkg-config \
                libopenssl-devel \
                gcc \
                gcc-c++ \
                make \
                cmake
            ;;
            
        alpine)
            log_info "Using apk to install dependencies..."
            sudo apk add --no-cache \
                pkgconfig \
                openssl-dev \
                build-base \
                cmake
            ;;
            
        termux)
            log_info "Using pkg to install dependencies..."
            pkg update
            pkg install -y \
                pkg-config \
                openssl \
                openssl-dev \
                binutils \
                build-essential
            ;;
            
        *)
            log_error "Unknown system. Please install manually:"
            echo "  - pkg-config"
            echo "  - OpenSSL development headers"
            echo "  - C compiler toolchain"
            exit 1
            ;;
    esac
}

# Verify installation
verify_installation() {
    log_info "Verifying installation..."
    
    local all_good=true
    
    # Check pkg-config
    if command -v pkg-config &>/dev/null; then
        log_success "pkg-config is installed"
    else
        log_error "pkg-config is NOT installed"
        all_good=false
    fi
    
    # Check for OpenSSL via pkg-config
    if pkg-config --exists openssl 2>/dev/null; then
        local openssl_version=$(pkg-config --modversion openssl)
        log_success "OpenSSL development files found: $openssl_version"
        
        # Show OpenSSL paths for debugging
        log_info "OpenSSL include path: $(pkg-config --cflags openssl)"
        log_info "OpenSSL library path: $(pkg-config --libs openssl)"
    else
        log_error "OpenSSL development files NOT found by pkg-config"
        all_good=false
    fi
    
    # Check for compiler
    if command -v gcc &>/dev/null || command -v clang &>/dev/null; then
        log_success "C compiler is available"
    else
        log_error "No C compiler found"
        all_good=false
    fi
    
    if $all_good; then
        log_success "All dependencies are properly installed!"
        return 0
    else
        log_error "Some dependencies are missing"
        return 1
    fi
}

# Alternative installation method using static linking
setup_static_openssl() {
    log_info "Setting up environment for static OpenSSL linking..."
    
    # Set environment variables for the current session
    export OPENSSL_STATIC=1
    export OPENSSL_LIB_DIR=/usr/lib/x86_64-linux-gnu
    export OPENSSL_INCLUDE_DIR=/usr/include/openssl
    
    log_info "Environment variables set:"
    echo "  OPENSSL_STATIC=1"
    echo "  OPENSSL_LIB_DIR=$OPENSSL_LIB_DIR"
    echo "  OPENSSL_INCLUDE_DIR=$OPENSSL_INCLUDE_DIR"
    
    log_warning "Note: These are temporary. Add to ~/.bashrc for persistence."
}

# Main execution
main() {
    echo -e "${BLUE}OpenSSL Dependencies Installer${NC}"
    echo "================================="
    
    # Detect system
    local system=$(detect_system)
    log_info "Detected system: $system"
    
    # Install dependencies
    install_dependencies "$system"
    
    # Verify installation
    if verify_installation; then
        echo ""
        log_success "System is ready for Rust compilation with OpenSSL!"
        echo ""
        echo "You can now retry installing Nushell:"
        echo "  cargo install nu --locked"
        
        # For Termux, suggest additional steps
        if [[ "$system" == "termux" ]]; then
            echo ""
            log_info "Termux-specific note:"
            echo "If you still encounter issues, try:"
            echo "  export OPENSSL_DIR=\$PREFIX"
            echo "  export PKG_CONFIG_PATH=\$PREFIX/lib/pkgconfig"
        fi
    else
        echo ""
        log_warning "Manual intervention may be required."
        echo ""
        echo "Try setting environment variables manually:"
        setup_static_openssl
    fi
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi