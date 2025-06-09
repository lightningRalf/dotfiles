#!/usr/bin/env bash
# Platform Detection Service Layer
# Provides comprehensive platform detection and caching functionality

# ═══════════════════════════════════════════════════════════════════════════════
# Service Configuration
# ═══════════════════════════════════════════════════════════════════════════════

readonly PLATFORM_CACHE="${DOTFILES_DIR:-$HOME/dotfiles}/.platform"

# ═══════════════════════════════════════════════════════════════════════════════
# Core Detection Functions
# ═══════════════════════════════════════════════════════════════════════════════

detect_os() {
    if [[ -d "/data/data/com.termux" ]]; then
        echo "termux"
    elif grep -qi microsoft /proc/version 2>/dev/null; then
        if grep -qi "microsoft-standard-WSL2" /proc/version 2>/dev/null; then
            echo "wsl2"
        else
            echo "wsl1"
        fi
    elif [[ -f /.dockerenv ]] || grep -q 'docker\|lxc' /proc/1/cgroup 2>/dev/null; then
        echo "container"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        echo "linux"
    fi
}

detect_distro() {
    local os=$(detect_os)
    
    case "$os" in
        termux)
            echo "termux"
            ;;
        macos)
            echo "macos"
            ;;
        container|wsl*)
            # Even in containers/WSL, try to detect the base distro
            if [[ -f /etc/os-release ]]; then
                grep "^ID=" /etc/os-release | cut -d= -f2 | tr -d '"'
            else
                echo "unknown"
            fi
            ;;
        *)
            if [[ -f /etc/os-release ]]; then
                grep "^ID=" /etc/os-release | cut -d= -f2 | tr -d '"'
            else
                echo "unknown"
            fi
            ;;
    esac
}

detect_pkg_manager() {
    # Check in order of likelihood/preference
    if command -v pkg &>/dev/null && [[ -d "/data/data/com.termux" ]]; then
        echo "pkg"
    elif command -v apt-get &>/dev/null; then
        echo "apt"
    elif command -v dnf &>/dev/null; then
        echo "dnf"
    elif command -v yum &>/dev/null; then
        echo "yum"
    elif command -v pacman &>/dev/null; then
        echo "pacman"
    elif command -v zypper &>/dev/null; then
        echo "zypper"
    elif command -v apk &>/dev/null; then
        echo "apk"
    elif command -v brew &>/dev/null; then
        echo "brew"
    else
        echo "unknown"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# Cache Management Functions
# ═══════════════════════════════════════════════════════════════════════════════

save_platform_info() {
    local cache_file="${1:-$PLATFORM_CACHE}"
    
    # Ensure directory exists
    mkdir -p "$(dirname "$cache_file")"
    
    # Perform detection and save
    cat > "$cache_file" << EOF
# Platform detection cache - generated $(date -u +"%Y-%m-%d %H:%M:%S UTC")
PLATFORM=$(detect_os)
DISTRO=$(detect_distro)
PKG_MANAGER=$(detect_pkg_manager)
ARCH=$(uname -m)
KERNEL=$(uname -r)
DETECTED=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
EOF
    
    return 0
}

load_platform_info() {
    local cache_file="${1:-$PLATFORM_CACHE}"
    
    if [[ -f "$cache_file" ]]; then
        # Load cached values
        source "$cache_file"
        return 0
    else
        # Fallback: perform detection dynamically
        export PLATFORM=$(detect_os)
        export DISTRO=$(detect_distro)
        export PKG_MANAGER=$(detect_pkg_manager)
        export ARCH=$(uname -m)
        export KERNEL=$(uname -r)
        export DETECTED="dynamic"
        
        return 0
    fi
}

clear_platform_cache() {
    local cache_file="${1:-$PLATFORM_CACHE}"
    
    if [[ -f "$cache_file" ]]; then
        rm -f "$cache_file"
        return 0
    fi
    
    return 1
}

# ═══════════════════════════════════════════════════════════════════════════════
# Service Operations
# ═══════════════════════════════════════════════════════════════════════════════

# Detect platform and export variables (dynamic mode)
detect_and_export() {
    export PLATFORM=$(detect_os)
    export DISTRO=$(detect_distro)
    export PKG_MANAGER=$(detect_pkg_manager)
    export ARCH=$(uname -m)
    export KERNEL=$(uname -r)
    export DETECTED="dynamic"
}

# Get current platform info (uses cache if available)
get_platform() {
    load_platform_info
    verify_platform
}

# Verify all required platform variables are set
verify_platform() {
    local required_vars=(PLATFORM PKG_MANAGER ARCH)
    local missing=()
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var}" ]]; then
            missing+=("$var")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "Error: Missing platform variables: ${missing[*]}" >&2
        return 1
    fi
    
    return 0
}

# Display current platform information
show_platform() {
    get_platform || return 1
    
    echo "Platform Information:"
    echo "  OS:       ${PLATFORM}"
    echo "  Distro:   ${DISTRO}"
    echo "  Package:  ${PKG_MANAGER}"
    echo "  Arch:     ${ARCH}"
    echo "  Kernel:   ${KERNEL}"
    echo "  Detected: ${DETECTED}"
}

# ═══════════════════════════════════════════════════════════════════════════════
# Package Manager Abstractions
# ═══════════════════════════════════════════════════════════════════════════════

pkg_update() {
    get_platform || return 1
    
    case "$PKG_MANAGER" in
        apt)
            sudo apt-get update -qq
            ;;
        dnf|yum)
            sudo ${PKG_MANAGER} check-update -q || true
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
        pkg)
            pkg update -y
            ;;
        brew)
            brew update
            ;;
        *)
            echo "Warning: Package manager update not supported for: $PKG_MANAGER" >&2
            return 1
            ;;
    esac
}

pkg_install() {
    get_platform || return 1
    
    local packages="$@"
    [[ -z "$packages" ]] && return 1
    
    case "$PKG_MANAGER" in
        apt)
            sudo apt-get install -y -qq $packages
            ;;
        dnf|yum)
            sudo ${PKG_MANAGER} install -y -q $packages
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
        pkg)
            pkg install -y $packages
            ;;
        brew)
            brew install $packages
            ;;
        *)
            echo "Error: Package installation not supported for: $PKG_MANAGER" >&2
            return 1
            ;;
    esac
}

# ═══════════════════════════════════════════════════════════════════════════════
# Export Service Functions
# ═══════════════════════════════════════════════════════════════════════════════

# Detection functions
export -f detect_os detect_distro detect_pkg_manager

# Cache management
export -f save_platform_info load_platform_info clear_platform_cache

# Service operations
export -f detect_and_export get_platform verify_platform show_platform

# Package manager abstractions
export -f pkg_update pkg_install