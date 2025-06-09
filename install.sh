#!/usr/bin/env bash
#
# Stage 1: Foundation Layer Installer
# A minimal, robust base for portable Linux environment setup
#
# This script focuses on:
# 1. Platform detection and adaptation
# 2. Basic dependency management
# 3. Repository structure creation
# 4. Essential tool installation

set -euo pipefail

pre_flight_check() {
    local required_dirs=("logs" "scripts" "config")
    
    echo "Performing pre-flight check..."
    
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$DOTFILES_DIR/$dir" ]]; then
            echo "Creating missing directory: $dir"
            mkdir -p "$DOTFILES_DIR/$dir"
        fi
    done
    
    # Verify write permissions
    if [[ ! -w "$DOTFILES_DIR" ]]; then
        echo "Error: Cannot write to $DOTFILES_DIR"
        exit 1
    fi
    
    echo "Pre-flight check completed successfully"
}

# ===== Configuration Variables =====
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
CONFIG_DIR="$HOME/.config"
STAGE_MARKER="$HOME/.dotfiles-stage"
CURRENT_STAGE=1

# ===== Color Definitions =====
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly NC='\033[0m' # No Color

# ===== Logging Functions =====
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1" >&2
}

log_stage() {
    echo -e "\n${PURPLE}━━━ $1 ━━━${NC}\n"
}

# ===== Platform Detection Module =====
detect_platform() {
    local platform="unknown"
    local pkg_manager="unknown"
    local distro="unknown"
    
    # Detect if we're in Termux
    if [[ -d "/data/data/com.termux" ]]; then
        platform="termux"
        pkg_manager="pkg"
        distro="termux"
    # Detect WSL
    elif grep -qi microsoft /proc/version 2>/dev/null; then
        platform="wsl"
        # Continue to detect actual distro
    # Detect if we're in a container
    elif [[ -f /.dockerenv ]] || grep -q 'docker\|lxc' /proc/1/cgroup 2>/dev/null; then
        platform="container"
    else
        platform="linux"
    fi
    
    # Detect package manager and distro for non-Termux systems
    if [[ "$platform" != "termux" ]]; then
        if [[ -f /etc/os-release ]]; then
            distro=$(grep "^ID=" /etc/os-release | cut -d= -f2 | tr -d '"')
            
            case "$distro" in
                ubuntu|debian|linuxmint|pop)
                    pkg_manager="apt"
                    ;;
                fedora|rhel|centos|rocky|almalinux)
                    pkg_manager="dnf"
                    ;;
                arch|manjaro|endeavouros)
                    pkg_manager="pacman"
                    ;;
                opensuse*)
                    pkg_manager="zypper"
                    ;;
                alpine)
                    pkg_manager="apk"
                    ;;
            esac
        fi
    fi
    
    # Export detected values
    export PLATFORM="$platform"
    export PKG_MANAGER="$pkg_manager"
    export DISTRO="$distro"
    
    log_info "Detected platform: $PLATFORM"
    log_info "Package manager: $PKG_MANAGER"
    log_info "Distribution: $DISTRO"
}

# ===== Package Manager Abstraction =====
pkg_update() {
    log_info "Updating package repositories..."
    
    case "$PKG_MANAGER" in
        apt)
            sudo apt-get update -qq
            ;;
        pkg)
            pkg update -y
            ;;
        dnf)
            sudo dnf check-update -q || true
            ;;
        pacman)
            sudo pacman -Sy --noconfirm
            ;;
        zypper)
            sudo zypper refresh -q
            ;;
        apk)
            sudo apk update
            ;;
        *)
            log_warning "Unknown package manager. Skipping update."
            return 1
            ;;
    esac
    
    log_success "Package repositories updated"
}

pkg_install() {
    local packages="$@"
    
    case "$PKG_MANAGER" in
        apt)
            sudo apt-get install -y -qq $packages
            ;;
        pkg)
            pkg install -y $packages
            ;;
        dnf)
            sudo dnf install -y -q $packages
            ;;
        pacman)
            sudo pacman -S --noconfirm --needed $packages
            ;;
        zypper)
            sudo zypper install -y -q $packages
            ;;
        apk)
            sudo apk add --no-cache $packages
            ;;
        *)
            log_error "Unknown package manager. Cannot install packages."
            return 1
            ;;
    esac
}

# ===== Dependency Mapping =====
get_base_packages() {
    local packages="git curl wget"
    
    case "$PKG_MANAGER" in
        apt|pkg)
            packages="$packages build-essential"
            ;;
        dnf)
            packages="$packages gcc gcc-c++ make"
            ;;
        pacman)
            packages="$packages base-devel"
            ;;
        zypper)
            packages="$packages gcc gcc-c++ make"
            ;;
        apk)
            packages="$packages build-base"
            ;;
    esac
    
    # Add platform-specific packages
    if [[ "$PLATFORM" != "termux" ]]; then
        packages="$packages sudo"
    fi
    
    echo "$packages"
}

# ===== Repository Structure Creation =====
create_repository_structure() {
    log_stage "Creating Repository Structure"
    
    # Create main directories
    local dirs=(
        "$DOTFILES_DIR/config/shell"
        "$DOTFILES_DIR/config/git"
        "$DOTFILES_DIR/config/tmux"
        "$DOTFILES_DIR/scripts/detect"
        "$DOTFILES_DIR/scripts/install"
        "$DOTFILES_DIR/scripts/utils"
        "$DOTFILES_DIR/docs"
        "$DOTFILES_DIR/backups"
    )
    
    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
        log_success "Created: $dir"
    done
    
    # Create .gitignore
    cat > "$DOTFILES_DIR/.gitignore" << 'EOF'
# Local configurations
local/
*.local

# Backup files
backups/
*.bak
*.backup

# Temporary files
*.tmp
*.swp
*.swo
*~

# OS files
.DS_Store
Thumbs.db

# IDE files
.idea/
.vscode/
*.sublime-*

# Logs
*.log
logs/

# Stage markers
.dotfiles-stage*
EOF
    
    log_success "Created .gitignore"
}

# ===== Basic Git Configuration =====
setup_basic_git() {
    log_stage "Setting Up Basic Git Configuration"
    
    # Create a minimal gitconfig
    cat > "$DOTFILES_DIR/config/git/gitconfig" << 'EOF'
# Basic Git Configuration - Stage 1

[core]
    editor = ${EDITOR:-nano}
    autocrlf = input
    safecrlf = warn

[init]
    defaultBranch = main

[color]
    ui = auto

[push]
    default = current

[pull]
    rebase = true

[alias]
    st = status
    co = checkout
    br = branch
    ci = commit
    unstage = reset HEAD --
    last = log -1 HEAD
    visual = !gitk
EOF
    
    # Link gitconfig if it doesn't exist
    if [[ ! -f "$HOME/.gitconfig" ]]; then
        ln -sf "$DOTFILES_DIR/config/git/gitconfig" "$HOME/.gitconfig"
        log_success "Linked git configuration"
    else
        log_info "Existing .gitconfig found, skipping link"
    fi
}

# ===== Essential Tools Installation =====
install_essential_tools() {
    log_stage "Installing Essential Tools"
    
    # Get platform-appropriate packages
    local packages=$(get_base_packages)
    
    log_info "Installing: $packages"
    if pkg_install $packages; then
        log_success "Essential tools installed"
    else
        log_error "Failed to install some packages"
        return 1
    fi
    
    # Install additional tools based on platform
    if [[ "$PLATFORM" != "termux" ]]; then
        # Install tmux if not present
        if ! command -v tmux &>/dev/null; then
            log_info "Installing tmux..."
            pkg_install tmux && log_success "tmux installed"
        fi
    fi
}

# ===== Create Helper Scripts =====
create_helper_scripts() {
    log_stage "Creating Helper Scripts"
    
    # Create platform detection script
    cat > "$DOTFILES_DIR/scripts/detect/platform.sh" << 'EOF'
#!/usr/bin/env bash
# Platform detection utilities

detect_os() {
    if [[ -d "/data/data/com.termux" ]]; then
        echo "termux"
    elif grep -qi microsoft /proc/version 2>/dev/null; then
        echo "wsl"
    elif [[ -f /.dockerenv ]]; then
        echo "docker"
    else
        echo "linux"
    fi
}

detect_distro() {
    if [[ -f /etc/os-release ]]; then
        grep "^ID=" /etc/os-release | cut -d= -f2 | tr -d '"'
    else
        echo "unknown"
    fi
}

detect_pkg_manager() {
    if command -v apt-get &>/dev/null; then
        echo "apt"
    elif command -v dnf &>/dev/null; then
        echo "dnf"
    elif command -v pacman &>/dev/null; then
        echo "pacman"
    elif command -v zypper &>/dev/null; then
        echo "zypper"
    elif command -v apk &>/dev/null; then
        echo "apk"
    elif command -v pkg &>/dev/null; then
        echo "pkg"
    else
        echo "unknown"
    fi
}

# Export functions for use in other scripts
export -f detect_os detect_distro detect_pkg_manager
EOF
    
    chmod +x "$DOTFILES_DIR/scripts/detect/platform.sh"
    log_success "Created platform detection script"
    
    # Create command existence checker
    cat > "$DOTFILES_DIR/scripts/utils/commands.sh" << 'EOF'
#!/usr/bin/env bash
# Command utility functions

command_exists() {
    command -v "$1" &>/dev/null
}

require_command() {
    local cmd="$1"
    local package="${2:-$cmd}"
    
    if ! command_exists "$cmd"; then
        echo "Required command '$cmd' not found."
        echo "Install it with: pkg_install $package"
        return 1
    fi
}

# Export functions
export -f command_exists require_command
EOF
    
    chmod +x "$DOTFILES_DIR/scripts/utils/commands.sh"
    log_success "Created command utilities"
}

