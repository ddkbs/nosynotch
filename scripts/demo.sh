#!/usr/bin/env bash
# Sends fake Claude Code hook events to the running app – tests the full HTTP path.
# (For a quick look without the terminal: menu bar ✦ → "Demo abspielen".)
set -euo pipefail
PORT="${CLAUDE_NOTCH_PORT:-7823}"
URL="http://127.0.0.1:$PORT/event"
SID="demo-$$"
CWD="$PWD"

send() {
  curl -s -m 2 -X POST -H 'Content-Type: application/json' -H 'Expect:' \
    -H "X-Term-Program: ${TERM_PROGRAM:-}" -H "X-Bundle-Id: ${__CFBundleIdentifier:-}" \
    --data-binary "$1" "$URL" >/dev/null || { echo "Is the app running on port $PORT?"; exit 1; }
}
ev() { # ev <event> [extra json]
  send "{\"hook_event_name\":\"$1\",\"session_id\":\"$SID\",\"cwd\":\"$CWD\"${2:+,$2}}"
}

ev SessionStart
ev UserPromptSubmit '"prompt":"Refactor the parser"'; sleep 2.5
ev PreToolUse '"tool_name":"Grep","tool_input":{"pattern":"func parse"}'; sleep 1.2
ev PostToolUse '"tool_name":"Grep"'; sleep 0.8
ev PreToolUse '"tool_name":"Edit","tool_input":{"file_path":"Sources/Parser.swift"}'; sleep 1.5
ev PostToolUse '"tool_name":"Edit"'; sleep 0.5
ev Notification '"message":"Claude needs your permission to use Bash","notification_type":"permission_prompt"'; sleep 3
ev PreToolUse '"tool_name":"Bash","tool_input":{"command":"swift test","description":"Run tests"}'; sleep 2.5
ev PostToolUse '"tool_name":"Bash"'; sleep 1.5
ev Stop '"last_assistant_message":"Parser refactored, all 42 tests pass."'
sleep 8
ev SessionEnd
echo "✓ Demo fertig"
