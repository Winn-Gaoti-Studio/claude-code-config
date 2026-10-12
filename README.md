# claude-code-config

## Migration status

Selected settings examples, keybindings, and the public-settings validation filter are moving to
[Gaotity/harness](https://github.com/Gaotity/harness). This repository remains a publicly available historical snapshot
until a reviewed replacement is publicly accessible; it will then be archived with a link to that replacement.
Harness is currently private and does not grant an open-source license. A private migration alone does not replace
this repository's public reference role.

The two legacy hooks below are not part of the new examples. Current harness uses a post-creation assignment hook,
and the maintained statusline no longer writes the context cache expected by the old compaction reminder.
Treat the hook files as historical examples rather than current installation guidance.

A privacy-safe, curated snapshot of portable
[Claude Code](https://docs.claude.com/en/docs/claude-code) configuration.

Harness is the maintained source for personal agent configuration. This repository
is a reference for sharing selected configuration, not an installer and not a
complete copy of `~/.claude`. Review every file before adopting it.

## Shared payload

Each payload file maps to the same relative path under `~/.claude`:

- `settings.json` — a filtered portable baseline for models, effort, public
  plugins, hooks, permissions, and status lines.
- `keybindings.json` — custom key bindings.
- `hooks/auto-assign-pr.sh` — safely adds draft and self-assignee options to
  direct `gh pr create` commands.
- `hooks/context-compact-reminder.sh` — emits tiered context reminders using
  the status line's local context cache.
- `agents/executor.md` — a scoped delegated execution agent.

`AGENTS.md`, `CLAUDE.md`, `README.md`, `scripts/`, and `tests/` are
repository-maintenance metadata rather than files to copy into `~/.claude`.

## Codex project defaults

The repository tracks `.codex/config.toml` separately from the Claude Code
payload. It provides portable project-local Codex model and reasoning defaults
and is not copied into `~/.claude` by the maintainer sync.

## Status lines

The main and subagent status lines are published separately in
[Winn-Gaoti-Studio/claude-code-statusline](https://github.com/Winn-Gaoti-Studio/claude-code-statusline).
The `statusLine` and `subagentStatusLine` settings in this snapshot expect
that bundle to be installed.

```bash
curl -fsSL https://raw.githubusercontent.com/Winn-Gaoti-Studio/claude-code-statusline/main/install.sh | bash
```

## Maintainer sync

The maintainer script reads an explicit allowlist from the chezmoi source:

This is the historical export mechanism. Its original source paths have been retired; do not run it against the
current chezmoi or harness checkout. Fixture tests below remain available to inspect the old snapshot's validation.

```bash
scripts/sync-from-chezmoi.sh --check
scripts/sync-from-chezmoi.sh --write
```

Use `--source <path>` for fixtures or an alternate source root. The script
never writes to chezmoi.

The checked-in jq filter rejects unknown settings fields and only exports:

- `CLAUDE_CODE_SUBAGENT_MODEL` from `env`
- `allow` and `defaultMode` from permissions
- the two included hook commands
- plugins from reviewed public marketplaces
- GitHub-backed marketplace definitions

Run all tests before committing:

```bash
bash tests/sync-from-chezmoi.sh
bash tests/hooks.smoke.sh
```

## Intentionally excluded

The snapshot excludes credentials, API keys, OAuth tokens, sessions,
transcripts, history, caches, telemetry, plugin runtime state, project trust,
machine-specific paths, work-only configuration, unreviewed Codex settings, and
any source field that has not been explicitly classified for safe publication.
Within `.codex/`, only the reviewed project-local `config.toml` is included;
Codex sessions, caches, authentication, and runtime state remain excluded.

The user's full global agent guidance is also excluded because it contains
machine and workflow policy that is not part of this portable baseline.
