# Nushell Configuration - Final Correction
# This version correctly scopes variables for parse-time analysis.

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

# Define script path variables at the top level so the parser recognizes them.
let scripts_dir = $"($env.HOME)/.config/nushell/scripts"
let aliases_file = $"($scripts_dir)/aliases.nu"
let functions_file = $"($scripts_dir)/functions.nu"
let completions_file = $"($scripts_dir)/completions.nu"

# At runtime, check for each file's existence and source it if present.
# The parser allows this because the variables are known at parse-time.
if ($aliases_file | path exists) {
    source ($aliases_file)
}

if ($functions_file | path exists) {
    source ($functions_file)
}

if ($completions_file | path exists) {
    source ($completions_file)
}