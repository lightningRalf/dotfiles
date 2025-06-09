# Nushell Environment - Minimal
# Philosophy: Just enough to bootstrap delegated tools

# PATH (no duplicates)
$env.PATH = ($env.PATH | split row (char esep) | uniq)

# Essential environment
$env.EDITOR = "nano"
$env.VISUAL = $env.EDITOR
$env.PAGER = "less -R"

# Initialize delegated tools
if (which starship | is-not-empty) {
    mkdir ~/.cache/starship
    starship init nu | save -f ~/.cache/starship/init.nu
    source ~/.cache/starship/init.nu
}

if (which zoxide | is-not-empty) {
    zoxide init nushell | save -f ~/.cache/zoxide.nu  
    source ~/.cache/zoxide.nu
}

# Atuin configuration
if (which atuin | is-not-empty) {
    $env.ATUIN_NOBIND = "true"
}