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
