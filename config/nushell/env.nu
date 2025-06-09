# Nushell Environment Configuration
# Fixed version addressing parse-time constraints

# ===== Core Directory Configuration =====
$env.CONFIG_DIR = $"($env.HOME)/.config"
$env.DOTFILES_DIR = $"($env.HOME)/dotfiles"

# ===== PATH Configuration =====
let base_paths = [
    $"($env.HOME)/.local/bin"
    $"($env.HOME)/.cargo/bin"
    "/usr/local/bin"
    "/usr/bin"
    "/bin"
]

# Platform-specific path additions
let platform_paths = if ($"($env.HOME)/.termux" | path exists) {
    ["/data/data/com.termux/files/usr/bin"]
} else {
    []
}

$env.PATH = ($base_paths | append $platform_paths | append $env.PATH | uniq)

# ===== Editor Configuration (Fixed) =====
# Check for nvim availability using a different approach
let nvim_path = (which nvim | get path.0? | default "")
$env.EDITOR = if ($nvim_path | is-not-empty) { "nvim" } else { "nano" }
$env.VISUAL = $env.EDITOR

# ===== Shell Integration Configuration =====
$env.STARSHIP_SHELL = "nu"
$env.STARSHIP_CONFIG = $"($env.CONFIG_DIR)/starship.toml"

# ===== Terminal Configuration =====
$env.TERM = if ($env.TERM? | default "dumb") == "dumb" { "xterm-256color" } else { $env.TERM }

# ===== Create Required Directories =====
# Ensure scripts directory exists for integrations
let scripts_dir = $"($env.CONFIG_DIR)/nushell/scripts"
if not ($scripts_dir | path exists) {
    mkdir $scripts_dir
}

# ===== Initialize Integration Scripts =====
# Generate integration scripts if commands are available

# Starship initialization
let starship_init_file = $"($scripts_dir)/starship.nu"
if (which starship | is-not-empty) and (not ($starship_init_file | path exists)) {
    ^starship init nu | save -f $starship_init_file
}

# Zoxide initialization
let zoxide_init_file = $"($scripts_dir)/zoxide.nu"
if (which zoxide | is-not-empty) and (not ($zoxide_init_file | path exists)) {
    ^zoxide init nushell | save -f $zoxide_init_file
}

# Atuin initialization (if needed later)
let atuin_init_file = $"($scripts_dir)/atuin.nu"
if (which atuin | is-not-empty) and (not ($atuin_init_file | path exists)) {
    ^atuin init nu | save -f $atuin_init_file
}

# ===== Default Configuration Structure =====
def create_default_config [] {
    {
        show_banner: false
        edit_mode: "vi"
        
        completions: {
            case_sensitive: false
            quick: true
            partial: true
            algorithm: "fuzzy"
            external: {
                enable: true
                max_results: 100
            }
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
        
        ls: {
            use_ls_colors: true
            clickable_links: true
        }
        
        rm: {
            always_trash: false
        }
        
        table: {
            mode: "rounded"
            index_mode: "always"
            trim: {
                methodology: "wrapping"
                wrapping_try_keep_words: true
            }
        }
        
        error_style: "fancy"
        
        use_grid_icons: true
        footer_mode: "25"
        float_precision: 2
        use_ansi_coloring: true
        file_encoding: "utf8"
        edit_mode: "vi"
        shell_integration: true
        show_banner: false
        
        render_right_prompt_on_last_line: false
        
        buffer_editor: ""
        use_kitty_protocol: false
        highlight_resolved_externals: false
        
        plugins: {}
        
        plugin_gc: {
            default: {
                enabled: true
                stop_after: 10sec
            }
            plugins: {}
        }
    }
}

# Apply default configuration
$env.config = (create_default_config)