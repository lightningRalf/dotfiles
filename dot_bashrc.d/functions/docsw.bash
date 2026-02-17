# docsw - workspace docs discovery helper
# usage:
#   docsw            # equivalent to docs-list --workspace --discover
#   docsw --json     # add extra flags as needed

docsw() {
  local script=""

  if [[ -f "$HOME/programming/agent-scripts/scripts/docs-list.mjs" ]]; then
    script="$HOME/programming/agent-scripts/scripts/docs-list.mjs"
  elif [[ -f "$HOME/.codex/scripts/docs-list.mjs" ]]; then
    script="$HOME/.codex/scripts/docs-list.mjs"
  else
    echo "docsw: docs-list.mjs not found" >&2
    echo "docsw: expected one of:" >&2
    echo "  $HOME/programming/agent-scripts/scripts/docs-list.mjs" >&2
    echo "  $HOME/.codex/scripts/docs-list.mjs" >&2
    return 1
  fi

  node "$script" --workspace --discover "$@"
}
