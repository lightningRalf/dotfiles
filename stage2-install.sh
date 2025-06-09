#!/usr/bin/env bash
#
# Stage 2: Shell Evolution Installer
# Transform your command line experience with modern shells and tools
#
# This stage implements:
# 1. Nushell as primary shell with intelligent configuration
# 2. Starship cross-shell prompt with contextual information
# 3. Enhanced navigation with zoxide
# 4. Seamless integration with existing shells

set -euo pipefail

# ===== Configuration Variables =====
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
CONFIG_DIR="$HOME/.config"
STAGE_MARKER="$HOME/.dotfiles-stage"
CURRENT_STAGE=2
REQUIRED_STAGE=1

# Load Stage 1 utilities
source "$DOTFILES_DIR/scripts/detect/platform.sh" 2>/dev/null || {
    echo "Error: Stage 1 platform detection not found. Please complete Stage 1 first."
    exit 1
}

# ===== Color Definitions =====
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# ===== Enhanced Logging Functions =====
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1" >&2; }
log_stage() { echo -e "\n${PURPLE}━━━ $1 ━━━${NC}\n"; }
log_substage() { echo -e "\n${CYAN}── $1 ──${NC}"; }

# ===== Stage Verification =====
verify_prerequisites() {
    log_stage "Verifying Prerequisites"
    
    # Check Stage 1 completion
    if [[ ! -f "$STAGE_MARKER" ]]; then
        log_error "Stage 1 not completed. Please run stage1-install.sh first."
        exit 1
    fi
    
    local completed_stage=$(cat "$STAGE_MARKER")
    if [[ "$completed_stage" -lt "$REQUIRED_STAGE" ]]; then
        log_error "Stage $REQUIRED_STAGE required. Current stage: $completed_stage"
        exit 1
    fi
    
    # Verify platform detection
    PLATFORM=$(detect_os)
    PKG_MANAGER=$(detect_pkg_manager)
    
    log_success "Prerequisites verified"
    log_info "Platform: $PLATFORM | Package Manager: $PKG_MANAGER"
}

# ===== Rust Installation =====
install_rust_toolchain() {
    log_substage "Installing Rust Toolchain"
    
    if command -v rustc &>/dev/null; then
        log_info "Rust already installed, updating..."
        rustup update stable
    else
        log_info "Installing Rust via rustup..."
        
        # Download and run rustup installer
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
        
        # Source cargo environment
        source "$HOME/.cargo/env"
    fi
    
    # Verify installation
    if command -v cargo &>/dev/null; then
        local rust_version=$(rustc --version | cut -d' ' -f2)
        log_success "Rust installed: $rust_version"
    else
        log_error "Rust installation failed"
        return 1
    fi
}

# ===== Nushell Installation =====
install_nushell() {
    log_substage "Installing Nushell"
    
    # Platform-specific installation
    case "$PKG_MANAGER" in
        pkg)  # Termux has nushell in repos
            pkg install -y nushell
            ;;
        *)
            # Use cargo for most platforms
            if ! command -v nu &>/dev/null; then
                log_info "Building Nushell from source (this may take a while)..."
                cargo install nu --locked
            else
                log_info "Nushell already installed"
            fi
            ;;
    esac
    
    # Verify installation
    if command -v nu &>/dev/null; then
        local nu_version=$(nu --version 2>/dev/null || echo "unknown")
        log_success "Nushell installed: $nu_version"
    else
        log_error "Nushell installation failed"
        return 1
    fi
}

# ===== Starship Installation =====
install_starship() {
    log_substage "Installing Starship Prompt"
    
    if ! command -v starship &>/dev/null; then
        log_info "Installing Starship..."
        
        # Platform-specific installation
        case "$PKG_MANAGER" in
            pkg)  # Termux
                pkg install -y starship
                ;;
            *)
                # Universal installer
                curl -sS https://starship.rs/install.sh | sh -s -- -y
                ;;
        esac
    else
        log_info "Starship already installed"
    fi
    
    # Verify installation
    if command -v starship &>/dev/null; then
        local starship_version=$(starship --version | head -1 | cut -d' ' -f2)
        log_success "Starship installed: $starship_version"
    else
        log_error "Starship installation failed"
        return 1
    fi
}

