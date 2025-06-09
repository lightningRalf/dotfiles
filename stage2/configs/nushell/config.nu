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

# Note: To source files with dynamic paths, wrap the variable in parentheses.
# This tells Nushell to evaluate the path at runtime.

let scripts_dir = $"($env.HOME)/.config/nushell/scripts"

# Check and source specific known scripts using the correct runtime syntax
let aliases_file = $"($scripts_dir)/aliases.nu"
if ($aliases_file | path exists) {
    source ($aliases_file)
}

let functions__file = $"($scripts_dir)/functions.nu"
if ($functions_file | path exists) {
    source ($functions_file)
}

let completions_file = $"($scripts_dir)/completions.nu"
if ($completions_file | path exists) {
    source ($completions_file)
}