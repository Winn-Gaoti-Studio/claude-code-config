# Agent Guidelines

Docs and Git commits must be in English. Respond to users in Simplified Chinese.

## Repository Purpose

This repository is a privacy-safe, curated publication subset of the user's
Claude Code configuration. The private chezmoi source is canonical; this
repository is a reference snapshot, not an installer or an independent source of
truth.

The exported payload is limited to:

- `settings.json`
- `keybindings.json`
- `hooks/auto-assign-pr.sh`
- `hooks/context-compact-reminder.sh`
- `agents/executor.md`

Repository metadata such as this file, `CLAUDE.md`, `README.md`, tests, and
maintainer scripts is not installed under `~/.claude`.

## Maintenance

```bash
scripts/sync-from-chezmoi.sh --check
scripts/sync-from-chezmoi.sh --write
bash tests/sync-from-chezmoi.sh
bash tests/hooks.smoke.sh
```

The settings filter is fail-closed. New top-level keys, environment variables,
permission fields, hook events, hook commands, plugin marketplaces, private
paths, identity strings, and secret-like values require explicit review before
export.

## Safety

- Never publish credentials, tokens, sessions, transcripts, history, caches,
  plugin runtime state, absolute identity paths, or work-only configuration.
- Keep `.codex/` and local tooling out of Git.
- Do not edit exported payload files independently of the chezmoi source.
- Preserve unrelated changes.
- Add failing tests before behavior changes.
- Run every test and review the staged diff before committing.
- Use Conventional Commits and signed commits only.
