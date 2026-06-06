#!/usr/bin/env bash
# Context compact reminder (UserPromptSubmit hook).
#
# Emits a JSON systemMessage when the session's context usage reaches the
# threshold, nudging the user to run /compact. systemMessage is shown to the
# user only; it is not injected into the model context, so the reminder itself
# costs no tokens.
#
# Window resolution (correct per model, in priority order):
#   1. CLAUDE_COMPACT_REMINDER_WINDOW env override, when set
#   2. context_window.context_window_size from the hook stdin, when the running
#      Claude Code build provides it. This is authoritative -- the same value
#      the footer uses -- so it is right for 200k and 1M models alike.
#   3. a model->window fallback map keyed on the transcript model id, for builds
#      whose hook stdin omits context_window.
#
# Usage percent prefers Claude Code's own context_window.used_percentage when
# present (matches the footer exactly), else recomputes from token counts.
#
# Tunables (environment overrides):
#   CLAUDE_COMPACT_REMINDER_PERCENT  threshold percent (default 70)
#   CLAUDE_COMPACT_REMINDER_WINDOW   force a context window in tokens

threshold="${CLAUDE_COMPACT_REMINDER_PERCENT:-70}"
case "$threshold" in ''|*[!0-9]*) threshold=70 ;; esac

input="$(cat)"
get() { printf '%s' "$input" | jq -r "$1 // empty" 2>/dev/null; }

transcript="$(get '.transcript_path')"

# Authoritative data from Claude Code, when this build supplies it.
stdin_size="$(get '.context_window.context_window_size')"
stdin_pct="$(get '.context_window.used_percentage')"
stdin_used="$(printf '%s' "$input" | jq -r '
  (.context_window.current_usage // empty)
  | ((.input_tokens // 0) + (.cache_creation_input_tokens // 0)
     + (.cache_read_input_tokens // 0) + (.output_tokens // 0))' 2>/dev/null)"

# Model -> context window fallback map (Claude Code, paid plans).
# 1M: Opus 4.6/4.7/4.8. 200k: everything else (Sonnet 4.5/Haiku 4.5/older Opus).
# Sonnet 4.6's 1M is credit-gated and indistinguishable by model id, so it stays
# at the 200k floor here; the stdin context_window path is the only fully
# reliable source for such cases.
window_for_model() {
  case "$1" in
    *opus-4-8*|*opus-4-7*|*opus-4-6*) printf 1000000 ;;
    *) printf 200000 ;;
  esac
}

# Resolve the window: env > stdin > model map.
window=""
case "${CLAUDE_COMPACT_REMINDER_WINDOW:-}" in
  ''|*[!0-9]*|0) ;;
  *) window="$CLAUDE_COMPACT_REMINDER_WINDOW" ;;
esac
if [ -z "$window" ]; then
  case "$stdin_size" in [1-9]*) window="$stdin_size" ;; esac
fi
if [ -z "$window" ]; then
  model=""
  [ -n "$transcript" ] && [ -f "$transcript" ] && \
    model="$(jq -r 'select(.message.model != null) | .message.model' "$transcript" 2>/dev/null | tail -n 1)"
  window="$(window_for_model "$model")"
fi

# Resolve usage percent: Claude Code's own value > stdin tokens > transcript.
# Prefer the footer's exact percentage, unless the window was force-overridden.
percent=""
if [ -z "${CLAUDE_COMPACT_REMINDER_WINDOW:-}" ] && [ -n "$stdin_pct" ]; then
  percent="${stdin_pct%%.*}"
fi
if [ -z "$percent" ]; then
  used=""
  case "$stdin_used" in [0-9]*) used="$stdin_used" ;; esac
  if [ -z "$used" ] && [ -n "$transcript" ] && [ -f "$transcript" ]; then
    used="$(jq -r '
      select(.message.usage != null) | .message.usage
      | ((.input_tokens // 0) + (.cache_creation_input_tokens // 0)
         + (.cache_read_input_tokens // 0) + (.output_tokens // 0))' "$transcript" 2>/dev/null | tail -n 1)"
  fi
  case "$used" in ''|*[!0-9]*) exit 0 ;; esac
  percent=$(( used * 100 / window ))
fi

case "$percent" in ''|*[!0-9]*) exit 0 ;; esac

if [ "$percent" -ge "$threshold" ]; then
  jq -nc \
    --arg pct "$percent" \
    --arg win "$window" \
    '{systemMessage: ("上下文已用约 " + $pct + "%(窗口 " + $win + " tokens),建议运行 /compact 压缩对话以释放空间。"), suppressOutput: true}'
fi

exit 0
