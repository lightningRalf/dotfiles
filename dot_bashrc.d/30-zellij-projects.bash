# Zellij project helpers
# NOTE: This file is sourced by ~/.bashrc (via ~/.bashrc.d/*.bash)
# Keep it interactive-only (no side-effects for automation shells).
[[ $- != *i* ]] && return

# Open a project as a new tab in the current Zellij session
# Usage: zproj <tab-name> <cwd> <layout-name>
zproj() {
  local name="${1:-}"
  local cwd="${2:-}"
  local layout="${3:-}"

  if [[ -z "$name" || -z "$cwd" || -z "$layout" ]]; then
    echo "Usage: zproj <tab-name> <cwd> <layout-name>" >&2
    return 2
  fi

  if [[ -z "${ZELLIJ_SESSION_NAME:-}${ZELLIJ:-}" ]]; then
    echo "Not in a Zellij session. Start/attach Zellij first." >&2
    return 1
  fi

  zellij action new-tab --name "$name" --cwd "$cwd" --layout "$layout"
}

# pi-societyChatGPT1
piS1() {
  zproj "pi-societyChatGPT1" "$HOME/pi-societyChatGPT1" "piS1"
}

# Open a dedicated tailscale setup tab in the current Zellij session.
# Runs a one-shot bootstrap script and then leaves an interactive shell open.
tailscale_tab() {
  if [[ -z "${ZELLIJ_SESSION_NAME:-}${ZELLIJ:-}" ]]; then
    echo "Not in a Zellij session. Start/attach Zellij first." >&2
    return 1
  fi

  local script_path="$HOME/.local/bin/tailscale-zellij-setup.sh"
  if [[ ! -x "$script_path" ]]; then
    echo "Missing executable: $script_path" >&2
    return 1
  fi

  zellij action new-tab --name "tailscale-init"
  zellij run --name "tailscale setup" -- bash -lc "exec '$script_path'"
}

# Short helper requested: `ts`
ts() {
  tailscale_tab "$@"
}

# Backward-compatible name
ztailscale_tab() {
  tailscale_tab "$@"
}
