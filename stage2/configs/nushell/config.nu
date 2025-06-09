# Nushell Configuration - Corrected for Parse-Time Constraints
# Philosophy: Minimal configuration with proper constraint handling

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
# Keybindings
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
# Script Loading
# ═══════════════════════════════════════════════════════════════════════════════

# Note: Due to Nushell's parse-time constraints, dynamic script loading
# requires explicit source statements rather than iteration.
# 
# To load custom scripts, add explicit source commands here:
# source ~/.config/nushell/scripts/custom.nu
#
# Or use the following pattern for a known set of scripts:

let scripts_dir = $"($env.HOME)/.config/nushell/scripts"

# Check and source specific known scripts (not dynamic)
if ($"($scripts_dir)/aliases.nu" | path exists) {
    source ~/.config/nushell/scripts/aliases.nu
}

if ($"($scripts_dir)/functions.nu" | path exists) {
    source ~/.config/nushell/scripts/functions.nu
}

if ($"($scripts_dir)/completions.nu" | path exists) {
    source ~/.config/nushell/scripts/completions.nu
}