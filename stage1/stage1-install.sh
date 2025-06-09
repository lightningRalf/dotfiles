#!/usr/bin/env bash
#
# Stage 1: Foundation Layer - Pure Orchestration
# 
# Assumes all files exist in repository structure
# Only copies and orchestrates, never generates

set -euo pipefail

# ===== Configuration =====
readonly DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
readonly STAGE_MARKER="$HOME/.dotfiles-stage1-complete"
readonly VERSION="3.0.0"

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

log_stage() { 
    echo -e "\n${PURPLE}━━━ $1 ━━━${NC}\n" 
}

# ===== Verify Repository Structure =====
verify_repository() {
    log_info "Verifying repository structure..."
    
    local required_files=(
        "shared/utils/platform.sh"
        "stage1/README.md"
        "README.md"
    )
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$DOTFILES_DIR/$file" ]]; then
            log_error "Missing required file: $file"
            log_error "Please ensure complete repository is cloned"
            exit 1
        fi
    done
    
    log_success "Repository structure verified"
}

# ===== Create Directory Structure =====
create_directories() {
    log_info "Creating directory structure..."
    
    local dirs=(
        ".cache"
        "backups"
    )
    
    for dir in "${dirs[@]}"; do
        mkdir -p "$DOTFILES_DIR/$dir"
    done
    
    log_success "Directory structure created"
}

# ===== Make Scripts Executable =====
set_permissions() {
    log_info "Setting script permissions..."
    
    # Make all shell scripts executable
    find "$DOTFILES_DIR" -name "*.sh" -type f -exec chmod +x {} \;
    
    log_success "Permissions set"
}

# ===== Platform Detection and Caching =====
detect_and_cache_platform() {
    log_info "Detecting platform..."
    
    # Source platform service
    source "$DOTFILES_DIR/shared/utils/platform.sh"
    
    # Save platform information
    save_platform_info
    
    # Load and display
    get_platform
    show_platform
    
    log_success "Platform detection complete"
}

# ===== Install Foundation Tools =====
install_foundation_tools() {
    log_info "Installing foundation tools..."
    
    # Source platform service for package management
    source "$DOTFILES_DIR/shared/utils/platform.sh"
    
    # Update repositories
    pkg_update
    
    # Platform-specific foundation packages
    local packages="git curl"
    
    case "$PKG_MANAGER" in
        apt|pkg)
            packages+=" build-essential"
            ;;
        dnf|yum)
            packages+=" gcc gcc-c++ make"
            ;;
        pacman)
            packages+=" base-devel"
            ;;
        zypper)
            packages+=" gcc gcc-c++ make"
            ;;
        apk)
            packages+=" build-base"
            ;;
    esac
    
    # Install packages
    if pkg_install $packages; then
        log_success "Foundation tools installed"
    else
        log_warning "Some tools may have failed to install"
    fi
}

# ===== Initialize Git Configuration Files =====
install_configs() {
    log_stage "Installing Foundation Configurations"
    
    local config_dir="$DOTFILES_DIR/stage1/configs"
    local scripts_dir="$DOTFILES_DIR/stage1/scripts"
    
    # Git configuration installation and setup
    if [[ -f "$config_dir/git/gitconfig" ]]; then
        log_info "Installing Git configuration..."
        
        # Backup existing configuration if present
        if [[ -f "$HOME/.gitconfig" ]]; then
            cp "$HOME/.gitconfig" "$DOTFILES_DIR/backups/gitconfig.$(date +%Y%m%d_%H%M%S)"
            log_info "Existing .gitconfig backed up"
        fi
        
        # Install base configuration
        cp "$config_dir/git/gitconfig" "$HOME/.gitconfig"
        log_success "Git base configuration installed"
        
        # Check if personalization needed
        if ! git config --global user.name &>/dev/null || ! git config --global user.email &>/dev/null; then
            # Run personalization script if available
            if [[ -f "$scripts_dir/setup-git.sh" ]]; then
                log_info "Running Git personalization..."
                source "$scripts_dir/setup-git.sh"
                setup_git_config
            else
                # Fallback: inline personalization
                log_warning "Git user configuration required for repository initialization"
                
                # Interactive prompts with validation
                while [[ -z "${git_name:-}" ]]; do
                    read -p "Enter your full name for Git commits: " git_name
                done
                
                while [[ -z "${git_email:-}" ]]; do
                    read -p "Enter your email for Git commits: " git_email
                done
                
                # Apply configuration
                git config --global user.name "$git_name"
                git config --global user.email "$git_email"
                
                log_success "Git user configuration set"
            fi
        else
            log_info "Git user configuration already exists"
        fi
        
        # Verify configuration is valid
        if git config --global user.name &>/dev/null && git config --global user.email &>/dev/null; then
            log_success "Git configuration verified"
            log_info "Git user: $(git config --global user.name) <$(git config --global user.email)>"
        else
            log_error "Git configuration verification failed"
            return 1
        fi
    else
        log_warning "Git configuration file not found, skipping"
    fi
    
    return 0
}

# ===== Initialize Git Repository =====
init_git_repo() {
    if [[ ! -d "$DOTFILES_DIR/.git" ]]; then
        log_info "Initializing git repository..."
        cd "$DOTFILES_DIR"
        git init
        git add .
        git commit -m "Initial commit: Stage 1 foundation"
        log_success "Git repository initialized"
    else
        log_info "Git repository already exists"
    fi
}

# ===== Main =====
main() {
    echo -e "\n${BLUE}Stage 1: Foundation Layer${NC}"
    echo -e "${BLUE}Version: $VERSION${NC}\n"
    
    # Check if already completed
    if [[ -f "$STAGE_MARKER" ]] && [[ "${1:-}" != "--force" ]]; then
        log_warning "Stage 1 already completed. Use --force to reinstall."
        exit 0
    fi
    
    # Change to dotfiles directory
    cd "$DOTFILES_DIR"
    
    # Core operations
    verify_repository
    create_directories
    set_permissions
    detect_and_cache_platform
    install_foundation_tools
    install_configs
    init_git_repo
    
    # Mark complete
    date -u +"%Y-%m-%d %H:%M:%S UTC" > "$STAGE_MARKER"
    
    # Summary
    echo -e "\n${GREEN}Stage 1 Complete!${NC}\n"
    echo "Foundation established with:"
    echo "  - Platform detection service"
    echo "  - Foundation tools installed"
    echo "  - Git configuration files installed"
    echo "  - Repository structure verified"
    echo -e "\nNext: ${BLUE}./stage2/install.sh${NC}"
}

# Execute
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi