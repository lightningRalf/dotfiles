#!/usr/bin/env bash
#
# Stage 1: Foundation Layer - Minimal, Focused Implementation
# 
# Scope: ONLY platform detection, essential tools, and base structure
# Philosophy: Each stage is self-contained and independent

set -euo pipefail

# ===== Configuration =====
readonly DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
readonly STAGE_MARKER="$HOME/.dotfiles-stage1-complete"
readonly VERSION="1.0.0"

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

# ===== Platform Detection =====
detect_platform() {
    log_info "Detecting platform..."
    
    local platform="linux"
    local pkg_manager="unknown"
    
    # Platform detection
    if [[ -d "/data/data/com.termux" ]]; then
        platform="termux"
        pkg_manager="pkg"
    elif grep -qi microsoft /proc/version 2>/dev/null; then
        platform="wsl"
    elif [[ -f /.dockerenv ]]; then
        platform="container"
    fi
    
    # Package manager detection
    if [[ "$pkg_manager" == "unknown" ]]; then
        if command -v apt-get &>/dev/null; then
            pkg_manager="apt"
        elif command -v dnf &>/dev/null; then
            pkg_manager="dnf"
        elif command -v pacman &>/dev/null; then
            pkg_manager="pacman"
        elif command -v apk &>/dev/null; then
            pkg_manager="apk"
        fi
    fi
    
    # Save platform info
    cat > "$DOTFILES_DIR/.platform" << EOF
PLATFORM=$platform
PKG_MANAGER=$pkg_manager
ARCH=$(uname -m)
KERNEL=$(uname -r)
DETECTED=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
EOF
    
    export PLATFORM="$platform"
    export PKG_MANAGER="$pkg_manager"
    
    log_success "Platform: $PLATFORM | Package Manager: $PKG_MANAGER"
}

# ===== Create Base Structure =====
create_base_structure() {
    log_info "Creating base directory structure..."
    
    # Minimal structure - stages manage their own subdirectories
    local dirs=(
        "stage1"
        "stage2"
        "stage3"
        "stage4"
        "stage5"
        "shared/utils"
        "docs"
    )
    
    for dir in "${dirs[@]}"; do
        mkdir -p "$DOTFILES_DIR/$dir"
    done
    
    log_success "Base structure created"
}

# ===== Install Foundation Tools =====
install_foundation_tools() {
    log_info "Installing foundation tools..."
    
    # Only the absolute essentials
    local tools=""
    
    case "$PKG_MANAGER" in
        apt)
            sudo apt-get update -qq
            tools="git curl build-essential"
            sudo apt-get install -y -qq $tools
            ;;
        dnf)
            sudo dnf check-update -q || true
            tools="git curl @development-tools"
            sudo dnf install -y -q $tools
            ;;
        pacman)
            sudo pacman -Sy --noconfirm
            tools="git curl base-devel"
            sudo pacman -S --noconfirm --needed $tools
            ;;
        pkg)
            pkg update -y
            tools="git curl"
            pkg install -y $tools
            ;;
        *)
            log_warning "Manual tool installation required for: $PKG_MANAGER"
            ;;
    esac
    
    log_success "Foundation tools installed"
}

# ===== Create Stage Documentation =====
create_documentation() {
    log_info "Creating documentation..."
    
    # Main README
    cat > "$DOTFILES_DIR/README.md" << 'EOF'
# Portable Development Environment

A modular, staged approach to system configuration.

## Philosophy

- **Stage Independence**: Each stage is self-contained
- **Static Configuration**: All configs exist as files, not generated code
- **Progressive Enhancement**: Each stage builds upon the previous

## Five-Stage Architecture

1. **Foundation**: Platform detection and essential tools (git, curl)
2. **Shell Evolution**: Modern shell with Nushell, Starship, Atuin
3. **CLI Modernization**: Enhanced replacements for Unix tools  
4. **Development Ecosystem**: Language managers and development tools
5. **Integration & Polish**: Automation and professional finishing

## Installation

```bash
# Stage 1: Foundation
./stage1/install.sh

# Stage 2: Shell Evolution  
./stage2/install.sh

# Continue with subsequent stages...
```

Each stage can be installed independently once its prerequisites are met.

## Structure

```
dotfiles/
├── stage1/     # Foundation installer
├── stage2/     # Shell evolution (configs + installer)
├── stage3/     # CLI tools (configs + installer)
├── stage4/     # Development tools (configs + installer)
├── stage5/     # Integration (configs + installer)
├── shared/     # Utilities shared across stages
└── docs/       # Additional documentation
```
EOF

    # Stage 1 specific docs
    cat > "$DOTFILES_DIR/stage1/README.md" << 'EOF'
# Stage 1: Foundation Layer

## Purpose

Establishes the minimal foundation required for all subsequent stages:
- Platform detection
- Essential tool installation (git, curl, build tools)
- Basic directory structure

## What This Stage Does NOT Do

- Install any user-facing tools
- Create any configuration files
- Make any shell modifications

## Post-Installation

After Stage 1:
1. Review platform detection: `cat ~/dotfiles/.platform`
2. Proceed to Stage 2 when ready

## Files Created

- `.platform` - Platform detection results
- Base directory structure for future stages
EOF

    log_success "Documentation created"
}

# ===== Create Shared Utilities =====
create_shared_utilities() {
    log_info "Creating shared utilities..."
    
    # Platform detection utility
    cat > "$DOTFILES_DIR/shared/utils/platform.sh" << 'EOF'
#!/usr/bin/env bash
# Shared platform detection utilities

load_platform_info() {
    local platform_file="${DOTFILES_DIR:-$HOME/dotfiles}/.platform"
    if [[ -f "$platform_file" ]]; then
        source "$platform_file"
    else
        echo "Error: Platform info not found. Run stage1/install.sh first."
        return 1
    fi
}

# Make function available
export -f load_platform_info
EOF
    
    chmod +x "$DOTFILES_DIR/shared/utils/platform.sh"
    log_success "Shared utilities created"
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
    
    # Ensure base directory exists
    mkdir -p "$DOTFILES_DIR"
    cd "$DOTFILES_DIR"
    
    # Core operations
    detect_platform
    create_base_structure
    install_foundation_tools
    create_documentation
    create_shared_utilities
    
    # Initialize git repo
    if [[ ! -d .git ]]; then
        git init
        git add .
        git commit -m "Stage 1: Foundation layer complete"
        log_success "Git repository initialized"
    fi
    
    # Mark complete
    date -u +"%Y-%m-%d %H:%M:%S UTC" > "$STAGE_MARKER"
    
    # Summary
    echo -e "\n${GREEN}Stage 1 Complete!${NC}\n"
    echo "Foundation established. You may now proceed to:"
    echo -e "  ${BLUE}./stage2/install.sh${NC} - Shell Evolution"
    echo -e "\nPlatform info saved to: ${YELLOW}$DOTFILES_DIR/.platform${NC}"
}

# Execute
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi