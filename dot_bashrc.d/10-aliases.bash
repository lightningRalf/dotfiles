# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sd -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Quick navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias ~='cd ~'

# Aliases for ripgrep (fast text search)
alias rg='rg --color=always --line-number --no-heading --smart-case --sort path'
alias rgi='rg --no-ignore'                   # Search everything
alias rgf='rg --files'                       # List all files
alias rgt='rg --type'                        # Search specific file type
alias rgc='rg --count'                       # Count matches per file
alias rgl='rg --files-with-matches'          # List files with matches
alias rgv='rg --invert-match'                # Invert match
alias rgw='rg --word-regexp'                 # Match whole words
alias rgs='rg --case-sensitive'              # Force case sensitive

# Integration with fzf
# alias rgfzf='rg --files | fzf --preview "bat --style=numbers --line-range :500 {}"' - does not work / get voila 2025-06-24 and claude

# Aliases for fd (fd-find)
# Non-WSL fallback: if only `fdfind` exists, provide `fd`.
if [[ -z "$WSL_DISTRO_NAME" ]] && command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
  alias fd='fdfind --color=always'
fi
alias fda='fd --no-ignore --hidden'
alias fdt='fd --type f'
alias fdd='fd --type d | fzf | cd'
alias fdjs='fd --extension js'
alias fdexec='fd --type f --exec'
# Aliases for fd + fzf for file selection
alias ff='fd --type f | fzf --preview "bat --style=numbers --color=always --line-range :500 {}"'

# Aliases for eza (ls replacement)
alias ls='eza --color=always --group-directories-first --icons'
alias ll='eza -la --icons --octal-permissions --group-directories-first'
alias lt='eza --tree --level=2 --color=always --group-directories-first --icons'
alias la='eza --long --all --group --group-directories-first'

# Aliases for fzf (fuzzy finder)
# alias fzfvi='fzf | xargs -r vi'
# alias fzfgb='git branch | fzf | xargs git checkout'

# Aliases for git
alias g='git'
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    alias dotfiles='/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
elif [[ "$OSTYPE" == "msys"* ]] || [[ "$OSTYPE" == "win32"* ]] || [[ "$OSTYPE" == "cygwin"* ]]; then
    alias dotfiles='/cmd/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
fi

# Aliases for batcat (enhanced cat)
alias bat='batcat --style=numbers,changes,header'
alias batl='bat --style=plain'
alias batd='bat --theme="Dracula"'

# Aliases for claude code
alias cc='claude'
alias ccmcp='claude --mcp-debug'

# Aliases for sd (sed alternative) - search and replace
alias sr='sd'
alias sr-trim='sd "\\s+$" ""'
alias sr-spaces='sd "\\s+" " "'

# uv specific things
alias smuv='uvx uvinit'
