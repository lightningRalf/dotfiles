# Nushell Environment Configuration - Corrected
# Addresses initialization sequencing and file existence requirements

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
# Starship Initialization with Proper Sequencing
# ═══════════════════════════════════════════════════════════════════════════════

# Only initialize if starship is available
if (which starship | is-not-empty) {
    # Ensure cache directory exists FIRST
    let starship_cache = $"($env.HOME)/.cache/starship"
    mkdir $starship_cache
    
    let init_file = $"($starship_cache)/init.nu"
    
    # Check if initialization file exists or needs regeneration
    if not ($init_file | path exists) {
        # Generate initialization file
        ^starship init nu | save -f $init_file
    }
    
    source ~/.cache/starship/init.nu
}

# ═══════════════════════════════════════════════════════════════════════════════
# Zoxide Initialization
# ═══════════════════════════════════════════════════════════════════════════════

zoxide init nushell | save -f ~/.zoxide.nu

# ═══════════════════════════════════════════════════════════════════════════════
# Atuin Configuration
# ═══════════════════════════════════════════════════════════════════════════════

if (which atuin | is-not-empty) {
    $env.ATUIN_NOBIND = "true"
}