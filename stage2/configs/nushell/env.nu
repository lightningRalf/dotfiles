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
    
    # Source the initialization file
    source-env $init_file
}

# ═══════════════════════════════════════════════════════════════════════════════
# Zoxide Initialization
# ═══════════════════════════════════════════════════════════════════════════════

if (which zoxide | is-not-empty) {
    let zoxide_cache = $"($env.HOME)/.cache"
    let zoxide_init = $"($zoxide_cache)/zoxide.nu"
    
    # Generate if missing
    if not ($zoxide_init | path exists) {
        ^zoxide init nushell | save -f $zoxide_init
    }
    
    source-env $zoxide_init
}

# ═══════════════════════════════════════════════════════════════════════════════
# Atuin Configuration
# ═══════════════════════════════════════════════════════════════════════════════

if (which atuin | is-not-empty) {
    $env.ATUIN_NOBIND = "true"
}