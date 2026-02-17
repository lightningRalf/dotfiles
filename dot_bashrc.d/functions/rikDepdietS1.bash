# Open rik-depdiet depdiet-first + AppMap tooling layout.
# Use `zellij --layout` so layouts that define multiple tabs are loaded fully.
rikDepdietS1() {
  local layout="rikDepdietS1"
  local session_name="${ZELLIJ_SESSION_NAME:-}"

  if [[ -z "${ZELLIJ_SESSION_NAME:-}${ZELLIJ:-}" ]]; then
    echo "Not in a Zellij session. Start/attach Zellij first." >&2
    return 1
  fi

  if [[ -n "$session_name" ]]; then
    zellij --session "$session_name" --layout "$layout"
  else
    zellij --layout "$layout"
  fi
}

# Short alias-style wrapper
rdS1() {
  rikDepdietS1 "$@"
}

# Depdiet-focused shorthand alias
zdepdiet() {
  rdS1 "$@"
}

# Stop the Convex self-hosted stack used by rdS1.
rdS1Down() {
  local convex_backend_repo="${CONVEX_BACKEND_REPO:-$HOME/programming/upstream/convex-backend}"
  local docker_dir="${CONVEX_SELF_HOSTED_DOCKER_DIR:-$convex_backend_repo/self-hosted/docker}"
  local compose_project="${CONVEX_SELF_HOSTED_COMPOSE_PROJECT:-rik-depdiet-convex}"

  if [[ ! -d "$docker_dir" ]]; then
    echo "Missing Convex self-hosted docker dir: $docker_dir" >&2
    return 1
  fi

  (
    cd "$docker_dir"
    PORT="${CONVEX_SELF_HOSTED_PORT:-3214}" \
    SITE_PROXY_PORT="${CONVEX_SELF_HOSTED_SITE_PORT:-3215}" \
    DASHBOARD_PORT="${CONVEX_SELF_HOSTED_DASHBOARD_PORT:-6795}" \
    docker compose -p "$compose_project" down
  )
}
