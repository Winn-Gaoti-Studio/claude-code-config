#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEMP_ROOT"' EXIT

input='{"tool_input":{"command":"gh pr create --title \"mentions --draft\""}}'
output="$(printf '%s' "$input" | bash "$ROOT/hooks/auto-assign-pr.sh")"
printf '%s' "$output" | jq -e '
  .hookSpecificOutput.updatedInput.command
  | contains("--draft") and contains("--assignee @me")
' >/dev/null

indirect='{"tool_input":{"command":"echo gh pr create --title test"}}'
test -z "$(printf '%s' "$indirect" | bash "$ROOT/hooks/auto-assign-pr.sh")"

runtime="$TEMP_ROOT/runtime"
mkdir -p "$runtime"
now="$(date +%s)"
printf '{"pct":70,"window":200000,"ts":%s}\n' "$now" > "$runtime/context-usage-session.json"
prompt='{"session_id":"session"}'
first="$(printf '%s' "$prompt" | CLAUDE_STATUSLINE_RUNTIME_DIR="$runtime" bash "$ROOT/hooks/context-compact-reminder.sh")"
printf '%s' "$first" | jq -e '.systemMessage | contains("70%")' >/dev/null
test -z "$(printf '%s' "$prompt" | CLAUDE_STATUSLINE_RUNTIME_DIR="$runtime" bash "$ROOT/hooks/context-compact-reminder.sh")"

printf '{"pct":85,"window":200000,"ts":%s}\n' "$now" > "$runtime/context-usage-session.json"
second="$(printf '%s' "$prompt" | CLAUDE_STATUSLINE_RUNTIME_DIR="$runtime" bash "$ROOT/hooks/context-compact-reminder.sh")"
printf '%s' "$second" | jq -e '.systemMessage | contains("85%")' >/dev/null

printf 'hook tests passed\n'
