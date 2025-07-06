########################################################################
#  Detect platform                               (_PLAT = windows|linux)
########################################################################
case "$OSTYPE" in
  msys*|cygwin*) _PLAT=windows ;;
  linux*)        _PLAT=linux   ;;           # Arch, Debian, etc.
  *)             _PLAT=unknown ;;
esac

########################################################################
#  Windows-only PATH tweaks (WinGet + Chocolatey shims)
########################################################################
if [[ $_PLAT == windows ]]; then
  PATH="/c/Users/$(whoami)/AppData/Local/Microsoft/WinGet/Links:$PATH"
  PATH="/c/ProgramData/chocolatey/bin:$PATH"
fi

########################################################################
#  bun (cross-platform)
########################################################################
if [[ -d "$HOME/.bun" ]]; then
  export BUN_INSTALL="$HOME/.bun"
  PATH="$BUN_INSTALL/bin:$PATH"
fi

########################################################################
#  1Password agent & plugins  (Linux only)
########################################################################
if [[ $_PLAT == linux ]]; then
  export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/1password/agent.sock"
  [[ -f "$HOME/.op/plugins.sh" ]] && source "$HOME/.op/plugins.sh"
fi

########################################################################
#  >>> mise (language toolchain manager) — Windows-safe wrapper <<<
########################################################################
if command -v mise &>/dev/null; then
  if [[ $_PLAT == windows ]]; then
    # 1. ask mise for its env tweaks
    _MISE_ENV="$(mise activate bash)"

    # 2. fix path separators and drive letters *before* we eval it
    # Convert: back-slashes → slashes, semicolons → colons, C:/something → /c/something
    _MISE_ENV="$(printf '%s\n' "$_MISE_ENV" \
      | sed -E 's#\\#/#g; s#;#:#g; s#([A-Za-z]):/#/\L\1/#g')"

    eval "$_MISE_ENV"
    unset _MISE_ENV
  else
    eval "$(mise activate bash)"
  fi
fi

########################################################################
#  Make sure Starship's real exe is visible *after* mise touched PATH
########################################################################
if [[ $_PLAT == windows ]]; then
  PATH="/c/Program Files/starship/bin:$PATH"
fi

########################################################################
#  Prompt & shell helpers (starship, zoxide, atuin)
########################################################################
command -v starship &>/dev/null && eval "$(starship init bash)"
command -v zoxide  &>/dev/null && eval "$(zoxide  init bash)"
command -v atuin   &>/dev/null && eval "$(atuin   init bash --disable-up-arrow)"

########################################################################
#  Completions & fzf helper functions
########################################################################
if command -v op &>/dev/null; then
  source <(op completion bash)
fi

[[ -f "$HOME/.config/fzf/functions.sh" ]] && source "$HOME/.config/fzf/functions.sh"

########################################################################
#  Guarantee core Git-for-Windows dirs are still there
########################################################################
for d in /usr/bin /mingw64/bin; do
  [[ ":$PATH:" != *":${d}:"* ]] && PATH="$d:$PATH"
done


########################################################################
#  EDITOR / PAGER / BAT / RIPGREP
########################################################################
# Some distros ship the binary as `batcat`.  Make a silent alias if needed.
if ! command -v bat &>/dev/null && command -v batcat &>/dev/null; then
  alias bat=batcat
fi

export EDITOR="hx"
export VISUAL="hx"
export PAGER="bat --style=plain"
export BAT_THEME="OneHalfDark"
export RIPGREP_CONFIG_PATH="$HOME/.ripgreprc"
export MANPAGER="sh -c 'col -bx | bat -l man -p'"

########################################################################
#  fzf defaults (fd preferred; fall back to ripgrep)
########################################################################
if command -v fd &>/dev/null; then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
else
  export FZF_DEFAULT_COMMAND='rg --files --no-ignore --hidden --follow --glob "!.git/*"'
fi

# Clipboard binding differs between Windows (clip.exe) and Linux (wl-copy/xclip)
if [[ $_PLAT == windows ]]; then
  _COPY_CMD='clip.exe'
elif command -v wl-copy &>/dev/null; then
  _COPY_CMD='wl-copy'
elif command -v xclip &>/dev/null; then
  _COPY_CMD='xclip -selection clipboard -in'
else
  _COPY_CMD=''   # no clipboard utility found
fi

export FZF_DEFAULT_OPTS=$(
  printf '%s' \
    '--height 40% --layout=reverse --border ' \
    '--preview "bat --style=numbers --color=always --line-range :500 {}" ' \
    '--bind "ctrl-/:toggle-preview" ' \
    '--bind "ctrl-a:select-all" '
)

if [[ -n $_COPY_CMD ]]; then
  export FZF_DEFAULT_OPTS+="--bind \"ctrl-y:execute-silent(echo {} | $_COPY_CMD)+abort\""
fi
unset _COPY_CMD

########################################################################
#  Bash history settings
########################################################################
HISTCONTROL=ignoreboth   # drop leading-space & duplicate entries
shopt -s histappend
HISTSIZE=1000
HISTFILESIZE=2000

########################################################################
#  Aliases / personal helpers
########################################################################
[[ -f "$HOME/.bash_aliases" ]] && source "$HOME/.bash_aliases"

cdfd() {               # cd to a directory chosen via fd+fzf
  cd -- "$(fd --color=never -t d "${1:-}" | fzf)" || return
}

########################################################################
#  Clean-up helper vars
########################################################################
unset _PLAT