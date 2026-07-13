#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEMP_ROOT"' EXIT

SOURCE="$TEMP_ROOT/source"
PROJECT="$TEMP_ROOT/project"
mkdir -p "$SOURCE/dot_claude/private_hooks" "$SOURCE/dot_claude/private_agents" "$PROJECT/scripts"

write_valid_settings() {
  cat > "$SOURCE/dot_claude/private_settings.json" <<'JSON'
{
  "model": "claude-test",
  "effortLevel": "high",
  "env": {"CLAUDE_CODE_SUBAGENT_MODEL": "claude-worker"},
  "permissions": {"allow": ["Skill(example)"], "defaultMode": "auto"},
  "hooks": {
    "PreToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "command": "bash \"$HOME/.claude/hooks/auto-assign-pr.sh\""}]}],
    "UserPromptSubmit": [{"hooks": [{"type": "command", "command": "bash \"$HOME/.claude/hooks/context-compact-reminder.sh\"", "timeout": 10}]}]
  },
  "statusLine": {"type": "command", "command": "bash \"$HOME/.claude/statusline.sh\"", "refreshInterval": 30},
  "subagentStatusLine": {"type": "command", "command": "bash \"$HOME/.claude/subagent-statusline.sh\""},
  "enabledPlugins": {"code-review@claude-plugins-official": true},
  "extraKnownMarketplaces": {"openai-codex": {"source": {"source": "github", "repo": "openai/codex-plugin-cc"}}}
}
JSON
}

write_valid_settings
printf '{"bindings":[]}\n' > "$SOURCE/dot_claude/private_keybindings.json"
printf '#!/usr/bin/env bash\nprintf "auto\\n"\n' > "$SOURCE/dot_claude/private_hooks/private_auto-assign-pr.sh"
printf '#!/usr/bin/env bash\nprintf "compact\\n"\n' > "$SOURCE/dot_claude/private_hooks/private_context-compact-reminder.sh"
printf '%s\n' '---' 'name: executor' '---' > "$SOURCE/dot_claude/private_agents/executor.md"

cp "$ROOT/scripts/sync-from-chezmoi.sh" "$PROJECT/scripts/sync-from-chezmoi.sh"
cp "$ROOT/scripts/public-settings.jq" "$PROJECT/scripts/public-settings.jq"

bash "$PROJECT/scripts/sync-from-chezmoi.sh" --write --source "$SOURCE"
jq -e '.model == "claude-test" and .env == {"CLAUDE_CODE_SUBAGENT_MODEL":"claude-worker"}' "$PROJECT/settings.json" >/dev/null
cmp "$SOURCE/dot_claude/private_keybindings.json" "$PROJECT/keybindings.json"
cmp "$SOURCE/dot_claude/private_hooks/private_auto-assign-pr.sh" "$PROJECT/hooks/auto-assign-pr.sh"
cmp "$SOURCE/dot_claude/private_hooks/private_context-compact-reminder.sh" "$PROJECT/hooks/context-compact-reminder.sh"
cmp "$SOURCE/dot_claude/private_agents/executor.md" "$PROJECT/agents/executor.md"
bash "$PROJECT/scripts/sync-from-chezmoi.sh" --check --source "$SOURCE"

printf '\n' >> "$PROJECT/keybindings.json"
if bash "$PROJECT/scripts/sync-from-chezmoi.sh" --check --source "$SOURCE"; then
  printf 'expected --check to report drift\n' >&2
  exit 1
fi
bash "$PROJECT/scripts/sync-from-chezmoi.sh" --write --source "$SOURCE" >/dev/null

cp "$PROJECT/settings.json" "$TEMP_ROOT/settings.before"
jq '.localOnly = true' "$SOURCE/dot_claude/private_settings.json" > "$TEMP_ROOT/unknown.json"
mv "$TEMP_ROOT/unknown.json" "$SOURCE/dot_claude/private_settings.json"
set +e
bash "$PROJECT/scripts/sync-from-chezmoi.sh" --write --source "$SOURCE" >/dev/null 2>&1
status=$?
set -e
[ "$status" -eq 2 ] || { printf 'expected unknown settings key to exit 2\n' >&2; exit 1; }
cmp "$TEMP_ROOT/settings.before" "$PROJECT/settings.json"

write_valid_settings
jq '.model = "/Users/example/private-model"' "$SOURCE/dot_claude/private_settings.json" > "$TEMP_ROOT/private.json"
mv "$TEMP_ROOT/private.json" "$SOURCE/dot_claude/private_settings.json"
set +e
bash "$PROJECT/scripts/sync-from-chezmoi.sh" --write --source "$SOURCE" >/dev/null 2>&1
status=$?
set -e
[ "$status" -eq 2 ] || { printf 'expected private path to exit 2\n' >&2; exit 1; }

write_valid_settings
rm "$SOURCE/dot_claude/private_agents/executor.md"
set +e
bash "$PROJECT/scripts/sync-from-chezmoi.sh" --write --source "$SOURCE" >/dev/null 2>&1
status=$?
set -e
[ "$status" -eq 2 ] || { printf 'expected missing source to exit 2\n' >&2; exit 1; }

printf 'sync and privacy tests passed\n'
