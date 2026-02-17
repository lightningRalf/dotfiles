# Tailscale bootstrap for WSL (no systemd)
# Starts tailscaled on-demand using a stable state/socket path.

TS_STATE="/var/lib/tailscale/tailscaled.state"
TS_SOCKET="/run/tailscale/tailscaled.sock"

_tailscale_boot() {
  if pgrep -x tailscaled >/dev/null 2>&1; then
    return 0
  fi

  sudo /usr/bin/mkdir -p /var/lib/tailscale /run/tailscale
  sudo /usr/bin/tailscaled --state="$TS_STATE" --socket="$TS_SOCKET" >/tmp/tailscaled.log 2>&1 &
  sudo /usr/bin/tailscale up --accept-dns=false --ssh
}

tailscale_boot() {
  _tailscale_boot
}

# Optional auto-start on interactive shells.
# Disabled by default to avoid sudo prompts on every new tab/pane.
# Enable explicitly with: export TAILSCALE_AUTO_BOOT_SHELL=1
if [[ -n "${PS1-}" && "${TAILSCALE_AUTO_BOOT_SHELL:-0}" == "1" ]]; then
  tailscale_boot
fi
