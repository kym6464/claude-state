#!/bin/bash
set -euo pipefail

STATE_DIR="${TMPDIR:-/tmp}/claude-state"
SESSION_ID=""

usage() {
  cat <<'EOF'
Usage: claude-state [--session-id <id>] <command> <key> [value]

Commands:
  has <key>            Check if a key exists (exit 0 if set, 1 if not)
  get <key>            Print the value of a key (exit 1 if not set)
  set <key> [value]    Set a key (defaults to "true" if no value given)
  delete <key>         Remove a key
  list                 Print all key-value pairs
EOF
  exit 1
}

resolve_session_id() {
  if [ -n "$SESSION_ID" ]; then
    return
  fi

  # Read session_id from stdin (hook JSON input)
  local input
  input=$(cat)
  SESSION_ID=$(echo "$input" | jq -r '.session_id // empty' 2>/dev/null || true)

  if [ -z "$SESSION_ID" ]; then
    echo "error: no session_id found in stdin and --session-id not provided" >&2
    exit 1
  fi
}

state_file() {
  echo "${STATE_DIR}/${SESSION_ID}.json"
}

ensure_state_file() {
  mkdir -p "$STATE_DIR"
  local file
  file=$(state_file)
  if [ ! -f "$file" ]; then
    echo '{}' > "$file"
  fi
}

cmd_has() {
  local key="$1"
  resolve_session_id
  local file
  file=$(state_file)
  [ -f "$file" ] && jq -e --arg k "$key" 'has($k)' "$file" > /dev/null 2>&1
}

cmd_get() {
  local key="$1"
  resolve_session_id
  local file
  file=$(state_file)
  if [ ! -f "$file" ]; then
    exit 1
  fi
  local value
  value=$(jq -r --arg k "$key" '.[$k] // empty' "$file")
  if [ -z "$value" ]; then
    exit 1
  fi
  echo "$value"
}

cmd_set() {
  local key="$1"
  local value="${2:-true}"
  resolve_session_id
  ensure_state_file
  local file
  file=$(state_file)
  local tmp="${file}.tmp"
  jq --arg k "$key" --arg v "$value" '.[$k] = $v' "$file" > "$tmp" && mv "$tmp" "$file"
}

cmd_delete() {
  local key="$1"
  resolve_session_id
  local file
  file=$(state_file)
  [ ! -f "$file" ] && return 0
  local tmp="${file}.tmp"
  jq --arg k "$key" 'del(.[$k])' "$file" > "$tmp" && mv "$tmp" "$file"
}

cmd_list() {
  resolve_session_id
  local file
  file=$(state_file)
  if [ ! -f "$file" ]; then
    echo '{}'
    return
  fi
  jq '.' "$file"
}

# Parse --session-id option
while [[ $# -gt 0 ]]; do
  case "$1" in
    --session-id)
      SESSION_ID="${2:-}"
      [ -z "$SESSION_ID" ] && usage
      shift 2
      ;;
    -*)
      usage
      ;;
    *)
      break
      ;;
  esac
done

[ $# -lt 1 ] && usage

COMMAND="$1"
shift

case "$COMMAND" in
  has)
    [ $# -lt 1 ] && usage
    cmd_has "$1"
    ;;
  get)
    [ $# -lt 1 ] && usage
    cmd_get "$1"
    ;;
  set)
    [ $# -lt 1 ] && usage
    cmd_set "$1" "${2:-}"
    ;;
  delete)
    [ $# -lt 1 ] && usage
    cmd_delete "$1"
    ;;
  list)
    cmd_list
    ;;
  *)
    usage
    ;;
esac
