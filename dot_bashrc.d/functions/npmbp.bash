# npmbp - local convenience wrapper for npm-bootstrap-publish
# usage:
#   npmbp [project-path] [npm-bootstrap-publish flags]
#   npmbp-dry [project-path] [npm-bootstrap-publish flags]
# examples:
#   npmbp --op op://dev/npm-publish/token
#   npmbp ~/programming/pi-extensions/pi-evalset-lab --op op://dev/npm-publish/token
#   NPM_TOKEN=... npmbp ~/programming/pi-extensions/pi-evalset-lab
#   npmbp-dry ~/programming/pi-extensions/pi-evalset-lab --op op://dev/npm-publish/token

npmbp() {
  local project="$PWD"
  local template_repo="$HOME/programming/pi-extensions/template"
  local repo_cli="$template_repo/bin/npm-bootstrap-publish.mjs"
  local -a args=("$@")

  if [[ ${#args[@]} -gt 0 && "${args[0]}" != -* ]]; then
    project="${args[0]}"
    args=("${args[@]:1}")
  fi

  if command -v npm-bootstrap-publish >/dev/null 2>&1; then
    npm-bootstrap-publish --project "$project" "${args[@]}"
    return $?
  fi

  if [[ -f "$repo_cli" ]]; then
    node "$repo_cli" --project "$project" "${args[@]}"
    return $?
  fi

  echo "npmbp: npm-bootstrap-publish not found." >&2
  echo "npmbp: install globally (npm i -g @tryinget/pi-extension-template)" >&2
  echo "npmbp: or keep template repo at $template_repo" >&2
  return 1
}

npmbp-dry() {
  local -a args=("$@")
  local has_dry=0

  for arg in "${args[@]}"; do
    if [[ "$arg" == "--dry-run" ]]; then
      has_dry=1
      break
    fi
  done

  if (( has_dry )); then
    npmbp "${args[@]}"
  else
    npmbp "${args[@]}" --dry-run
  fi
}
