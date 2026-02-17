# Synology / DS1621+ SSH helpers
#
# Problem this solves:
# - You may open many shells (zellij panes, pi sessions, CI shells) where SSH cannot prompt for key passphrases.
# - If the key is passphrase-protected and no usable agent is available, SSH may fall back to ssh_askpass and fail.
#
# Approach:
# - Use a *stable* ssh-agent socket path so all shells can share the same agent.
# - Keep the private key passphrase-protected on disk; unlock it into the agent with a time limit when needed.

SYNO_SSH_AGENT_SOCK="$HOME/.ssh/agent/synology.sock"
SYNO_SSH_KEY="$HOME/.ssh/synology_pi_ops"

syno_agent_ensure() {
  mkdir -p "$HOME/.ssh/agent"

  # ssh-add exit codes:
  # 0 = has identities, 1 = no identities, 2 = cannot connect
  local out rc
  out="$(SSH_AUTH_SOCK="$SYNO_SSH_AGENT_SOCK" ssh-add -l 2>&1)"
  rc=$?

  if [[ $rc -eq 0 || $rc -eq 1 ]]; then
    return 0
  fi

  # Likely stale/broken socket → restart agent on the stable socket.
  rm -f "$SYNO_SSH_AGENT_SOCK"
  ssh-agent -a "$SYNO_SSH_AGENT_SOCK" >/dev/null
}

syno_agent_ls() {
  syno_agent_ensure
  SSH_AUTH_SOCK="$SYNO_SSH_AGENT_SOCK" ssh-add -l
}

# Unlock the Synology key into the stable agent for a limited time.
# Usage: syno_unlock [ttl]
#   ttl examples: 8h, 24h, 7d, 30d
syno_unlock() {
  local ttl="${1:-7d}"

  syno_agent_ensure

  if [[ ! -f "$SYNO_SSH_KEY" ]]; then
    echo "syno_unlock: key not found: $SYNO_SSH_KEY" >&2
    return 1
  fi

  SSH_AUTH_SOCK="$SYNO_SSH_AGENT_SOCK" ssh-add -t "$ttl" "$SYNO_SSH_KEY"
}

# Convenience wrapper
syno() {
  ssh synology-pi-ops "$@"
}
