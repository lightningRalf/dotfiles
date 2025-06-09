# Nushell Environment Configuration - Final Correction
# This version correctly scopes variables for parse-time analysis.

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

# Define the path variable at the top level so the parser can see it.
let starship_cache = $"($env.HOME)/.cache/starship"
let starship_init = $"($starship_cache)/init.nu"

# Only initialize if starship is available at runtime.
if (which starship | is-not-empty) {
    # Ensure cache directory exists before generating the file.
    mkdir $starship_cache

    # Generate initialization file if it doesn't exist.
    if not ($starship_init | path exists) {
        ^starship init nu | save -f $starship_init
    }
    
    # Source the file. The parser accepts this because $starship_init is a known variable.
    source-env ($starship_init)
}

# ═══════════════════════════════════════════════════════════════════════════════
# Zoxide Initialization
# ═══════════════════════════════════════════════════════════════════════════════

# Define the path variable at the top level.
let zoxide_init = $"($env.HOME)/.cache/zoxide.nu"

# Only initialize if zoxide is available at runtime.
if (which zoxide | is-not-empty) {
    # Generate if missing.
    if not ($zoxide_init | path exists) {
        ^zoxide init nushell | save -f $zoxide_init
    }
    
    # Source the file.
    source-env ($zoxide_init)
}

# ═══════════════════════════════════════════════════════════════════════════════
# Atuin Configuration
# ═══════════════════════════════════════════════════════════════════════════════

if (which atuin | is-not-empty) {
    $env.ATUIN_NOBIND = "true"
}