# Overview of filedirectory for LLMs
ezal() {
  local level="${1:-1}"
  local src="./src"
  local pkg

  # If first arg isn't a number, treat it as package; default level=1
  if ! [[ "$level" =~ ^[0-9]+$ ]]; then
    pkg="$level"
    level="${2:-1}"
  else
    pkg="${2:-}"
  fi

  # Auto-detect package: prefer ./src/dspx, else first subdir
  if [[ -z "$pkg" ]]; then
    if [[ -d "$src/dspx" ]]; then
      pkg="dspx"
    else
      pkg="$(basename "$(ls -1 -d "$src"/*/ 2>/dev/null | head -n1)")"
    fi
  fi

  if [[ -z "$pkg" || ! -d "$src/$pkg" ]]; then
    echo "ezal: package dir not found under $src. Usage: ezal [LEVEL] [PACKAGE]" >&2
    return 1
  fi

  command eza -T -L "$level" "$src/$pkg/" --git-ignore
}
