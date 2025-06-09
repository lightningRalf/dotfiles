# Nushell Configuration - Truly Minimal
# Philosophy: Maximum delegation, minimum configuration

# Core settings only
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

# Minimal keybindings - only shell integration
$env.config.keybindings = [
    {
        name: atuin_history
        modifier: control
        keycode: char_r
        mode: [emacs, vi_normal, vi_insert]
        event: { send: executehostcommand cmd: "atuin search -i" }
    }
]

# Load user scripts if present
let scripts_dir = $"($env.HOME)/.config/nushell/scripts"
if ($scripts_dir | path exists) {
    ls $"($scripts_dir)/*.nu" | each { |it| source $it.name }
}