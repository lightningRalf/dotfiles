# Nushell Integration for Stage 3 CLI Tools
# Philosophy: Structured data pipelines with modern tool integration
#
# This configuration demonstrates the synergy between Nushell's structured
# data paradigm and modern CLI tools. Each integration leverages both the
# tool's strengths and Nushell's type system for maximum productivity.

# ═══════════════════════════════════════════════════════════════════════════════
# Core Tool Aliases: Seamless Transition
# ═══════════════════════════════════════════════════════════════════════════════

# File Operations
alias cat = bat
alias find = fd
alias ls = eza
alias ll = eza -la
alias la = eza -la
alias tree = eza --tree

# Text Processing
alias grep = rg

# System Monitoring
alias top = btm
alias htop = btm
alias du = dust

# ═══════════════════════════════════════════════════════════════════════════════
# Enhanced Functions: Leveraging Tool Synergy
# ═══════════════════════════════════════════════════════════════════════════════

# Interactive file search with preview
def search [
    pattern: string      # Search pattern (regex supported)
    path?: string       # Optional search path
    --type(-t): string  # File type filter
] {
    let search_path = ($path | default ".")
    let type_flag = if ($type | is-empty) { [] } else { [-t $type] }
    
    rg $pattern $search_path ...$type_flag
    | lines
    | parse "{file}:{line}:{content}"
    | fzf --preview $"bat --color=always --highlight-line {($in.line)} {($in.file)}"
}

# Fuzzy directory navigation
def fuzzy_cd [] {
    let selected = (
        fd --type d
        | fzf --preview 'eza --tree --level=2 --color=always {}'
    )
    
    if ($selected | is-not-empty) {
        cd $selected
    }
}

# Find large files interactively
def find_large [
    size: string = "10M"  # Minimum size (e.g., "10M", "1G")
    path?: string         # Search path
] {
    let search_path = ($path | default ".")
    
    fd . $search_path --type f --size $"+($size)"
    | each { |file| 
        let info = (ls -la $file | first)
        {path: $file, size: $info.size}
    }
    | sort-by size --reverse
}

# Git status with visual enhancements
def gs [] {
    let status = (git status --porcelain | lines)
    
    if ($status | is-empty) {
        print "✨ Working tree clean"
    } else {
        print "📝 Changes detected:"
        $status | each { |line|
            let parts = ($line | parse "{status} {file}")
            let emoji = match $parts.status {
                "M " => "📝",
                "A " => "➕",
                "D " => "➖",
                "R " => "🔄",
                "??" => "❓",
                _ => "🔸"
            }
            print $"($emoji) ($parts.file)"
        }
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# Data Processing Pipelines: Modern Tool Integration
# ═══════════════════════════════════════════════════════════════════════════════

# Analyze code statistics with visual output
def code_stats [path?: string] {
    let target = ($path | default ".")
    
    print $"Analyzing code in ($target)..."
    
    # Use fd to find source files
    fd -e py -e js -e rs -e go -e java $target
    | lines
    | each { |file|
        let lines = (open $file | lines | length)
        {file: $file, lines: $lines}
    }
    | sort-by lines --reverse
    | first 20
}

# Search and replace with preview
def replace [
    pattern: string     # Search pattern
    replacement: string # Replacement text
    --preview(-p)      # Preview changes without applying
] {
    if $preview {
        sd $pattern $replacement --preview
    } else {
        print "Searching for pattern..."
        let files = (rg -l $pattern)
        
        if ($files | is-empty) {
            print "No matches found"
        } else {
            print $"Found matches in ($files | lines | length) files"
            print "Proceed with replacement? [y/N]"
            let answer = (input)
            
            if $answer == "y" {
                sd $pattern $replacement $files
                print "✅ Replacement complete"
            }
        }
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# System Monitoring Enhancements
# ═══════════════════════════════════════════════════════════════════════════════

# Quick system overview
def sys [] {
    print "🖥️  System Overview"
    print "━━━━━━━━━━━━━━━━━━"
    
    # CPU and Memory from bottom (if available)
    print "📊 Resources:"
    if (which btm | is-not-empty) {
        # This would ideally parse btm output, but btm doesn't have good CLI output
        print "  Run 'btm' for detailed view"
    }
    
    # Disk usage via dust
    print "\n💾 Disk Usage:"
    dust -d 1
    
    # Large directories
    print "\n📁 Largest Directories:"
    fd --type d -d 2 | each { |dir|
        let size = (du -s $dir | parse "{size}\t{path}" | get size | first)
        {path: $dir, size: $size}
    } | sort-by size --reverse | first 5
}

# ═══════════════════════════════════════════════════════════════════════════════
# Development Workflow Helpers
# ═══════════════════════════════════════════════════════════════════════════════

# Interactive git add with delta preview
def ga [] {
    git status --porcelain
    | lines
    | parse "{status} {file}"
    | where status != "??"
    | get file
    | fzf --multi --preview "git diff --color=always {}"
    | lines
    | each { |file| git add $file }
}

# Browse git history with visual diffs
def git_history [] {
    git log --oneline --graph --color=always
    | fzf --ansi --preview "git show --color=always {1}"
}

# ═══════════════════════════════════════════════════════════════════════════════
# Configuration Helpers
# ═══════════════════════════════════════════════════════════════════════════════

# Check tool installation status
def check_tools [] {
    let tools = [
        {name: "bat", cmd: "bat"},
        {name: "fd", cmd: "fd"},
        {name: "eza", cmd: "eza"},
        {name: "ripgrep", cmd: "rg"},
        {name: "sd", cmd: "sd"},
        {name: "bottom", cmd: "btm"},
        {name: "dust", cmd: "dust"},
        {name: "delta", cmd: "delta"},
        {name: "fzf", cmd: "fzf"},
    ]
    
    print "🔧 Stage 3 Tool Status:"
    print "━━━━━━━━━━━━━━━━━━━━━"
    
    $tools | each { |tool|
        let status = if (which $tool.cmd | is-not-empty) { "✅" } else { "❌" }
        print $"($status) ($tool.name)"
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
# Environment Setup
# ═══════════════════════════════════════════════════════════════════════════════

# Set up FZF defaults for consistent experience
$env.FZF_DEFAULT_OPTS = "
    --height 40%
    --layout=reverse
    --border
    --inline-info
    --preview-window=:hidden
    --bind='ctrl-/:toggle-preview'
    --bind='ctrl-a:select-all'
    --bind='ctrl-y:execute-silent(echo {} | clip)+abort'
"

# Use fd for FZF file searching
$env.FZF_DEFAULT_COMMAND = "fd --type f --hidden --follow --exclude .git"
$env.FZF_CTRL_T_COMMAND = $env.FZF_DEFAULT_COMMAND
$env.FZF_ALT_C_COMMAND = "fd --type d --hidden --follow --exclude .git"

# Configure ripgrep defaults
$env.RIPGREP_CONFIG_PATH = "~/.config/ripgrep/config"

print "✨ Stage 3 CLI tools integrated with Nushell"
print "Run 'check_tools' to verify installation status"
