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
