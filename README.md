# claude-code-config

A curated snapshot of my [Claude Code](https://docs.claude.com/en/docs/claude-code) global configuration (the
contents of `~/.claude`), shared as a recommended baseline.

This repository is a **reference**, not an installer. Nothing here will touch
your machine unless you copy a file yourself. Review each piece, take what you
like, and never blindly overwrite your own `~/.claude`.

## What lives here, and where it goes

Each tracked file maps to the same relative path under `~/.claude`:

- **`CLAUDE.md`** → `~/.claude/CLAUDE.md` — global agent guidelines applied to
  every project (communication style, git workflow, code style, behavioral
  guardrails).
- **`settings.json`** → `~/.claude/settings.json` — main settings: model and
  effort defaults, theme, enabled plugins, hooks, status line, permissions, and
  a few non-secret environment variables. Contains personal preferences; treat
  it as a starting point rather than a drop-in.
- **`keybindings.json`** → `~/.claude/keybindings.json` — custom key bindings.
- **`output-styles/formal.md`** → `~/.claude/output-styles/formal.md` — a custom
  output style ("Formal") selectable via `/output-style`.
- **`hooks/auto-assign-pr.sh`**, **`hooks/context-compact-reminder.sh`** →
  `~/.claude/hooks/` — hook scripts referenced from `settings.json`.

## Recommended plugins

These are the plugins I keep enabled, grouped by the marketplace they come from.
Add a marketplace, then install the plugins from it.

**`anthropics/claude-plugins-official`** (marketplace `claude-plugins-official`):
`context7`, `code-review`, `commit-commands`, `claude-md-management`,
`pr-review-toolkit`, `typescript-lsp`, `playwright`, `linear`, `superpowers`,
`slack`, `notion`, `sentry`, `posthog`, `security-guidance`.

**`anthropics/skills`** (marketplace `anthropic-agent-skills`): `claude-api`.

**`forrestchang/andrej-karpathy-skills`** (marketplace `karpathy-skills`):
`andrej-karpathy-skills`.

## Recommended standalone skills

A few third-party skills live under `~/.claude/skills/`. They are not vendored
here — install them from their own marketplaces so attribution and updates stay
intact:

- **Tavily suite** (`tavily-search`, `tavily-extract`, `tavily-crawl`,
  `tavily-map`, `tavily-research`, `tavily-cli`, `tavily-best-practices`,
  `tavily-dynamic-search`) — from `tavily-ai/skills`.
- **`find-skills`** — helps discover and install additional skills.

## Status line

The custom status line lives in its own repository,
[`terrence-kira/claude-statusline`](https://github.com/terrence-kira/claude-statusline),
so its updates and attribution stay there rather than being vendored here. The
`statusLine` block in `settings.json` still points at `~/.claude/statusline.sh`;
install or update that script from the upstream repo:

```bash
curl -fsSL https://raw.githubusercontent.com/terrence-kira/claude-statusline/main/install.sh | bash
```

## What is intentionally excluded

To keep this safe to share, everything outside the allowlist above is excluded —
in particular conversation transcripts (`projects/`, `sessions/`,
`transcripts/`, `history.jsonl`), caches and runtime state (`cache/`, `daemon*`,
`security/`, `telemetry/`), credentials, and any machine-specific install paths
(e.g. the raw `plugins/installed_plugins.json`, whose contents are summarized
above as a recommended-install list instead).