# ===== Zoxide Installation =====
install_zoxide() {
    log_substage "Installing Zoxide"
    
    if ! command -v zoxide &>/dev/null; then
        log_info "Installing Zoxide..."
        
        case "$PKG_MANAGER" in
            pkg)  # Termux
                pkg install -y zoxide
                ;;
            *)
                # Install via cargo
                cargo install zoxide --locked
                ;;
        esac
    else
        log_info "Zoxide already installed"
    fi
    
    # Verify installation
    if command -v zoxide &>/dev/null; then
        local zoxide_version=$(zoxide --version | cut -d' ' -f2)
        log_success "Zoxide installed: $zoxide_version"
    else
        log_warning "Zoxide installation failed (non-critical)"
    fi
}

# ===== Configuration Creation =====
create_nushell_config() {
    log_substage "Creating Nushell Configuration"
    
    # Create config directory
    local nu_config_dir="$CONFIG_DIR/nushell"
    mkdir -p "$nu_config_dir/scripts"
    
    # Create env.nu
    cat > "$nu_config_dir/env.nu" << 'EOF'
# Nushell Environment Configuration
# Stage 2 - Foundation Setup

# Directories
$env.CONFIG_DIR = $"($env.HOME)/.config"
$env.DOTFILES_DIR = $"($env.HOME)/dotfiles"

# Path configuration
let paths = [
    $"($env.HOME)/.local/bin"
    $"($env.HOME)/.cargo/bin"
    "/usr/local/bin"
    "/usr/bin"
    "/bin"
]

# Add platform-specific paths
let platform_paths = if ($"($env.HOME)/.termux" | path exists) {
    ["/data/data/com.termux/files/usr/bin"]
} else {
    []
}

$env.PATH = ($paths | append $platform_paths | append $env.PATH | uniq)

# Editor configuration
$env.EDITOR = if (which nvim | complete).exit_code == 0 { "nvim" } else { "nano" }
$env.VISUAL = $env.EDITOR

# Starship configuration
$env.STARSHIP_SHELL = "nu"
$env.STARSHIP_CONFIG = $"($env.CONFIG_DIR)/starship.toml"

# Create config structure
def create_default_config [] {
    {
        show_banner: false
        edit_mode: "vi"
        
        completions: {
            case_sensitive: false
            quick: true
            partial: true
            algorithm: "fuzzy"
        }
        
        history: {
            max_size: 10000
            sync_on_enter: true
            file_format: "sqlite"
        }
        
        cursor_shape: {
            vi_insert: "line"
            vi_normal: "block"
        }
    }
}

$env.config = (create_default_config)
EOF
    
    # Create config.nu
    cat > "$nu_config_dir/config.nu" << 'EOF'
# Nushell Configuration
# Stage 2 - Core Setup

# Source environment
source ~/.config/nushell/env.nu

# Basic aliases for common operations
alias ll = ls -la
alias la = ls -a
alias cls = clear
alias .. = cd ..
alias ... = cd ../..

# Git aliases
alias gs = git status
alias ga = git add
alias gc = git commit
alias gp = git push
alias gl = git pull

# Navigation helpers
def --env cdd [] {
    cd $env.DOTFILES_DIR
}

# Platform-specific configuration
let is_termux = ($"($env.HOME)/.termux" | path exists)

# Source integration scripts
let scripts_dir = $"($env.CONFIG_DIR)/nushell/scripts"

# Starship initialization
if (which starship | complete).exit_code == 0 {
    mkdir $scripts_dir
    starship init nu | save -f $"($scripts_dir)/starship.nu"
    source $"($scripts_dir)/starship.nu"
}

# Zoxide initialization
if (which zoxide | complete).exit_code == 0 {
    zoxide init nushell | save -f $"($scripts_dir)/zoxide.nu"
    source $"($scripts_dir)/zoxide.nu"
}

# Welcome message
if $env.TERM != "dumb" {
    print $"(ansi green_bold)Welcome to Nushell!(ansi reset)"
    print $"Stage 2 configuration loaded. Platform: (if $is_termux { "Termux" } else { "Linux" })"
    print ""
}
EOF
    
    log_success "Nushell configuration created"
}

