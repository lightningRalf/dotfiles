#!/usr/bin/env bash
#
# Stage 2: Shell Evolution - Installer Only
# 
# This script ONLY orchestrates installation.
# All configurations exist as separate files in stage2/configs/

set -euo pipefail

# ===== Configuration =====
readonly DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
readonly STAGE_DIR="$DOTFILES_DIR/stage2"
readonly CONFIG_DIR="$HOME/.config"
readonly STAGE_MARKER="$HOME/.dotfiles-stage2-complete"

# ===== Colors =====
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# ===== Logging =====
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }

# ===== Load Platform Info =====
load_platform() {
    source "$DOTFILES_DIR/shared/utils/platform.sh"
    load_platform_info || exit 1
}

# ===== Copy Configuration Files =====
install_configs() {
    log_info "Installing configuration files..."
    
    # Nushell
    mkdir -p "$CONFIG_DIR/nushell"
    cp "$STAGE_DIR/configs/nushell/config.nu" "$CONFIG_DIR/nushell/"
    cp "$STAGE_DIR/configs/nushell/env.nu" "$CONFIG_DIR/nushell/"
    
    # Starship
    cp "$STAGE_DIR/configs/starship.toml" "$CONFIG_DIR/starship.toml"
    
    # Atuin
    mkdir -p "$CONFIG_DIR/atuin"
    cp "$STAGE_DIR/configs/atuin/config.toml" "$CONFIG_DIR/atuin/"
    
    log_success "Configurations installed"
}

# ===== Logging Functions =====
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1" >&2; }
log_stage() { echo -e "\n${PURPLE}━━━ $1 ━━━${NC}\n"; }

# ===== Stage Verification =====
verify_prerequisites() {
    log_stage "Verifying Prerequisites"
    
    if [[ ! -f "$STAGE_MARKER" ]] || [[ $(cat "$STAGE_MARKER") -lt "$REQUIRED_STAGE" ]]; then
        log_error "Stage 1 must be completed first."
        exit 1
    fi
    
    PLATFORM=$(detect_os)
    DISTRO=$(detect_distro)
    PKG_MANAGER=$(detect_pkg_manager)
    
    log_success "Prerequisites verified"
    log_info "Platform: $PLATFORM | Distribution: $DISTRO | Package Manager: $PKG_MANAGER"
}

# ===== Build Dependencies Installation =====
install_build_dependencies() {
    log_stage "Installing Build Dependencies"
    
    local deps_needed=false
    
    # Check if pkg-config exists
    if ! command -v pkg-config &>/dev/null; then
        deps_needed=true
        log_warning "pkg-config not found"
    fi
    
    # Check if OpenSSL development headers are available
    if ! pkg-config --exists openssl 2>/dev/null; then
        deps_needed=true
        log_warning "OpenSSL development headers not found"
    fi
    
    if [[ "$deps_needed" == "false" ]]; then
        log_success "Build dependencies already satisfied"
        return 0
    fi
    
    log_info "Installing required build dependencies..."
    
    case "$PKG_MANAGER" in
        apt)
            sudo apt-get update -qq
            sudo apt-get install -y pkg-config libssl-dev build-essential
            ;;
        dnf)
            sudo dnf install -y pkg-config openssl-devel gcc gcc-c++ make
            ;;
        yum)
            sudo yum install -y pkg-config openssl-devel gcc gcc-c++ make
            ;;
        pacman)
            sudo pacman -S --needed --noconfirm pkg-config openssl base-devel
            ;;
        zypper)
            sudo zypper install -y pkg-config libopenssl-devel gcc gcc-c++ make
            ;;
        apk)
            sudo apk add --no-cache pkgconfig openssl-dev build-base
            ;;
        pkg)  # Termux
            pkg install -y pkg-config openssl openssl-dev build-essential
            ;;
        *)
            log_error "Unsupported package manager for automatic dependency installation"
            log_info "Please install: pkg-config, OpenSSL dev headers, C compiler"
            exit 1
            ;;
    esac
    
    # Verify installation succeeded
    if pkg-config --exists openssl 2>/dev/null; then
        log_success "Build dependencies installed successfully"
    else
        log_error "Failed to install build dependencies"
        exit 1
    fi
}

# ===== Rust Installation =====
install_rust_toolchain() {
    log_stage "Installing Rust Toolchain"
    
    if command -v rustc &>/dev/null; then
        log_info "Rust already installed, updating..."
        rustup update stable
    else
        log_info "Installing Rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
        source "$HOME/.cargo/env"
    fi
    
    if command -v cargo &>/dev/null; then
        log_success "Rust installed: $(rustc --version)"
    else
        log_error "Rust installation failed"
        exit 1
    fi
}

# ===== Tool Installation with Fallbacks =====
install_cli_tools() {
    log_stage "Installing Modern CLI Tools"
    
    # Ensure cargo is in PATH
    export PATH="$HOME/.cargo/bin:$PATH"
    
    # Nushell
    if ! command -v nu &>/dev/null; then
        log_info "Installing Nushell..."
        if [[ "$PKG_MANAGER" == "pkg" ]]; then
            pkg install -y nushell
        else
            cargo install nu --locked || {
                log_warning "Cargo install failed, trying pre-built binary..."
                install_nushell_binary
            }
        fi
    fi
    
    # Starship
    if ! command -v starship &>/dev/null; then
        log_info "Installing Starship..."
        if [[ "$PKG_MANAGER" == "pkg" ]]; then
            pkg install -y starship
        else
            curl -sS https://starship.rs/install.sh | sh -s -- -y
        fi
    fi
    
    # Zoxide
    if ! command -v zoxide &>/dev/null; then
        log_info "Installing Zoxide..."
        if [[ "$PKG_MANAGER" == "pkg" ]]; then
            pkg install -y zoxide
        else
            cargo install zoxide --locked
        fi
    fi
    
    # Atuin (optional - may fail on some platforms)
    if ! command -v atuin &>/dev/null; then
        log_info "Installing Atuin..."
        if [[ "$PKG_MANAGER" == "pkg" ]]; then
            pkg install -y atuin 2>/dev/null || log_warning "Atuin not available in Termux"
        else
            cargo install atuin --locked || log_warning "Atuin installation failed (non-critical)"
        fi
    fi
    
    # Verify critical tools
    local critical_tools=("nu" "starship" "zoxide")
    for tool in "${critical_tools[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            log_error "Failed to install critical tool: $tool"
            exit 1
        fi
    done
    
    log_success "CLI tools installed"
}

# ===== Fallback: Install Nushell Binary =====
install_nushell_binary() {
    local nu_version="0.91.0"  # Update as needed
    local arch=$(uname -m)
    local platform=$(uname -s | tr '[:upper:]' '[:lower:]')
    
    case "$arch" in
        x86_64) arch="x86_64" ;;
        aarch64) arch="aarch64" ;;
        *) log_error "Unsupported architecture: $arch"; return 1 ;;
    esac
    
    local download_url="https://github.com/nushell/nushell/releases/download/${nu_version}/nu-${nu_version}-${arch}-unknown-${platform}-gnu.tar.gz"
    
    log_info "Downloading Nushell binary..."
    cd /tmp
    curl -L -o nu.tar.gz "$download_url"
    tar -xzf nu.tar.gz
    sudo mv nu-${nu_version}-*/nu /usr/local/bin/
    rm -rf nu.tar.gz nu-${nu_version}-*
    cd -
}

# ===== Main =====
main() {
    echo -e "\n${BLUE}Stage 2: Shell Evolution${NC}\n"
    
    load_platform
    install_configs
    install_tools
    
    date > "$STAGE_MARKER"
    echo -e "\n${GREEN}Stage 2 Complete!${NC}"
}

main "$@"