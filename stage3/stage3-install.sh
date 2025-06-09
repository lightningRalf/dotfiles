#!/usr/bin/env bash
#
# Stage 3: CLI Modernization - Installation Orchestrator
# 
# Philosophy: Replace traditional tools with modern alternatives
# that embrace performance, usability, and visual clarity

set -euo pipefail

# ===== Configuration =====
readonly DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
readonly STAGE_DIR="$DOTFILES_DIR/stage3"
readonly CONFIG_DIR="$HOME/.config"
readonly STAGE_MARKER="$HOME/.dotfiles-stage3-complete"
readonly VERSION="1.0.0"

# ===== Tool Versions =====
# Pin versions for reproducibility
readonly FZF_VERSION="0.46.0"
readonly BAT_VERSION="0.24.0"
readonly EZA_VERSION="0.18.0"
readonly DELTA_VERSION="0.17.0"

# ===== Colors =====
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly PURPLE='\033[0;35m'
readonly NC='\033[0m'

# ===== Logging =====
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1" >&2; }
log_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
log_stage() { echo -e "\n${PURPLE}━━━ $1 ━━━${NC}\n"; }

# ===== Helper Functions =====
command_exists() {
    command -v "$1" &>/dev/null
}

install_from_cargo() {
    local tool="$1"
    local package="${2:-$tool}"
    
    if command_exists "$tool"; then
        log_info "$tool already installed"
    else
        log_info "Installing $tool via cargo..."
        cargo install "$package" --locked || {
            log_warning "$tool installation failed, trying without --locked"
            cargo install "$package"
        }
    fi
}

install_from_binary() {
    local tool="$1"
    local url="$2"
    local extract_cmd="$3"
    
    if command_exists "$tool"; then
        log_info "$tool already installed"
        return 0
    fi
    
    log_info "Installing $tool from binary..."
    local temp_dir=$(mktemp -d)
    cd "$temp_dir"
    
    curl -LO "$url" || wget "$url"
    eval "$extract_cmd"
    
    # Find and install binary
    find . -name "$tool" -type f -executable -exec mv {} "$HOME/.local/bin/" \;
    cd - > /dev/null
    rm -rf "$temp_dir"
}

# ===== Verify Prerequisites =====
verify_prerequisites() {
    log_stage "Verifying Prerequisites"
    
    # Check Stage 2 completion
    if [[ ! -f "$HOME/.dotfiles-stage2-complete" ]]; then
        log_error "Stage 2 not completed. Please run stage2/install.sh first."
        exit 1
    fi
    
    # Verify Rust toolchain
    if ! command_exists cargo; then
        log_error "Cargo not found. Rust toolchain required."
        exit 1
    fi
    
    # Ensure ~/.local/bin exists and is in PATH
    mkdir -p "$HOME/.local/bin"
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        export PATH="$HOME/.local/bin:$PATH"
        log_warning "Added ~/.local/bin to PATH for this session"
    fi
    
    log_success "Prerequisites verified"
}

# ===== Load Platform Service =====
load_platform_service() {
    source "$DOTFILES_DIR/shared/utils/platform.sh"
    get_platform || exit 1
    log_success "Platform service loaded: $PLATFORM | $PKG_MANAGER"
}

# ===== Install Core File Tools =====
install_file_tools() {
    log_stage "Installing Core File Tools"
    
    # bat - Better cat
    case "$PKG_MANAGER" in
        apt|brew|pkg)
            pkg_install batcat
            ;;
        *)
            install_from_cargo "bat"
            ;;
    esac
    
    # fd - Better find
    case "$PKG_MANAGER" in
        apt|brew|pkg)
            pkg_install fd-find || pkg_install fd
            # Debian/Ubuntu use fd-find
            if [[ "$PKG_MANAGER" == "apt" ]] && command_exists fdfind; then
                ln -sf $(which fdfind) "$HOME/.local/bin/fd"
            fi
            ;;
        *)
            install_from_cargo "fd"
            ;;
    esac
    
    # eza - Better ls (successor to exa)
    case "$PKG_MANAGER" in
        brew|pkg)
            pkg_install eza
            ;;
        *)
            install_from_cargo "eza"
            ;;
    esac
}

# ===== Install Text Processing Tools =====
install_text_tools() {
    log_stage "Installing Text Processing Tools"
    
    # ripgrep - Better grep
    case "$PKG_MANAGER" in
        apt|brew|pkg|dnf|pacman)
            pkg_install ripgrep
            ;;
        *)
            install_from_cargo "rg" "ripgrep"
            ;;
    esac
    
    # sd - Better sed (for simple cases)
    case "$PKG_MANAGER" in
        brew|pkg)
            pkg_install sd
            ;;
        *)
            install_from_cargo "sd"
            ;;
    esac
}

# ===== Install System Monitoring Tools =====
install_monitoring_tools() {
    log_stage "Installing System Monitoring Tools"
    
    # bottom - Better top
    case "$PKG_MANAGER" in
        brew)
            pkg_install bottom
            ;;
        *)
            install_from_cargo "btm" "bottom"
            ;;
    esac
    
    # dust - Better du
    case "$PKG_MANAGER" in
        brew)
            pkg_install dust
            ;;
        *)
            install_from_cargo "dust" "du-dust"
            ;;
    esac
}

# ===== Install Development Tools =====
install_dev_tools() {
    log_stage "Installing Development Tools"
    
    # delta - Better git diff
    case "$PKG_MANAGER" in
        brew)
            pkg_install git-delta
            ;;
        *)
            install_from_cargo "delta" "git-delta"
            ;;
    esac
    
    # fzf - Fuzzy finder
    case "$PKG_MANAGER" in
        apt|brew|pkg|dnf|pacman)
            pkg_install fzf
            ;;
        *)
            local arch=$(uname -m)
            local os=$(uname -s | tr '[:upper:]' '[:lower:]')
            local fzf_url="https://github.com/junegunn/fzf/releases/download/${FZF_VERSION}/fzf-${FZF_VERSION}-${os}_${arch}.tar.gz"
            install_from_binary "fzf" "$fzf_url" "tar -xzf *.tar.gz"
            ;;
    esac
}