create_starship_config() {
    log_substage "Creating Starship Configuration"
    
    # Create simplified but powerful config
    cat > "$CONFIG_DIR/starship.toml" << 'EOF'
# Starship Configuration - Stage 2
# A clean, informative prompt for all shells

"$schema" = 'https://starship.rs/config-schema.json'

format = """
[<](color_orange)\
$os\
$username\
[|](bg:color_yellow fg:color_orange)\
$directory\
[|](fg:color_yellow bg:color_aqua)\
$git_branch\
$git_status\
[|](fg:color_aqua bg:color_blue)\
$c\
$cpp\
$rust\
$golang\
$nodejs\
$php\
$java\
$kotlin\
$haskell\
$python\
[|](fg:color_blue bg:color_bg3)\
$docker_context\
$conda\
$pixi\
[|](fg:color_bg3 bg:color_bg1)\
$time\
[>](fg:color_bg1)\
$line_break$character"""

palette = 'gruvbox_dark'

[palettes.gruvbox_dark]
color_fg0 = '#fbf1c7'
color_bg1 = '#3c3836'
color_bg3 = '#665c54'
color_blue = '#458588'
color_aqua = '#689d6a'
color_green = '#98971a'
color_orange = '#d65d0e'
color_purple = '#b16286'
color_red = '#cc241d'
color_yellow = '#d79921'

# Prompt character changes based on success/failure
[character]
disabled = false
success_symbol = "[➜](bold green)"
error_symbol = "[✗](bold red)"
vicmd_symbol = "[⮜](bold yellow)"
vimcmd_replace_one_symbol = '[r](bold fg:color_purple)'
vimcmd_replace_symbol = '[r](bold fg:color_purple)'
vimcmd_visual_symbol = '[v](bold fg:color_yellow)'

[os]
disabled = false
style = "bg:color_orange fg:color_fg0"

[os.symbols]
Windows = "WIN"
Ubuntu = "UBU"
SUSE = "SUSE"
Raspbian = "PI"
Mint = "MINT"
Macos = "MAC"
Manjaro = "MANJARO"
Linux = "LINUX"
Gentoo = "GENTOO"
Fedora = "FEDORA"
Alpine = "ALPINE"
Amazon = "AWS"
Android = "ANDROID"
Arch = "ARCH"
Artix = "ARTIX"
EndeavourOS = "ENDEAVOUR"
CentOS = "CENTOS"
Debian = "DEBIAN"
Redhat = "RHEL"
RedHatEnterprise = "RHEL"
Pop = "POP"

[username]
show_always = true
style_user = "bg:color_orange fg:color_fg0"
style_root = "bg:color_orange fg:color_fg0"
format = '[ $user ]($style)'

[hostname]
ssh_only = true
format = "[@$hostname]($style) "
style = "bold green"

[directory]
style = "fg:color_fg0 bg:color_yellow"
format = "[ $path ]($style)"
truncation_length = 3
truncation_symbol = ".../"

[directory.substitutions]
"Documents" = "[Doc] "
"Downloads" = "[Dwn] "
"Music" = "[Mus] "
"Pictures" = "[Pic] "
"Developer" = "[Dev] "

[git_commit]
commit_hash_length = 4
tag_symbol = '🔖 '

[git_branch]
symbol = '🌱 '
truncation_length = 4
truncation_symbol = ''
ignore_branches = ['master', 'main']
style = "bg:color_aqua"
format = '[[ $symbol $branch ](fg:color_fg0 bg:color_aqua)]($style)'

[git_state]
format = '[\($state( $progress_current of $progress_total)\)]($style) '
cherry_pick = '[🍒 PICKING](bold red)'

[git_status]
conflicted = '🏳'
up_to_date = '✓'
untracked = '🤷'
stashed = '📦'
modified = '📝'
staged = '[++\($count\)](green)'
renamed = '👅'
deleted = '🗑'
ahead = '⇡${count}'
diverged = '⇕⇡${ahead_count}⇣${behind_count}'
behind = '⇣${count}'
windows_starship = '/mnt/c/Users/mjpa/scoop/apps/starship/current/starship.exe'
style = "bg:color_aqua"
format = '[[($all_status$ahead_behind )](fg:color_fg0 bg:color_aqua)]($style)'


[nodejs]
symbol = "⬢ "
style = "bg:color_blue"
format = '[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)'

[c]
symbol = "C"
style = "bg:color_blue"
format = '[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)'

[rust]
symbol = "🦀 "
style = "bg:color_blue"
format = '[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)'

[golang]
symbol = "go"
style = "bg:color_blue"
format = '[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)'

[php]
symbol = "php"
style = "bg:color_blue"
format = '[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)'

[java]
symbol = "java"
style = "bg:color_blue"
format = '[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)'

[kotlin]
symbol = "kt"
style = "bg:color_blue"
format = '[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)'

[haskell]
symbol = "hs"
style = "bg:color_blue"
format = '[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)'

[python]
symbol = "🐍 "
style = "bg:color_blue"
format = '[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)'

[docker_context]
symbol = "docker"
style = "bg:color_bg3"
format = '[[ $symbol( $context) ](fg:#83a598 bg:color_bg3)]($style)'

[conda]
style = "bg:color_bg3"
format = '[[ $symbol( $environment) ](fg:#83a598 bg:color_bg3)]($style)'

# Performance optimizations
[cmd_duration]
min_time = 2_000
format = "took [$duration]($style) "
style = "bold yellow"

[battery]
disabled = true

[time]
disabled = false
time_format = "%R"
style = "bg:color_bg1"
format = '[[ ⏰ $time ](fg:color_fg0 bg:color_bg1)]($style)'

[aws]
disabled = true

[gcloud]
disabled = true

[package]
disabled = true

[line_break]
disabled = false
EOF
    
    log_success "Starship configuration created"
}

# ===== Shell Integration Setup =====
setup_bash_integration() {
    log_substage "Setting up Bash Integration"
    
    local bashrc="$HOME/.bashrc"
    local marker="# === Stage 2: Shell Evolution ==="
    
    # Check if already integrated
    if grep -q "$marker" "$bashrc" 2>/dev/null; then
        log_info "Bash integration already configured"
        return
    fi
    
    # Backup existing .bashrc
    cp "$bashrc" "$DOTFILES_DIR/backups/bashrc.stage2.bak" 2>/dev/null || true
    
    # Add integration
    cat >> "$bashrc" << 'EOF'

# === Stage 2: Shell Evolution ===

# Starship prompt
if command -v starship &>/dev/null; then
    eval "$(starship init bash)"
fi

# Zoxide for smart navigation
if command -v zoxide &>/dev/null; then
    eval "$(zoxide init bash)"
fi

# Better command defaults
alias ls='ls --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Quick navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Nushell launcher
nu() {
    if command -v nu &>/dev/null; then
        exec $(command -v nu)
    else
        echo "Nushell not installed. Run stage2-install.sh to install."
    fi
}

# Add cargo to PATH if not already present
if [[ -d "$HOME/.cargo/bin" ]] && [[ ":$PATH:" != *":$HOME/.cargo/bin:"* ]]; then
    export PATH="$HOME/.cargo/bin:$PATH"
fi

# Platform-specific enhancements
if [[ -d "/data/data/com.termux" ]]; then
    # Termux-specific settings
    export TERMUX_HOME="/data/data/com.termux/files/home"
fi

EOF
    
    log_success "Bash integration configured"
}

