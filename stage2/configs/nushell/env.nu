# Nushell Environment Configuration - Parse-Time Compliant
# All source commands use literal paths as required by Nushell's architecture

# ═══════════════════════════════════════════════════════════════════════════════
# PATH Configuration
# ═══════════════════════════════════════════════════════════════════════════════

$env.PATH = ($env.PATH | split row (char esep) | uniq)

# ═══════════════════════════════════════════════════════════════════════════════
# Essential Environment Variables
# ═══════════════════════════════════════════════════════════════════════════════

$env.EDITOR = "nano"
$env.VISUAL = $env.EDITOR
$env.PAGER = "less -R"

# ═══════════════════════════════════════════════════════════════════════════════
# Starship Initialization - Using Literal Paths
# ═══════════════════════════════════════════════════════════════════════════════

if (which starship | is-not-empty) {
    # Ensure cache directory exists
    mkdir ~/.cache/starship
    
    # Check if init file exists before attempting to source
    if not ("~/.cache/starship/init.nu" | path exists) {
        # Generate the initialization file
        ^starship init nu | save -f ~/.cache/starship/init.nu
    }
    
    # Source with literal path - required by Nushell
    source ~/.cache/starship/init.nu
}

# ═══════════════════════════════════════════════════════════════════════════════
# Zoxide Initialization - Using Literal Paths
# ═══════════════════════════════════════════════════════════════════════════════

if (which zoxide | is-not-empty) {
    # Check and generate if needed
    if not ("~/.cache/zoxide.nu" | path exists) {
        ^zoxide init nushell | save -f ~/.cache/zoxide.nu
    }
    
    # Source with literal path
    source ~/.cache/zoxide.nu
}

# ═══════════════════════════════════════════════════════════════════════════════
# Atuin Configuration
# ═══════════════════════════════════════════════════════════════════════════════

if (which atuin | is-not-empty) {
    $env.ATUIN_NOBIND = "true"
}

# ═══════════════════════════════════════════════════════════════════════════════
# XDG Base Directory Specification
# ═══════════════════════════════════════════════════════════════════════════════

$env.XDG_CONFIG_HOME = $"($env.HOME)/.config"
$env.XDG_DATA_HOME = $"($env.HOME)/.local/share"
$env.XDG_CACHE_HOME = $"($env.HOME)/.cache"