# ===== Install Configurations =====
install_configs() {
    log_stage "Installing Configuration Files"
    
    # bat configuration
    if [[ -f "$STAGE_DIR/configs/bat/config" ]]; then
        mkdir -p "$CONFIG_DIR/bat"
        cp "$STAGE_DIR/configs/bat/config" "$CONFIG_DIR/bat/"
        log_success "bat configuration installed"
    fi
    
    # bottom configuration
    if [[ -f "$STAGE_DIR/configs/bottom/bottom.toml" ]]; then
        mkdir -p "$CONFIG_DIR/bottom"
        cp "$STAGE_DIR/configs/bottom/bottom.toml" "$CONFIG_DIR/bottom/"
        log_success "bottom configuration installed"
    fi
    
    # Git configuration for delta
    if command_exists delta; then
        log_info "Configuring git to use delta..."
        git config --global core.pager "delta"
        git config --global interactive.diffFilter "delta --color-only"
        git config --global delta.navigate true
        git config --global delta.light false
        git config --global delta.side-by-side true
        git config --global delta.line-numbers true
        log_success "Git configured to use delta"
    fi

}

# ===== Setup Shell Integration =====
setup_shell_integration() {
    log_stage "Setting up Shell Integration"
    
    local nu_config="$CONFIG_DIR/nushell/config.nu"
    if [[ -f "$nu_config" ]]; then
        # Add tool aliases if not already present
        if ! grep -q "# Stage 3 CLI Tools" "$nu_config"; then
            cat >> "$nu_config" << 'EOF'

# Stage 3 CLI Tools Integration
alias bat = batcat
alias find = fd
alias ls = eza
alias ll = eza -la
alias tree = eza --tree
alias grep = rg
alias top = btm
alias htop = btm
alias du = dust

# Enhanced commands
def search [pattern: string, path?: string] {
    let search_path = ($path | default ".")
    rg $pattern $search_path | fzf --preview 'bat --color=always {1} --highlight-line {2}'
}

def fuzzy_cd [] {
    let dir = (fd --type d | fzf --preview 'eza --tree --level=2 {}')
    if ($dir | is-not-empty) {
        cd $dir
    }
}
EOF
            log_success "Nushell integration configured"
        fi
    fi
}

# ===== Verify Installation =====
verify_installation() {
    log_stage "Verifying Installation"
    
    local tools=(
        "batcat:bat"
        "fd:fd"
        "eza:eza"
        "rg:ripgrep"
        "sd:sd"
        "btm:bottom"
        "dust:dust"
        "delta:git-delta"
        "fzf:fzf"
    )
    
    local failed=()
    
    for tool_spec in "${tools[@]}"; do
        IFS=':' read -r cmd name <<< "$tool_spec"
        if command_exists "$cmd"; then
            log_success "$name: $(command -v $cmd)"
        else
            failed+=("$name")
            log_error "$name: not found"
        fi
    done
    
    if [[ ${#failed[@]} -gt 0 ]]; then
        log_error "Missing tools: ${failed[*]}"
        log_warning "Some tools failed to install. The system is still usable."
    fi
}

# ===== Print Usage Guide =====
print_usage_guide() {
    cat << EOF

${GREEN}Stage 3 Complete!${NC}

${BLUE}Modern CLI Tools Installed:${NC}
  ${YELLOW}File Operations:${NC}
    bat    - Enhanced file viewer with syntax highlighting
    fd     - Fast and intuitive file finder
    eza    - Modern ls with Git integration
    
  ${YELLOW}Text Processing:${NC}
    rg     - Blazing fast grep replacement
    sd     - Intuitive sed alternative
    
  ${YELLOW}System Monitoring:${NC}
    btm    - Beautiful process monitor
    dust   - Visual disk usage analyzer
    
  ${YELLOW}Development:${NC}
    delta  - Enhanced git diffs
    fzf    - Fuzzy finder for everything

${BLUE}Quick Start:${NC}
  ${GREEN}# View files with syntax highlighting${NC}
  bat README.md
  
  ${GREEN}# Find files quickly${NC}
  fd pattern
  
  ${GREEN}# Search in files${NC}
  rg "search term"
  
  ${GREEN}# Interactive file search${NC}
  rg pattern | fzf --preview 'bat {1}'
  
  ${GREEN}# Visualize disk usage${NC}
  dust

${BLUE}Next Steps:${NC}
  - Explore each tool with --help
  - Check ~/.config for tool configurations
  - Run ${YELLOW}nu${NC} to use enhanced commands in Nushell

EOF
}

# ===== Main =====
main() {
    echo -e "\n${BLUE}Stage 3: CLI Modernization${NC}"
    echo -e "${BLUE}Version: $VERSION${NC}\n"
    
    # Check if already completed
    if [[ -f "$STAGE_MARKER" ]] && [[ "${1:-}" != "--force" ]]; then
        log_warning "Stage 3 already completed. Use --force to reinstall."
        exit 0
    fi
    
    # Core workflow
    verify_prerequisites
    load_platform_service
    install_file_tools
    install_text_tools
    install_monitoring_tools
    install_dev_tools
    install_configs
    setup_shell_integration
    verify_installation
    
    # Mark complete
    date -u +"%Y-%m-%d %H:%M:%S UTC" > "$STAGE_MARKER"
    
    # Show usage guide
    print_usage_guide
}

# Execute
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