setup_alternative_shells() {
    log_substage "Configuring Alternative Shell Support"
    
    # Zsh integration (if present)
    if [[ -f "$HOME/.zshrc" ]]; then
        local zshrc="$HOME/.zshrc"
        local marker="# === Stage 2: Shell Evolution ==="
        
        if ! grep -q "$marker" "$zshrc" 2>/dev/null; then
            cat >> "$zshrc" << 'EOF'

# === Stage 2: Shell Evolution ===

# Starship prompt
if command -v starship &>/dev/null; then
    eval "$(starship init zsh)"
fi

# Zoxide
if command -v zoxide &>/dev/null; then
    eval "$(zoxide init zsh)"
fi

# Nushell launcher
alias nu='exec nu'

# Cargo path
export PATH="$HOME/.cargo/bin:$PATH"

EOF
            log_success "Zsh integration configured"
        fi
    fi
    
    # Fish integration (if present)
    if [[ -d "$CONFIG_DIR/fish" ]]; then
        mkdir -p "$CONFIG_DIR/fish/conf.d"
        cat > "$CONFIG_DIR/fish/conf.d/stage2.fish" << 'EOF'
# Stage 2: Shell Evolution

# Starship
if command -v starship &>/dev/null
    starship init fish | source
end

# Zoxide
if command -v zoxide &>/dev/null
    zoxide init fish | source
end

# Path
set -gx PATH $HOME/.cargo/bin $PATH

EOF
        log_success "Fish integration configured"
    fi
}

# ===== Termux-Specific Setup =====
setup_termux_integration() {
    if [[ "$PLATFORM" != "termux" ]]; then
        return
    fi
    
    log_substage "Configuring Termux Integration"
    
    # Create properties file for better keyboard handling
    mkdir -p "$HOME/.termux"
    cat > "$HOME/.termux/termux.properties" << 'EOF'
# Better keyboard experience
extra-keys = [['ESC','TAB','CTRL','ALT','LEFT','RIGHT','UP','DOWN']]

# Use black theme
use-black-ui = true

# Vibrate on bell
bell-character = vibrate

EOF
    
    # Set Nushell as default shell
    if command -v nu &>/dev/null; then
        chsh -s $(command -v nu) 2>/dev/null || {
            log_warning "Could not set Nushell as default shell in Termux"
            log_info "You can manually run 'nu' to start Nushell"
        }
    fi
    
    log_success "Termux integration configured"
}

# ===== Testing and Verification =====
test_shell_integration() {
    log_substage "Testing Shell Integration"
    
    local tests_passed=0
    local tests_total=0
    
    # Test 1: Nushell startup
    ((tests_total++))
    if nu -c "print 'Nushell works!'" &>/dev/null; then
        log_success "Nushell startup test passed"
        ((tests_passed++))
    else
        log_warning "Nushell startup test failed"
    fi
    
    # Test 2: Starship in bash
    ((tests_total++))
    if bash -c "command -v starship && starship prompt" &>/dev/null; then
        log_success "Starship integration test passed"
        ((tests_passed++))
    else
        log_warning "Starship integration test failed"
    fi
    
    # Test 3: Zoxide functionality
    ((tests_total++))
    if command -v zoxide &>/dev/null && zoxide query --list &>/dev/null; then
        log_success "Zoxide test passed"
        ((tests_passed++))
    else
        log_warning "Zoxide test failed"
    fi
    
    # Test 4: Configuration files
    ((tests_total++))
    if [[ -f "$CONFIG_DIR/nushell/config.nu" ]] && [[ -f "$CONFIG_DIR/starship.toml" ]]; then
        log_success "Configuration files test passed"
        ((tests_passed++))
    else
        log_warning "Configuration files test failed"
    fi
    
    log_info "Tests passed: $tests_passed/$tests_total"
    
    if [[ $tests_passed -eq $tests_total ]]; then
        log_success "All integration tests passed!"
        return 0
    else
        log_warning "Some tests failed. Check the warnings above."
        return 1
    fi
}

