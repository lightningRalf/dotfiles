# Nushell Configuration - Minimal Parse-Time Compliant
# All paths are literals, no dynamic loading attempts

# ═══════════════════════════════════════════════════════════════════════════════
# Core Configuration
# ═══════════════════════════════════════════════════════════════════════════════

$env.config = {
    show_banner: false
    edit_mode: "vi"
    
    table: {
        mode: "rounded"
        index_mode: "always"
    }
    
    history: {
        max_size: 10000
        sync_on_enter: true
        file_format: "sqlite"
    }
    
    completions: {
        case_sensitive: false
        quick: true
        partial: true
        algorithm: "fuzzy"
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# Keybindings - Minimal Set
# ═══════════════════════════════════════════════════════════════════════════════

$env.config.keybindings = [
    {
        name: atuin_history
        modifier: control
        keycode: char_r
        mode: [emacs, vi_normal, vi_insert]
        event: { send: executehostcommand cmd: "atuin search -i" }
    }
]

# ═══════════════════════════════════════════════════════════════════════════════
# Optional Script Loading
# ═══════════════════════════════════════════════════════════════════════════════

# Create scripts directory if needed
mkdir ~/.config/nushell/scripts

# Note: To load custom scripts, create them first, then uncomment these lines:
# source ~/.config/nushell/scripts/aliases.nu
# source ~/.config/nushell/scripts/functions.nu
# source ~/.config/nushell/scripts/completions.nu

# For now, we'll include minimal aliases directly here:
alias ll = ls -la
alias la = ls -a
alias l = ls -l