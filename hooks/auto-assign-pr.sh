#!/usr/bin/env bash
# PreToolUse hook: inject --assignee @me and --draft into gh pr create commands.
# Reads tool input from stdin (JSON). Modifies command if flags are not already set.
#
# Known limitation: --assignee or -a appearing in --title text (not --body) may
# cause false-positive detection, skipping assignee injection silently.

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Strip --body/--body-file and their values before checking flags,
# to avoid false positives from body text mentioning "--assignee" or "-a".
FLAGS_ZONE=$(echo "$CMD" | sed -E 's/(--body-file|--body)[[:space:]].*//')

INJECT=""

# Inject --assignee @me if not already set (long form or -a short form)
if ! echo "$FLAGS_ZONE" | grep -qE '(--assignee[[:space:]=]| -a( |$))'; then
  INJECT="--assignee @me $INJECT"
fi

# Inject --draft if not already set
if ! echo "$FLAGS_ZONE" | grep -qE '(--draft|-d( |$))'; then
  INJECT="--draft $INJECT"
fi

if [ -n "$INJECT" ]; then
  NEW_CMD=$(echo "$CMD" | sed "s/gh pr create /gh pr create ${INJECT}/")
  jq -n --arg cmd "$NEW_CMD" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      updatedInput: { command: $cmd }
    }
  }'
fi
