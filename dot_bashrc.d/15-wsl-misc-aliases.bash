# WSL clipboard integration (Windows paths)
if [[ -n "$WSL_DISTRO_NAME" ]]; then
  alias pbcopy='clip.exe'
  alias pbpaste='powershell.exe -command "Get-Clipboard"'
fi

# Windows integration
alias code='code .'

# Zellij session
alias zclaude='zellij --session claude-2025-08-20 --layout ~/claude-2025-08-20.kdl'

# ai-society: GitLab (NAS) via 1Password
alias gl_nas="$HOME/.local/bin/gl-nas"
alias gl_nas_shell="$HOME/.local/bin/gl-nas-shell"
alias zgitlab="$HOME/.local/bin/zgitlab"
