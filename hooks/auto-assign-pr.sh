#!/usr/bin/env bash
# PreToolUse hook: inject --assignee @me and --draft into direct gh pr create commands.
# Reads tool input from stdin (JSON) and fails open without output.

set -u

for dependency in cat jq sed; do
  command -v "$dependency" >/dev/null 2>&1 || exit 0
done
[ -x /usr/bin/env ] || exit 0
[ -x /bin/bash ] || exit 0

INPUT="$(cat 2>/dev/null)" || exit 0
if ! CMD="$(printf '%s' "$INPUT" | jq -er '
  .tool_input.command
  | select(type == "string" and length > 0)
' 2>/dev/null)"; then
  exit 0
fi

MAX_COMMAND_CHARS=8192
[ "${#CMD}" -le "$MAX_COMMAND_CHARS" ] || exit 0

case "$CMD" in
  *$'\r'*|*$'\n'*) exit 0 ;;
esac
[[ "$CMD" =~ ^[[:blank:]]*gh[[:blank:]]+pr[[:blank:]]+create([[:blank:]]|$) ]] || exit 0
/usr/bin/env -i PATH=/usr/bin:/bin LC_ALL=C /bin/bash --noprofile --norc -n -c "$CMD" >/dev/null 2>&1 || exit 0

contains_shell_expansion() {
  local input="$1"
  local length="${#input}"
  local index=0
  local char
  local next
  local state="plain"

  while [ "$index" -lt "$length" ]; do
    char="${input:index:1}"
    case "$state" in
      plain)
        case "$char" in
          "'") state="single" ;;
          '"') state="double" ;;
          \\)
            index=$((index + 1))
            [ "$index" -lt "$length" ] || return 0
            ;;
          '$'|'`') return 0 ;;
          '<'|'>')
            next="${input:index+1:1}"
            [ "$next" = "(" ] && return 0
            ;;
        esac
        ;;
      single)
        [ "$char" = "'" ] && state="plain"
        ;;
      double)
        case "$char" in
          '"') state="plain" ;;
          \\)
            index=$((index + 1))
            [ "$index" -lt "$length" ] || return 0
            ;;
          '$'|'`') return 0 ;;
        esac
        ;;
    esac
    index=$((index + 1))
  done

  return 1
}

# The option scanner does not evaluate shell expansions; leave real expansions unchanged.
contains_shell_expansion "$CMD" && exit 0

split_command_words() {
  local input="$1"
  local length="${#input}"
  local index=0
  local char
  local state="plain"
  local word=""
  local started=0

  COMMAND_WORDS=()

  while [ "$index" -lt "$length" ]; do
    char="${input:index:1}"
    case "$state" in
      plain)
        if [[ "$char" =~ [[:blank:]] ]]; then
          if [ "$started" -eq 1 ]; then
            COMMAND_WORDS+=("$word")
            word=""
            started=0
          fi
        else
          case "$char" in
            "'") state="single"; started=1 ;;
            '"') state="double"; started=1 ;;
            \\)
              index=$((index + 1))
              [ "$index" -lt "$length" ] || return 1
              word="${word}${input:index:1}"
              started=1
              ;;
            *) word="${word}${char}"; started=1 ;;
          esac
        fi
        ;;
      single)
        if [ "$char" = "'" ]; then
          state="plain"
        else
          word="${word}${char}"
        fi
        ;;
      double)
        case "$char" in
          '"') state="plain" ;;
          \\)
            index=$((index + 1))
            [ "$index" -lt "$length" ] || return 1
            word="${word}${input:index:1}"
            ;;
          *) word="${word}${char}" ;;
        esac
        ;;
    esac
    index=$((index + 1))
  done

  [ "$state" = "plain" ] || return 1
  if [ "$started" -eq 1 ]; then
    COMMAND_WORDS+=("$word")
  fi
}

split_command_words "$CMD" || exit 0
[ "${#COMMAND_WORDS[@]}" -ge 3 ] || exit 0
[ "${COMMAND_WORDS[0]}" = "gh" ] || exit 0
[ "${COMMAND_WORDS[1]}" = "pr" ] || exit 0
[ "${COMMAND_WORDS[2]}" = "create" ] || exit 0

HAS_ASSIGNEE=0
HAS_DRAFT=0
SKIP_VALUE=0

for ((index = 3; index < ${#COMMAND_WORDS[@]}; index++)); do
  token="${COMMAND_WORDS[index]}"
  if [ "$SKIP_VALUE" -eq 1 ]; then
    SKIP_VALUE=0
    continue
  fi
  case "$token" in
    --) break ;;
    --assignee|-a) HAS_ASSIGNEE=1; SKIP_VALUE=1 ;;
    --assignee=*|-a=*|-a?*) HAS_ASSIGNEE=1 ;;
    --draft|-d|--draft=*|-d=*|-d?*) HAS_DRAFT=1 ;;
    --base|-B|--body|-b|--body-file|-F|--head|-H|--label|-l|--milestone|-m|--project|-p|--recover|--repo|-R|--reviewer|-r|--template|-T|--title|-t)
      SKIP_VALUE=1
      ;;
  esac
done

INJECT=""
if [ "$HAS_DRAFT" -eq 0 ]; then
  INJECT="--draft"
fi
if [ "$HAS_ASSIGNEE" -eq 0 ]; then
  if [ -n "$INJECT" ]; then
    INJECT="$INJECT --assignee @me"
  else
    INJECT="--assignee @me"
  fi
fi

[ -n "$INJECT" ] || exit 0

NEW_CMD="$(printf '%s' "$CMD" | sed -E "s/^([[:blank:]]*gh[[:blank:]]+pr[[:blank:]]+create)([[:blank:]]|$)/\\1 ${INJECT}\\2/" 2>/dev/null)" || exit 0
[ -n "$NEW_CMD" ] || exit 0
[ "$NEW_CMD" != "$CMD" ] || exit 0

OUTPUT="$(jq -n --arg cmd "$NEW_CMD" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    updatedInput: { command: $cmd }
  }
}' 2>/dev/null)" || exit 0
[ -n "$OUTPUT" ] || exit 0
printf '%s\n' "$OUTPUT"
