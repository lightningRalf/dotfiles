#!/usr/bin/env bash
# Platform Detection Service Layer - Idempotent Implementation
# Handles multiple source operations without variable conflicts

# ═══════════════════════════════════════════════════════════════════════════════
# Service Configuration - Idempotent Declarations
# ═══════════════════════════════════════════════════════════════════════════════

# Only declare if not already set (idempotent pattern)
if [[ -z "${PLATFORM_CACHE:-}" ]]; then
    PLATFORM_CACHE="${DOTFILES_DIR:-$HOME/dotfiles}/.platform"
fi

# Alternative: Use declare without readonly for re-sourceable scripts
declare PLATFORM_CACHE="${PLATFORM_CACHE:-${DOTFILES_DIR:-$HOME/dotfiles}/.platform}"

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
# Cache Management Functions - With Proper Quoting
# ═══════════════════════════════════════════════════════════════════════════════

save_platform_info() {
    local cache_file="${1:-$PLATFORM_CACHE}"
    
    # Ensure directory exists
    mkdir -p "$(dirname "$cache_file")"
    
    # Generate with proper quoting for all values
    cat > "$cache_file" << EOF
# Platform detection cache - generated $(date -u +"%Y-%m-%d %H:%M:%S UTC")
PLATFORM="$(detect_os)"
DISTRO="$(detect_distro)"
PKG_MANAGER="$(detect_pkg_manager)"
ARCH="$(uname -m)"
KERNEL="$(uname -r)"
DETECTED="$(date -u +"%Y-%m-%d %H:%M:%S UTC")"
EOF
    
    # Validate generated file syntax
    if ! bash -n "$cache_file" 2>/dev/null; then
        echo "Error: Generated platform file has syntax errors" >&2
        return 1
    fi
    
    return 0
}

load_platform_info() {
    local cache_file="${1:-$PLATFORM_CACHE}"
    
    if [[ -f "$cache_file" ]]; then
        # Source with error handling
        if ! source "$cache_file" 2>/dev/null; then
            echo "Warning: Cache file corrupted, using dynamic detection" >&2
            # Fallback to dynamic detection
            export PLATFORM="$(detect_os)"
            export DISTRO="$(detect_distro)"
            export PKG_MANAGER="$(detect_pkg_manager)"
            export ARCH="$(uname -m)"
            export KERNEL="$(uname -r)"
            export DETECTED="dynamic"
        fi
        return 0
    else
        # Dynamic detection fallback
        export PLATFORM="$(detect_os)"
        export DISTRO="$(detect_distro)"
        export PKG_MANAGER="$(detect_pkg_manager)"
        export ARCH="$(uname -m)"
        export KERNEL="$(uname -r)"
        export DETECTED="dynamic"
        
        return 0
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# Service Operations
# ═══════════════════════════════════════════════════════════════════════════════

get_platform() {
    load_platform_info
    verify_platform
}

verify_platform() {
    local required_vars=(PLATFORM PKG_MANAGER ARCH)
    local missing=()
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing+=("$var")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "Error: Missing platform variables: ${missing[*]}" >&2
        return 1
    fi
    
    return 0
}

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
# Guard Against Multiple Sourcing
# ═══════════════════════════════════════════════════════════════════════════════

# Mark as loaded to prevent duplicate exports
if [[ -z "${_PLATFORM_SERVICE_LOADED:-}" ]]; then
    _PLATFORM_SERVICE_LOADED=1
    
    # Export functions only once
    export -f detect_os detect_distro detect_pkg_manager
    export -f save_platform_info load_platform_info
    export -f get_platform verify_platform show_platform
    export -f pkg_update pkg_install
fi