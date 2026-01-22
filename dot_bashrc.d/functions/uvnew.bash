# usage: uvnew <name> [template] [--public|--private|--internal] [--org ORG]
# templates: simple (default) | copier | cookie
uvnew() {
  set -euo pipefail
  local name="${1:?Usage: uvnew <name> [template] [--public|--private|--internal] [--org ORG]}"
  local template="${2:-simple}"
  shift 2 2>/dev/null || shift 1 2>/dev/null || true

  local vis="--private"; local org=""
  while (($#)); do
    case "$1" in
      --public|--private|--internal) vis="$1" ;;
      -o|--org) org="$2"; shift ;;
      *) echo "Ignoring unknown arg: $1" ;;
    esac
    shift || true
  done

  local dest="$PWD/$name"
  if [ -e "$dest" ]; then
    echo "Error: $dest already exists" >&2
    return 1
  fi

  case "$template" in
    simple|smuv|simple-modern-uv)
      # Minimal template (Copier)
      uvx copier copy --trust gh:jlevy/simple-modern-uv "$dest"
      ;;
    copier|copier-uv)
      # Feature-rich Copier template; uses template extensions
      uvx --with copier-templates-extensions copier copy --trust gh:pawamoy/copier-uv "$dest"
      ;;
    cookie|cookiecutter|cookiecutter-uv)
      # Cookiecutter template; non-interactive with project_name set to <name>
      uvx cookiecutter https://github.com/fpgmaas/cookiecutter-uv.git \
        -o "$(dirname "$dest")" --no-input project_name="$name"
      ;;
    *) echo "Unknown template '$template' (use simple|copier|cookie)"; return 2 ;;
  esac

  cd "$dest"
  git init -b main
  git add .
  git commit -m "chore: initial scaffold ($template)"

  # Create the GitHub repo from the current directory and push
  if [ -n "${org}" ]; then
    gh repo create "${org}/${name}" ${vis} --source=. --remote=origin --push
  else
    gh repo create "${name}" ${vis} --source=. --remote=origin --push
  fi

  echo "✅ Created ${dest} and pushed to GitHub."
}
