command -v starship &> /dev/null && eval "$(starship init bash)"
command -v zoxide &> /dev/null && eval "$(zoxide init bash)"
command -v atuin &> /dev/null && eval "$(atuin init bash --disable-up-arrow)"

source <(op completion bash)
source ~/.config/fzf/functions.sh
# export HELIX_RUNTIME=/usr/local/share/helix/runtime


if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# ~/.bashrc (Git Bash) or ~/.config/nushell/env.nu (Nushell)
export EDITOR="hx"
export VISUAL="hx"
export PAGER="bat --style=plain"
export BAT_THEME="OneHalfDark"
export RIPGREP_CONFIG_PATH="$HOME/.ripgreprc"
export MANPAGER="sh -c 'col -bx | bat -l man -p'"

# Vars for fzf
# export FZF_DEFAULT_COMMAND='rg --files --no-ignore --hidden --follow --glob "!.git/*"'
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border --preview "bat --style=numbers --color=always --line-range :500 {}" --bind "ctrl-/:toggle-preview" --bind "ctrl-a:select-all" --bind "ctrl-y:execute-silent(echo {} | clip.exe)+abort"'
#  --color=bg+:#414559,bg:#303446,spinner:#f2d5cf,hl:#e78284
#  --color=fg:#c6d0f5,header:#e78284,info:#ca9ee6,pointer:#f2d5cf
#  --color=marker:#f2d5cf,fg+:#c6d0f5,prompt:#ca9ee6,hl+:#e78284

# don't put duplicate lines or lines starting with space in the history.       
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

cdfd() {
  cd "$(fd --color=never -t d "$1" | fzf)"
}