# ===== Create README =====
create_documentation() {
    log_stage "Creating Documentation"
    
    cat > "$DOTFILES_DIR/README.md" << 'EOF'
# Portable Linux Environment - Stage 1 Foundation

A modular, cross-platform development environment configuration system.

## Quick Start

```bash
git clone https://github.com/yourusername/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

## Current Stage: 1 - Foundation Layer

### Completed Features
- ✅ Cross-platform detection (Linux, WSL, Termux, Containers)
- ✅ Package manager abstraction
- ✅ Repository structure
- ✅ Basic Git configuration
- ✅ Essential tool installation

### Platform Support
- **Termux** (Android)
- **Ubuntu/Debian** and derivatives
- **Fedora/RHEL** and derivatives
- **Arch Linux** and derivatives
- **openSUSE**
- **Alpine Linux**
- **WSL** (Windows Subsystem for Linux)

### Repository Structure
```
dotfiles/
├── config/          # Configuration files
│   ├── git/        # Git configuration
│   ├── shell/      # Shell configurations
│   └── tmux/       # Tmux configuration
├── scripts/         # Utility scripts
│   ├── detect/     # Platform detection
│   ├── install/    # Installation scripts
│   └── utils/      # Helper utilities
├── docs/           # Documentation
└── backups/        # Backup storage
```

## Next Steps

Stage 2 will introduce:
- Nushell configuration
- Starship prompt
- Advanced shell integration

## Contributing

Feel free to fork and customize for your needs!
EOF
    
    log_success "Created README.md"
}

# ===== Stage Marker Management =====
mark_stage_complete() {
    echo "$CURRENT_STAGE" > "$STAGE_MARKER"
    log_success "Stage $CURRENT_STAGE marked as complete"
}

check_stage_status() {
    if [[ -f "$STAGE_MARKER" ]]; then
        local completed_stage=$(cat "$STAGE_MARKER")
        log_info "Previously completed stage: $completed_stage"
        
        if [[ "$completed_stage" -ge "$CURRENT_STAGE" ]]; then
            log_warning "Stage $CURRENT_STAGE already completed. Run with --force to reinstall."
            [[ "${1:-}" != "--force" ]] && exit 0
        fi
    fi
}

# ===== Main Installation Function =====
main() {
    log_stage "Portable Linux Environment - Stage 1: Foundation Layer"
    
    # Check if already completed
    check_stage_status "${1:-}"
    
    # Detect platform
    detect_platform
    
    # Update package repositories
    pkg_update
    
    # Install essential tools
    install_essential_tools
    
    # Create repository structure
    create_repository_structure
    
    # Setup basic git
    setup_basic_git
    
    # Create helper scripts
    create_helper_scripts
    
    # Create documentation
    create_documentation
    
    # Initialize git repository if not already
    if [[ ! -d "$DOTFILES_DIR/.git" ]]; then
        cd "$DOTFILES_DIR"
        git init
        git add .
        git commit -m "Initial commit: Stage 1 Foundation"
        log_success "Initialized git repository"
    fi
    
    # Mark stage as complete
    mark_stage_complete
    
    # Final summary
    log_stage "Stage 1 Complete! 🎉"
    echo -e "${GREEN}Foundation layer successfully installed!${NC}"
    echo -e "\nNext steps:"
    echo -e "1. Review and customize configurations in: ${BLUE}$DOTFILES_DIR${NC}"
    echo -e "2. Commit your changes: ${YELLOW}cd $DOTFILES_DIR && git add -A && git commit${NC}"
    echo -e "3. When ready, proceed to Stage 2: ${PURPLE}./stage2-install.sh${NC}"
    echo -e "\nYour platform: ${BLUE}$PLATFORM${NC} | Package manager: ${BLUE}$PKG_MANAGER${NC}"
}

# ===== Script Entry Point =====
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi