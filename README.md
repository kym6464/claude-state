# claude-state

A lightweight CLI for managing session-scoped state in [Claude Code hooks](https://code.claude.com/docs/en/hooks).

## Why

Claude Code hooks often need to track state across a session (e.g., "only nudge once", "remember if lint errors were pre-existing"). Without a shared mechanism, each hook invents its own marker files, polluting `/tmp` and duplicating logic.

`claude-state` provides a single key-value store per session, scoped automatically by `session_id`.

## Installation

```bash
brew install claude-state
```

## Usage

```
claude-state [--session-id <id>] <command> <key> [value]
```

### Commands

| Command          | Description                          | Exit code              |
| :--------------- | :----------------------------------- | :--------------------- |
| `has <key>`      | Check if a key exists                | `0` if set, `1` if not |
| `get <key>`      | Print the value of a key             | `1` if not set         |
| `set <key>`      | Set a flag (boolean true)            |                        |
| `set <key> <value>` | Set a key to a value             |                        |
| `delete <key>`   | Remove a key                         |                        |
| `list`           | Print all key-value pairs            |                        |

### Session ID

By default, `claude-state` reads the hook's JSON input from stdin to extract `session_id`. This means in the simple case you don't need to pass anything — just pipe stdin through.

If your hook needs stdin for other purposes, pass the session ID explicitly:

```bash
claude-state --session-id <id> <command> <key> [value]
```

### Storage

State is stored in `${TMPDIR:-/tmp}/claude-state/<session_id>.json`. Each session gets its own file, automatically created on first write.

## Examples

### Simple hook — only fire once per session

A `PostToolUse` hook that provides feedback to Claude, but only the first time:

```bash
#!/bin/bash
claude-state has migration_warning_sent && exit 0
claude-state set migration_warning_sent
cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "This project uses v2 of the config format. See docs/migration.md before making changes."
  }
}
EOF
```

### Hook that also reads stdin

When your hook needs to inspect the tool input/output in addition to managing state, capture stdin first and pass the session ID explicitly:

```bash
#!/bin/bash
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id')

claude-state --session-id "$SESSION_ID" has deprecation_warning_sent && exit 0

if echo "$INPUT" | grep -q 'legacyApi'; then
  claude-state --session-id "$SESSION_ID" set deprecation_warning_sent
  # ... output nudge JSON
fi
```
