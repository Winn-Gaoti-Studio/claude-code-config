# claude-code-config

A privacy-safe, curated snapshot of portable
[Claude Code](https://docs.claude.com/en/docs/claude-code) configuration.

The private chezmoi dotfiles repository is the canonical source. This repository
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

## Status lines

The main and subagent status lines are published separately in
[Gaotity/claude-statusline](https://github.com/Gaotity/claude-statusline).
The `statusLine` and `subagentStatusLine` settings in this snapshot expect
that bundle to be installed.

```bash
curl -fsSL https://raw.githubusercontent.com/Gaotity/claude-statusline/main/install.sh | bash
```

## Maintainer sync

The maintainer script reads an explicit allowlist from the chezmoi source:

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
machine-specific paths, work-only configuration, local `.codex/` settings, and
any source field that has not been explicitly classified for safe publication.

The user's full global agent guidance is also excluded because it contains
machine and workflow policy that is not part of this portable baseline.
