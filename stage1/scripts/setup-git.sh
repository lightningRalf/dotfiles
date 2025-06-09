#!/usr/bin/env bash
#
# Git Configuration Setup - Stage 1
# Handles personalization of git configuration

set -euo pipefail

# Colors
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $1"; }

setup_git_config() {
    log_info "Setting up Git configuration..."
    
    # Copy base configuration
    cp "$DOTFILES_DIR/stage1/configs/git/gitconfig" "$HOME/.gitconfig"
    log_success "Base Git configuration installed"
    
    # Check if user configuration already exists
    if git config --global user.name &>/dev/null && git config --global user.email &>/dev/null; then
        log_info "Git user configuration already exists:"
        echo "  Name:  $(git config --global user.name)"
        echo "  Email: $(git config --global user.email)"
        return 0
    fi
    
    # Prompt for user information
    log_warning "Git user configuration required"
    
    read -p "Enter your full name for Git commits: " git_name
    read -p "Enter your email for Git commits: " git_email
    
    # Set user configuration
    git config --global user.name "$git_name"
    git config --global user.email "$git_email"
    
    log_success "Git user configuration set"
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
    setup_git_config
fi