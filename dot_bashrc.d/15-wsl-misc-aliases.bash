# WSL clipboard integration
# Prefer WSLg/Wayland clipboard utilities (Linux-native).
# Fallback to Windows executables via absolute paths (PATH is intentionally Linux-only).
if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
  if command -v wl-copy >/dev/null 2>&1 && command -v wl-paste >/dev/null 2>&1; then
    alias pbcopy='wl-copy'
    alias pbpaste='wl-paste'
  else
    alias pbcopy='/mnt/c/Windows/System32/clip.exe'
    alias pbpaste='/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -NoProfile -Command Get-Clipboard'
  fi
fi

# Windows integration
alias code='code .'

# ai-society: GitLab (NAS) via 1Password
alias gl_nas="$HOME/.local/bin/gl-nas"
alias gl_nas_shell="$HOME/.local/bin/gl-nas-shell"
alias zgitlab="$HOME/.local/bin/zgitlab"

# NOTE: pi-dev is defined as a function in ~/.bashrc.d/functions/pi-dev.bash.
# Don't alias it here, because aliases override functions and can break pi-dev.
