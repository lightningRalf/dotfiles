# pi-dev function - wrapper for pi-mono coding agent
pi-dev() {
  local repo="$HOME/programming/pi-mono"
  local pkg="$repo/packages/coding-agent"
  
  if [[ ! -d "$pkg" ]]; then
    echo "pi-dev: missing repo at $pkg" >&2
    echo "pi-dev: clone: git clone https://github.com/badlogic/pi-mono.git $repo" >&2
    return 1
  fi

  local tsx_bin="$repo/node_modules/.bin/tsx"
  if [[ -x "$tsx_bin" ]]; then
    (cd "$pkg" && PI_CODING_AGENT_DIR="$HOME/.pi-dev/agent" "$tsx_bin" src/cli.ts "$@")
    return
  fi

  echo "pi-dev: missing $tsx_bin (deps not installed?)" >&2
  echo "pi-dev: run: (cd $repo && npm install)" >&2
  return 1
}
