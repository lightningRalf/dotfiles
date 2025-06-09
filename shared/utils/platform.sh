#!/usr/bin/env bash
# Platform detection utilities - Supporting both dynamic and cached patterns

# ═══════════════════════════════════════════════════════════════════════════════
# Dynamic Detection Functions
# ═══════════════════════════════════════════════════════════════════════════════

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

# ═══════════════════════════════════════════════════════════════════════════════
# Cached Platform Loading Function
# ═══════════════════════════════════════════════════════════════════════════════

load_platform_info() {
    local platform_file="${DOTFILES_DIR:-$HOME/dotfiles}/.platform"
    
    if [[ -f "$platform_file" ]]; then
        # Source the cached platform information
        source "$platform_file"
        return 0
    else
        # Fallback: Perform detection dynamically
        echo "Warning: No cached platform info found, detecting dynamically..." >&2
        
        # Export detected values
        export PLATFORM=$(detect_os)
        export DISTRO=$(detect_distro)
        export PKG_MANAGER=$(detect_pkg_manager)
        export ARCH=$(uname -m)
        
        return 0
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# Utility Functions
# ═══════════════════════════════════════════════════════════════════════════════

# Save current platform detection to cache file
save_platform_info() {
    local platform_file="${DOTFILES_DIR:-$HOME/dotfiles}/.platform"
    
    cat > "$platform_file" << EOF
PLATFORM=$(detect_os)
DISTRO=$(detect_distro)
PKG_MANAGER=$(detect_pkg_manager)
ARCH=$(uname -m)
KERNEL=$(uname -r)
DETECTED=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
EOF
}

# Verify platform information is available
verify_platform() {
    local required_vars=(PLATFORM PKG_MANAGER)
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var}" ]]; then
            echo "Error: Required variable $var not set" >&2
            return 1
        fi
    done
    
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# Export Functions
# ═══════════════════════════════════════════════════════════════════════════════

export -f detect_os detect_distro detect_pkg_manager
export -f load_platform_info save_platform_info verify_platform