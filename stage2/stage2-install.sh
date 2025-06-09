#!/usr/bin/env bash
#
# Stage 2: Shell Evolution - Pure Orchestration
# 
# Assumes all configuration files exist in stage2/configs/
# Only copies files and installs tools, never generates content

set -euo pipefail

# ===== Configuration =====
readonly DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
readonly STAGE_DIR="$DOTFILES_DIR/stage2"
readonly CONFIG_DIR="$HOME/.config"
readonly STAGE_MARKER="$HOME/.dotfiles-stage2-complete"
readonly VERSION="3.0.0"

# ===== Colors =====
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# ===== Logging =====
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1" >&2; }
log_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
log_stage() { echo -e "\n${BLUE}═══ $1 ═══${NC}\n"; }

# ===== Verify Prerequisites =====
verify_prerequisites() {
    log_info "Verifying prerequisites..."
    
    # Check Stage 1 completion
    if [[ ! -f "$HOME/.dotfiles-stage1-complete" ]]; then
        log_error "Stage 1 not completed. Please run stage1/install.sh first."
        exit 1
    fi
    
    # Verify platform service exists
    if [[ ! -f "$DOTFILES_DIR/shared/utils/platform.sh" ]]; then
        log_error "Platform service not found"
        exit 1
    fi
    
    # Verify configuration files exist
    local required_configs=(
        "configs/nushell/config.nu"
        "configs/nushell/env.nu"
        "configs/starship.toml"
        "configs/atuin/config.toml"
    )
    
    for config in "${required_configs[@]}"; do
        if [[ ! -f "$STAGE_DIR/$config" ]]; then
            log_error "Missing configuration: $config"
            exit 1
        fi
    done
    
    log_success "Prerequisites verified"
}

# ===== Load Platform Service =====
load_platform_service() {
    source "$DOTFILES_DIR/shared/utils/platform.sh"
    get_platform || exit 1
    log_success "Platform service loaded: $PLATFORM | $PKG_MANAGER"
}

# ===== Install Build Dependencies =====
install_build_deps() {
    log_stage "Installing Build Dependencies"
    
    local deps=""
    
    case "$PKG_MANAGER" in
        apt)
            deps="pkg-config libssl-dev"
            ;;
        dnf|yum)
            deps="pkg-config openssl-devel"
            ;;
        pacman)
            deps="pkg-config openssl"
            ;;
        zypper)
            deps="pkg-config libopenssl-devel"
            ;;
        apk)
            deps="pkgconfig openssl-dev"
            ;;
        pkg)
            deps="pkg-config openssl"
            ;;
        brew)
            deps="pkg-config openssl"
            ;;
    esac
    
    if [[ -n "$deps" ]]; then
        log_info "Installing: $deps"
        pkg_install $deps || log_warning "Some dependencies failed"
    fi
}

# ===== Install Rust =====
install_rust() {
    log_stage "Installing Rust Toolchain"
    
    if command -v rustc &>/dev/null; then
        log_info "Rust already installed: $(rustc --version)"
        rustup update stable
    else
        case "$PLATFORM" in
            termux)
                pkg_install rust
                ;;
            *)
                curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | \
                    sh -s -- -y --no-modify-path
                source "$HOME/.cargo/env"
                ;;
        esac
    fi
    
    export PATH="$HOME/.cargo/bin:$PATH"
}

# ===== Install Shell Tools =====
install_tools() {
    log_stage "Installing Shell Evolution Tools"
    
    # Nushell
    if ! command -v nu &>/dev/null; then
        log_info "Installing Nushell..."
        case "$PKG_MANAGER" in
            pkg|brew)
                pkg_install nushell
                ;;
            *)
                cargo install nu --locked
                ;;
        esac
    fi
    
    # Starship
    if ! command -v starship &>/dev/null; then
        log_info "Installing Starship..."
        case "$PKG_MANAGER" in
            pkg|brew)
                pkg_install starship
                ;;
            *)
                curl -sS https://starship.rs/install.sh | sh -s -- -y
                ;;
        esac
    fi
    
    # Zoxide
    if ! command -v zoxide &>/dev/null; then
        log_info "Installing Zoxide..."
        case "$PKG_MANAGER" in
            pkg|brew)
                pkg_install zoxide
                ;;
            *)
                cargo install zoxide --locked
                ;;
        esac
    fi
    
    # Atuin (optional)
    if ! command -v atuin &>/dev/null; then
        log_info "Installing Atuin (optional)..."
        case "$PKG_MANAGER" in
            brew)
                pkg_install atuin
                ;;
            pkg)
                pkg_install atuin 2>/dev/null || log_warning "Atuin not available"
                ;;
            *)
                cargo install atuin --locked || log_warning "Atuin failed (optional)"
                ;;
        esac
    fi
}

# ===== Copy Configurations =====
install_configs() {
    log_stage "Installing Configuration Files"
    
    # Nushell
    mkdir -p "$CONFIG_DIR/nushell"
    cp "$STAGE_DIR/configs/nushell/config.nu" "$CONFIG_DIR/nushell/"
    cp "$STAGE_DIR/configs/nushell/env.nu" "$CONFIG_DIR/nushell/"
    log_success "Nushell configuration installed"
    
    # Starship
    cp "$STAGE_DIR/configs/starship.toml" "$CONFIG_DIR/starship.toml"
    log_success "Starship configuration installed"
    
    # Atuin
    mkdir -p "$CONFIG_DIR/atuin"
    cp "$STAGE_DIR/configs/atuin/config.toml" "$CONFIG_DIR/atuin/"
    log_success "Atuin configuration installed"
}

# ===== Verify Installation =====
verify_installation() {
    log_stage "Verifying Installation"
    
    local tools=("nu" "starship" "zoxide")
    local missing=()
    
    for tool in "${tools[@]}"; do
        if command -v "$tool" &>/dev/null; then
            log_success "$tool: $(command -v $tool)"
        else
            missing+=("$tool")
        fi
    done
    
    # Atuin is optional
    if command -v atuin &>/dev/null; then
        log_success "atuin: $(command -v atuin) (optional)"
    else
        log_info "atuin: not installed (optional)"
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing critical tools: ${missing[*]}"
        exit 1
    fi
}

# ===== Main =====
main() {
    echo -e "\n${BLUE}Stage 2: Shell Evolution${NC}"
    echo -e "${BLUE}Version: $VERSION${NC}\n"
    
    # Core workflow
    verify_prerequisites
    load_platform_service
    install_build_deps
    install_rust
    install_tools
    install_configs
    verify_installation
    
    # Mark complete
    date -u +"%Y-%m-%d %H:%M:%S UTC" > "$STAGE_MARKER"
    
    # Summary
    echo -e "\n${GREEN}Stage 2 Complete!${NC}"
    echo -e "\nTo start using Nushell: ${YELLOW}nu${NC}"
    echo -e "To set as default: ${YELLOW}chsh -s $(command -v nu)${NC}"
}

# Execute
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi