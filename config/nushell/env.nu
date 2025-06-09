# Nushell Environment Configuration
# Corrected version - eliminates duplicate fields and improves structure

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

# ===== Editor Configuration =====
# Safely check for nvim availability
let nvim_path = (which nvim | get path.0? | default "")
$env.EDITOR = if ($nvim_path | is-not-empty) { "nvim" } else { "nano" }
$env.VISUAL = $env.EDITOR

# ===== Shell Integration Configuration =====
$env.STARSHIP_SHELL = "nu"
$env.STARSHIP_CONFIG = $"($env.CONFIG_DIR)/starship.toml"

# ===== Terminal Configuration =====
$env.TERM = if ($env.TERM? | default "dumb") == "dumb" { "xterm-256color" } else { $env.TERM }

# ===== Create Required Directories =====
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

# Atuin initialization - only if atuin is installed
let atuin_init_file = $"($scripts_dir)/atuin.nu"
if (which atuin | is-not-empty) and (not ($atuin_init_file | path exists)) {
    print "Generating atuin integration..."
    ^atuin init nu | save -f $atuin_init_file
}

# ===== Default Configuration Structure =====
# CORRECTED: Removed duplicate fields and reorganized for clarity
def create_default_config [] {
    {
        # Behavior settings
        show_banner: false
        shell_integration: true
        buffer_editor: ""
        
        # Editor mode - DEFINED ONLY ONCE
        edit_mode: "vi"
        
        # Cursor configuration
        cursor_shape: {
            vi_insert: "line"
            vi_normal: "block"
        }
        
        # Completion settings
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
        
        # History configuration
        history: {
            max_size: 10000
            sync_on_enter: true
            file_format: "sqlite"
            isolation: false
        }
        
        # Command-specific settings
        ls: {
            use_ls_colors: true
            clickable_links: true
        }
        
        rm: {
            always_trash: false
        }
        
        # Table display configuration
        table: {
            mode: "rounded"
            index_mode: "always"
            show_empty: true
            padding: { left: 1, right: 1 }
            trim: {
                methodology: "wrapping"
                wrapping_try_keep_words: true
                truncating_suffix: "..."
            }
            header_on_separator: false
            # abbreviated_row_count: 10
        }
        
        # Display settings
        error_style: "fancy"
        use_grid_icons: true
        footer_mode: "25"
        float_precision: 2
        use_ansi_coloring: true
        file_encoding: "utf8"
        
        # Prompt rendering
        render_right_prompt_on_last_line: false
        
        # Advanced features
        use_kitty_protocol: false
        highlight_resolved_externals: false
        
        # Plugin system
        plugins: {}
        
        # Plugin garbage collection
        plugin_gc: {
            default: {
                enabled: true
                stop_after: 10sec
            }
            plugins: {}
        }
        
        # Menus configuration
        menus: [
            {
                name: completion_menu
                only_buffer_difference: false
                marker: "| "
                type: {
                    layout: columnar
                    columns: 4
                    col_width: 20
                    col_padding: 2
                }
                style: {
                    text: green
                    selected_text: { attr: r }
                    description_text: yellow
                    match_text: { attr: u }
                    selected_match_text: { attr: ur }
                }
            }
            {
                name: history_menu
                only_buffer_difference: true
                marker: "? "
                type: {
                    layout: list
                    page_size: 10
                }
                style: {
                    text: green
                    selected_text: green_reverse
                    description_text: yellow
                }
            }
        ]
        
        # Keybindings
        keybindings: [
            {
                name: completion_menu
                modifier: none
                keycode: tab
                mode: [emacs vi_normal vi_insert]
                event: {
                    until: [
                        { send: menu name: completion_menu }
                        { send: menunext }
                        { edit: complete }
                    ]
                }
            }
            {
                name: history_menu
                modifier: control
                keycode: char_r
                mode: [emacs, vi_insert, vi_normal]
                event: { send: menu name: history_menu }
            }
        ]
        
        # Hooks
        hooks: {
            pre_prompt: [{ null }]
            pre_execution: [{ null }]
            env_change: {
                PWD: [{ |before, after| null }]
            }
            display_output: "if (term size).columns >= 100 { table -e } else { table }"
            command_not_found: { null }
        }
    }
}

# Apply configuration