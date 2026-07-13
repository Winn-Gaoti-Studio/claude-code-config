#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FILTER="$ROOT/scripts/public-settings.jq"
MODE=""
SOURCE_ROOT=""

usage() {
  printf 'Usage: %s --check|--write [--source <chezmoi-root>]\n' "${0##*/}"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --check|--write)
      [ -z "$MODE" ] || { usage >&2; exit 2; }
      MODE="$1"
      shift
      ;;
    --source)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      SOURCE_ROOT="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
done

[ -n "$MODE" ] || { usage >&2; exit 2; }
[ -f "$FILTER" ] || { printf 'error: missing settings filter: %s\n' "$FILTER" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { printf 'error: jq is required\n' >&2; exit 2; }

if [ -z "$SOURCE_ROOT" ]; then
  command -v chezmoi >/dev/null 2>&1 || { printf 'error: chezmoi is required\n' >&2; exit 2; }
  SOURCE_ROOT="$(chezmoi source-path 2>/dev/null)" || { printf 'error: unable to resolve chezmoi source\n' >&2; exit 2; }
fi

SOURCE_PATHS=(
  "dot_claude/private_settings.json"
  "dot_claude/private_keybindings.json"
  "dot_claude/private_hooks/private_auto-assign-pr.sh"
  "dot_claude/private_hooks/private_context-compact-reminder.sh"
  "dot_claude/private_agents/executor.md"
)
DEST_PATHS=(
  "settings.json"
  "keybindings.json"
  "hooks/auto-assign-pr.sh"
  "hooks/context-compact-reminder.sh"
  "agents/executor.md"
)

for relative in "${SOURCE_PATHS[@]}"; do
  [ -f "$SOURCE_ROOT/$relative" ] || { printf 'error: missing source file: %s\n' "$SOURCE_ROOT/$relative" >&2; exit 2; }
done

TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT
if ! jq -S -f "$FILTER" "$SOURCE_ROOT/${SOURCE_PATHS[0]}" > "$TEMP_DIR/settings.json"; then
  printf 'error: settings failed public export validation\n' >&2
  exit 2
fi

for ((index = 1; index < ${#SOURCE_PATHS[@]}; index++)); do
  mkdir -p "$TEMP_DIR/$(dirname "${DEST_PATHS[index]}")"
  cp "$SOURCE_ROOT/${SOURCE_PATHS[index]}" "$TEMP_DIR/${DEST_PATHS[index]}"
done

if [ "$MODE" = "--check" ]; then
  drift=0
  for destination in "${DEST_PATHS[@]}"; do
    if ! cmp -s "$TEMP_DIR/$destination" "$ROOT/$destination"; then
      printf 'drift: %s\n' "$destination" >&2
      drift=1
    fi
  done
  exit "$drift"
fi

for destination in "${DEST_PATHS[@]}"; do
  target="$ROOT/$destination"
  mkdir -p "$(dirname "$target")"
  temporary="$(mktemp "${target}.tmp.XXXXXX")"
  cp "$TEMP_DIR/$destination" "$temporary"
  case "$destination" in
    hooks/*.sh) chmod 755 "$temporary" ;;
    *) chmod 644 "$temporary" ;;
  esac
  mv "$temporary" "$target"
  printf 'updated: %s\n' "$destination"
done
