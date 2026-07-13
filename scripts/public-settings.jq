def allowed_top_level:
  [
    "advisorModel",
    "agentPushNotifEnabled",
    "effortLevel",
    "enabledPlugins",
    "env",
    "extraKnownMarketplaces",
    "hooks",
    "inputNeededNotifEnabled",
    "model",
    "permissions",
    "statusLine",
    "subagentStatusLine",
    "tui",
    "ultracode"
  ];

def fail_if($condition; $message):
  if $condition then error($message) else . end;

. as $source
| fail_if(($source | type) != "object"; "settings root must be an object")
| (($source | keys_unsorted) - allowed_top_level) as $unknown
| fail_if(($unknown | length) > 0; "unknown settings keys: \($unknown | join(", "))")
| fail_if((($source.env // {}) | type) != "object"; "env must be an object")
| (($source.env // {} | keys_unsorted) - ["CLAUDE_CODE_SUBAGENT_MODEL"]) as $unknown_env
| fail_if(($unknown_env | length) > 0; "unknown environment keys: \($unknown_env | join(", "))")
| fail_if((($source.permissions // {}) | type) != "object"; "permissions must be an object")
| (($source.permissions // {} | keys_unsorted) - ["allow", "defaultMode"]) as $unknown_permissions
| fail_if(($unknown_permissions | length) > 0; "unknown permission keys: \($unknown_permissions | join(", "))")
| fail_if((($source.hooks // {}) | type) != "object"; "hooks must be an object")
| (($source.hooks // {} | keys_unsorted) - ["PreToolUse", "UserPromptSubmit"]) as $unknown_hooks
| fail_if(($unknown_hooks | length) > 0; "unknown hook events: \($unknown_hooks | join(", "))")
| [$source.hooks // {} | .. | objects | .command? // empty] as $commands
| fail_if(
    any($commands[];
      . != "bash \"$HOME/.claude/hooks/auto-assign-pr.sh\""
      and . != "bash \"$HOME/.claude/hooks/context-compact-reminder.sh\""
    );
    "hook command is not public-allowlisted"
  )
| fail_if((($source.enabledPlugins // {}) | type) != "object"; "enabledPlugins must be an object")
| [$source.enabledPlugins // {} | keys_unsorted[]] as $plugins
| fail_if(
    any($plugins[]; test("^[A-Za-z0-9._-]+@(claude-plugins-official|openai-codex)$") | not);
    "plugin is not from an allowlisted public marketplace"
  )
| fail_if((($source.extraKnownMarketplaces // {}) | type) != "object"; "extraKnownMarketplaces must be an object")
| [$source.extraKnownMarketplaces // {} | to_entries[] | .value.source] as $marketplaces
| fail_if(
    any($marketplaces[];
      (.source != "github")
      or ((.repo | type) != "string")
      or (.repo | test("^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$") | not)
    );
    "marketplace source is not a public GitHub repository"
  )
| [.. | strings] as $strings
| fail_if(
    any($strings[];
      test("/Users/|/home/[A-Za-z0-9._-]+/|gh[pousr]_[A-Za-z0-9]|sk-[A-Za-z0-9]|kira-learning|terrence-kira|SUPERSET_HOME_DIR"; "i")
    );
    "settings contain a private path, identity, or secret-like literal"
  )
| with_entries(. as $entry | select(allowed_top_level | index($entry.key)))