# ===== Documentation Update =====
update_documentation() {
    log_substage "Updating Documentation"
    
    # Add Stage 2 completion to README
    cat >> "$DOTFILES_DIR/README.md" << 'EOF'

## Stage 2: Shell Evolution ✓

### Completed Features
- ✅ Nushell modern shell with structured data
- ✅ Starship cross-shell prompt
- ✅ Zoxide intelligent navigation
- ✅ Bash/Zsh/Fish integration
- ✅ Platform-specific optimizations

### New Commands Available
- `nu` - Launch Nushell (or auto-start if configured)
- `z <partial-path>` - Jump to frecent directories
- `cdd` - Go to dotfiles directory (in Nushell)

### Configuration Locations
- Nushell: `~/.config/nushell/`
- Starship: `~/.config/starship.toml`
- Shell integrations: `~/.bashrc`, `~/.zshrc`

### Quick Test
```bash
# Test Nushell
nu -c "sys | get host"

# Test Starship
starship prompt

# Test Zoxide
z dotfiles
```

EOF
    
    log_success "Documentation updated"
}

# ===== Main Installation Flow =====
main() {
    log_stage "Stage 2: Shell Evolution"
    
    # Verify prerequisites
    verify_prerequisites
    
    # Core installations
    log_stage "Installing Core Components"
    install_rust_toolchain || exit 1
    
    # Ensure cargo is in PATH for this session
    export PATH="$HOME/.cargo/bin:$PATH"
    
    install_nushell || exit 1
    install_starship || exit 1
    install_zoxide
    
    # Configuration
    log_stage "Creating Configurations"
    create_nushell_config
    create_starship_config
    
    # Integration
    log_stage "Setting Up Shell Integration"
    setup_bash_integration
    setup_alternative_shells
    setup_termux_integration
    
    # Testing
    log_stage "Verification"
    test_shell_integration
    
    # Documentation
    update_documentation
    
    # Update stage marker
    echo "$CURRENT_STAGE" > "$STAGE_MARKER"
    
    # Final summary
    log_stage "Stage 2 Complete! 🚀"
    
    echo -e "${GREEN}Shell evolution successfully implemented!${NC}"
    echo -e "\n${CYAN}What's New:${NC}"
    echo -e "• ${YELLOW}Nushell${NC} - Modern shell with structured data"
    echo -e "• ${YELLOW}Starship${NC} - Beautiful, fast prompt in any shell"
    echo -e "• ${YELLOW}Zoxide${NC} - Smarter cd command that learns"
    echo -e "\n${CYAN}Try It Now:${NC}"
    echo -e "1. Reload your shell: ${BLUE}source ~/.bashrc${NC}"
    echo -e "2. Launch Nushell: ${BLUE}nu${NC}"
    echo -e "3. Navigate smartly: ${BLUE}z <partial-directory-name>${NC}"
    echo -e "\n${CYAN}Next Stage:${NC}"
    echo -e "Stage 3 will add modern CLI tools (bat, ripgrep, fd, etc.)"
    echo -e "Run ${PURPLE}./stage3-install.sh${NC} when ready!"
    
    # Platform-specific notes
    if [[ "$PLATFORM" == "termux" ]]; then
        echo -e "\n${YELLOW}Termux Note:${NC}"
        echo -e "Restart Termux app for full integration"
    fi
}

# ===== Script Entry Point =====
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi