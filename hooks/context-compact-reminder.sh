#!/usr/bin/env bash
# Context compact reminder (UserPromptSubmit hook).
#
# Shows a user-only systemMessage nudging /compact when context usage crosses a tier (default 70/85/95%), at most once per tier per session. systemMessage is not injected into model context, so the reminder costs no tokens.
#
# Data sources, in priority order:
#   1. Statusline cache ${CLAUDE_STATUSLINE_RUNTIME_DIR:-/tmp/claude}/context-usage-<session_id>.json, written by ~/.claude/statusline.sh on every render. Carries Claude Code's own used_percentage and context_window_size — the exact numbers the footer shows, correct for 200k and 1M models alike (including credit-gated 1M variants that a model id can't reveal). Fresh for CACHE_MAX_AGE seconds.
#   2. Transcript fallback: sum the last main-thread usage record (sidechain entries filtered, compact_boundary aware) and divide by a window guessed from the model id. Used by headless/background sessions that render no status line.
#
# Hook stdin does NOT carry context_window — only the status line receives it — which is why the cache hand-off exists. See the docs' "Common input fields" for hooks vs the status line's "Available data".
#
# Tunables (environment overrides):
#   CLAUDE_COMPACT_REMINDER_TIERS    space-separated percent tiers (default "70 85 95")
#   CLAUDE_COMPACT_REMINDER_WINDOW   force a context window in tokens (fallback path only)

command -v jq >/dev/null 2>&1 || exit 0

# Defer to a project-registered copy of this reminder so one prompt never produces two nudges.
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -f "$CLAUDE_PROJECT_DIR/.claude/scripts/context-compact-reminder.sh" ]; then
  exit 0
fi

input="$(cat)"
get() { printf '%s' "$input" | jq -r "$1 // empty" 2>/dev/null; }

session_id="$(get '.session_id')"
session_id="${session_id//[^a-zA-Z0-9_-]/}"
transcript="$(get '.transcript_path')"
runtime_dir="${CLAUDE_STATUSLINE_RUNTIME_DIR:-/tmp/claude}"

CACHE_MAX_AGE=300

percent=""
window=""

# 1. Statusline cache (authoritative, mirrors the footer).
if [ -n "$session_id" ] && [ -f "$runtime_dir/context-usage-${session_id}.json" ]; then
  cache_file="$runtime_dir/context-usage-${session_id}.json"
  ts="$(jq -r '.ts // 0' "$cache_file" 2>/dev/null)"
  case "$ts" in ''|*[!0-9]*) ts=0 ;; esac
  if [ $(( $(date +%s) - ts )) -le "$CACHE_MAX_AGE" ]; then
    percent="$(jq -r '.pct // empty' "$cache_file" 2>/dev/null)"
    percent="${percent%%.*}"
    window="$(jq -r '.window // empty' "$cache_file" 2>/dev/null)"
  fi
fi

# 2. Transcript fallback (headless sessions, stale/missing cache).
if [ -z "$percent" ]; then
  { [ -n "$transcript" ] && [ -f "$transcript" ]; } || exit 0

  case "${CLAUDE_COMPACT_REMINDER_WINDOW:-}" in
    ''|*[!0-9]*|0) window="" ;;
    *) window="$CLAUDE_COMPACT_REMINDER_WINDOW" ;;
  esac
  if [ -z "$window" ]; then
    # 1M: Fable/Mythos 5 (native), Opus 4.6+, and Sonnet 5 (confirmed native 1M via the statusline cache, unlike Sonnet 4.6 whose 1M is credit-gated and indistinguishable by model id -- that one keeps the conservative 200k floor here; the cache path above reports it correctly regardless).
    model="$(jq -r 'select(.isSidechain != true) | select(.message.model != null) | .message.model' "$transcript" 2>/dev/null | tail -n 1)"
    case "$model" in
      *fable-5*|*mythos-5*|*sonnet-5*|*opus-4-8*|*opus-4-7*|*opus-4-6*) window=1000000 ;;
      *) window=200000 ;;
    esac
  fi

  # Last main-thread usage record. Sidechain (subagent) entries are skipped so a parallel agent's counters never pollute the main-loop reading; a compact_boundary resets the running size to its postTokens so the first prompt after /compact reports the compacted size.
  used="$(jq -n '
    reduce inputs as $e (0;
      if (($e | type) != "object") then .
      elif ($e.isSidechain == true) then .
      elif ($e.subtype == "compact_boundary") then ($e.compactMetadata.postTokens // 0)
      elif (($e.message | type) == "object" and ($e.message.usage | type) == "object") then
        ($e.message.usage
         | ((.input_tokens // 0) + (.cache_creation_input_tokens // 0)
            + (.cache_read_input_tokens // 0) + (.output_tokens // 0)))
      else . end)' "$transcript" 2>/dev/null)"
  case "$used" in ''|*[!0-9]*) exit 0 ;; esac
  percent=$(( used * 100 / window ))
fi

case "$percent" in ''|*[!0-9]*) exit 0 ;; esac
case "$window" in ''|*[!0-9]*) window=0 ;; esac

# Tiered dedup: remind once per crossed tier per session; falling below every tier (e.g. after /compact) resets the state so tiers can fire again.
tiers="${CLAUDE_COMPACT_REMINDER_TIERS:-70 85 95}"
state_file="$runtime_dir/compact-reminder-${session_id:-unknown}.tier"

last_tier=0
[ -f "$state_file" ] && last_tier="$(cat "$state_file" 2>/dev/null)"
case "$last_tier" in ''|*[!0-9]*) last_tier=0 ;; esac

current_tier=0
for t in $tiers; do
  case "$t" in ''|*[!0-9]*) continue ;; esac
  [ "$percent" -ge "$t" ] && [ "$t" -gt "$current_tier" ] && current_tier="$t"
done

mkdir -p "$runtime_dir" 2>/dev/null

if [ "$current_tier" -eq 0 ]; then
  [ "$last_tier" -ne 0 ] && printf '0' > "$state_file" 2>/dev/null
  exit 0
fi

[ "$current_tier" -le "$last_tier" ] && exit 0

printf '%s' "$current_tier" > "$state_file" 2>/dev/null

window_label="$window"
[ "$window" -eq 0 ] && window_label="?"

jq -nc \
  --arg pct "$percent" \
  --arg win "$window_label" \
  '{systemMessage: ("上下文已用约 " + $pct + "%（窗口 " + $win + " tokens），建议运行 /compact 压缩对话。"), suppressOutput: true}'

exit 0
