# opencode extension surface

Research notes for choosing and configuring opencode extensions. Everything
here was read out of the `anomalyco/opencode` source and the shipped
`customize-opencode` skill, cross-checked against DeepWiki.

Two facts to hold onto:

- **Config is loaded once at startup and is not hot-reloaded.** After writing
  any file under this table, tell the user to quit and restart opencode.
- **A wrong top-level key in `opencode.json` is a hard failure**, not a
  warning — unknown keys are rejected with `ConfigInvalidError` and opencode
  refuses to start. Verify a shape before writing it.

## Pick the extension point

| The user needs | Use | Where |
|---|---|---|
| Instructions the *model* pulls in when a task matches | skill | `.opencode/skills/<name>/SKILL.md` |
| A prompt the *user* invokes by name | command | `.opencode/commands/<name>.md` |
| A dedicated persona with its own permissions | agent | `.opencode/agents/<name>.md` |
| Runtime interception — rewrite tool args, inject env, edit the prompt | plugin | `.opencode/plugins/*.ts` |
| External tools and their prompts | MCP server | `mcp:` in `opencode.json` |
| An outside directory or Git repo readable via `@` | references | `references:` in `opencode.json` |
| Standing rules for the whole project | rules | `AGENTS.md` at the repo root |

The decision that actually matters is **who decides it runs**. A skill runs
because the model judged the description matched; a command runs because the
user typed `/name`; an agent runs because something delegated to it; a plugin
runs because opencode started. If the user wants to be in control of *when*,
it is a command, not a skill — a skill fires on the model's judgment and the
user cannot force it except via `@` autocomplete.

Skills, commands, and agents are all markdown files with YAML frontmatter and
share a directory convention. Plugins are TypeScript. Reach for a plugin only
when no declarative file can express the behaviour.

## v1 vs v2 config keys

The installed release (1.18.34) reads the **v1 singular keys**. `packages/core`
on `main` has a v2 schema with **plural keys and array shapes**. A migration
layer (`ConfigMigrateV1.migrate`) rewrites v1 → v2 on load, so v1 files still
work, but writing v2 keys against a v1 binary is the "unknown key" hard
failure above. Check `opencode --version` before choosing.

| Concern | v1 (what the release reads) | v2 (`packages/core`) |
|---|---|---|
| Permissions | `permission` — object keyed by tool | `permissions` — ordered array of `{action, resource, effect}` |
| Agents | `agent` — object keyed by name | `agents` |
| Commands | `command` — object keyed by name | `commands` |
| Plugins | `plugin` — array | `plugins` |
| Skills | `skills` — object `{paths, urls}` | `skills` — bare array |

Within a `permission` object, **insertion order matters and the last matching
rule wins** — put `"*"` first and narrow rules after it.

## Skills

Discovery scans `**/SKILL.md` under each config directory, walking up from
the cwd to the git worktree. Both `skill/` and `skills/` are accepted, as are
`.claude/skills/` and `.agents/skills/`. Frontmatter fields read are exactly
`name` and `description`; `license`, `compatibility`, and `metadata` are
tolerated and ignored. Unknown fields are silently dropped.

A skill is **keyed by its frontmatter `name`, not its path**. On a collision
the later-registered copy overwrites the earlier one and a
`duplicate skill name` warning logs both locations — but disk discovery runs
concurrently, so ordering between on-disk sources is not deterministic. Keep
names unique across every location; do not rely on shadowing.

When the `skill` tool loads a body it injects the file's *name and a sampled
list of sibling files (max 10) as absolute paths.* Supporting file **contents
are never loaded** — the body has to tell the model when to read one. The tool
does **not** change the working directory; it prints an advisory
`Base directory for this skill: …` line. A body that says
`scripts/validate.sh` will fail unless the model resolves it against that
announced base directory.

Gate a skill with `"permission": { "skill": { "my-skill": "ask" } }`. There is
**no** `disable-model-invocation` and no `allowed-tools` in the shipped code —
both are v2-doc-only or other tools' conventions.

## Commands

Directory scan is `**/*.md` under `command/`/`commands/`; the name comes from
the path with the extension stripped, so subdirectories become
`parent/child` names.

Fields read: `description`, `agent`, `model`, `variant`, `subtask`. **The
trimmed body is the `template`** and always overrides a `template:` key — do
not put `template` in the frontmatter. `$ARGUMENTS` expands to everything
after the command name; `$1`, `$2`, … are positional. `subtask: true` forces
execution in a subagent so the command does not pollute the primary context.

Two in-body macros: `` !`cmd` `` injects shell output into the prompt, and
`@path` inlines a file. Both expand before the model sees the prompt and both
bypass the tool permission flow — never place untrusted input inside them.

Skills are registered into the same command registry, but **a command of the
same name wins**; a skill never overwrites a command. That is why a skill named
like an existing slash command still loads fine via the `skill` tool.

Precedence for definitions, lowest to highest: remote config → global config →
`OPENCODE_CONFIG` → project `opencode.json` → `.opencode` directories →
`OPENCODE_CONFIG_CONTENT` → managed config → macOS managed preferences.
Configs merge rather than replace; only conflicting keys are overridden.

## Agents

Fields read: `name`, `model`, `variant`, `description`, `mode`, `hidden`,
`color`, `steps`, `options`, `permission`, `disable`, `temperature`, `top_p`.
The trimmed body becomes the agent's `prompt` — do not also set `prompt:` in
the frontmatter. **Any unrecognised frontmatter field is silently routed into
`options` and forwarded to the provider**, so a typo like `temperture` fails
silently instead of loudly.

`mode` is `primary`, `subagent`, or `all` (the default when omitted).
Built-ins are `build`, `plan`, `general`, `explore`, plus hidden `compaction`,
`title`, and `summary`; define a key of the same name to override one. Disable
a built-in with `disable: true`. `opencode agent create` scaffolds an agent
interactively and prompts for its permissions.

A subagent does **not** inherit its parent's allowed tools. The child session
inherits only the parent's `deny` rules and `external_directory` rules; the
child's own `permission` block decides what it may do, and `todowrite` and
`task` are denied by default unless the subagent's own ruleset grants them.
Nesting depth defaults to 1 (`subagent_depth`), so subagents cannot spawn
subagents out of the box. `hidden: true` only affects `@` autocomplete — it is
a visibility control, not a security control.

## Plugins

Auto-discovered from `*.ts` / `*.js` in `.opencode/plugin/` or
`.opencode/plugins/` (flat, not recursive), or declared in `plugin:` as an npm
spec, a file path, a `file://` URL, or a `[name, options]` tuple. TypeScript
loads directly — no build step — and `@opencode-ai/plugin` is installed into
the config directory for you, so `import type { Plugin }` resolves.

A plugin exports **a function that returns a hooks object**. Return `{}` when
there is nothing to register.

```ts
import type { Plugin } from "@opencode-ai/plugin"

export default (async ({ client, project, directory, $ }) => {
  return {
    "tool.execute.before": async (input, output) => {
      output.args.command = redact(output.args.command)
    },
  }
}) satisfies Plugin
```

**Every hook mutates its second `output` argument in place and returns
`void`.** All hooks are typed `Promise<void>` and the runtime discards the
return value entirely — returning a modified object does nothing. The `trigger`
helper hands each hook the same `output` reference sequentially, so a later
plugin observes an earlier plugin's edits. Throw to abort.

Callback hooks: `event(input)`, `config(cfg)`, `chat.message`, `chat.params`,
`chat.headers`, `tool.execute.before`, `tool.execute.after`, `tool.definition`,
`command.execute.before`, `shell.env`, `permission.ask`, `dispose`, and the
`experimental.*` family (`chat.messages.transform`, `chat.system.transform`,
`provider.small_model`, `session.compacting`, `compaction.autocontinue`,
`text.complete`).

Object-shaped, **not** callbacks: `tool` (register a custom LLM-callable tool),
`auth`, `provider`.

Two traps: every module export must be a function, or loading fails with
`Plugin export is not a function`; and `permission.ask` is declared in the
types but has no trigger site in the shipped source — do not depend on it.

`config` receives the merged config once at init and is the last programmatic
override short of managed config. Errors from it are swallowed. Use
`client.app.log()` rather than `console.log` for structured logging, and
`client.tui.*` for toasts and prompt injection.

## MCP servers

`mcp:` is an object keyed by server name. `type` is required — `local` (with
`command` as an **array** of strings, never a bare string) or `remote` (with
`url` and optional `headers`). Set `enabled: false` to switch off a server
inherited from a parent config. String values interpolate `{env:VAR}` and
`{file:path}` — the shell-style `${VAR}` is *not* substituted.

## References

`references:` mounts a directory or Git repository outside the project as
context reachable through `@` autocomplete. It is an object keyed by alias;
each value is a local path (relative to the declaring config, absolute, or
`~/`) or `{repository, branch}` for Git, with string shorthand accepted. Only
references that carry a `description` are advertised to agents, so the
description is not optional in practice. `hidden: true` removes an alias from
TUI autocomplete only — it stays available to agents. Mounted directories are
automatically allowed through the `external_directory` boundary, though normal
read/edit permissions still apply.

## Permissions

`permission:` is either a bare action string or an object keyed by tool name,
whose value is an action or a `{pattern: action}` map. Actions are `allow`,
`ask`, `deny`. Known keys: `read`, `edit`, `glob`, `grep`, `list`, `bash`,
`task`, `external_directory`, `todowrite`, `question`, `webfetch`, `websearch`,
`lsp`, `doom_loop`, `skill`. Only the pattern-map form is accepted for `read`,
`edit`, `glob`, `grep`, `list`, `bash`, `task`, `external_directory`, `lsp`,
and `skill`; the rest take a flat action.

Per-agent `permission:` overrides the top-level block. A top-level
`permission: "allow"` means allow everything and is rarely what a user wants.

## Escape hatches

When a user's config is broken and opencode will not start:

| Variable | Effect |
|---|---|
| `OPENCODE_DISABLE_PROJECT_CONFIG=1` | skip project config, start from globals |
| `OPENCODE_CONFIG=/path/to.json` | load an additional explicit config |
| `OPENCODE_CONFIG_CONTENT='{...}'` | inject inline JSON as a final merge |
| `OPENCODE_DISABLE_DEFAULT_PLUGINS=1` | skip built-in plugins |
| `OPENCODE_PURE=1` | skip external plugins entirely |
| `OPENCODE_DISABLE_EXTERNAL_SKILLS=1` | skip `~/.claude` and `~/.agents` skill scans |
| `OPENCODE_DISABLE_CLAUDE_CODE_SKILLS=1` | skip only `~/.claude` skills |

## Where the truth lives

- **`<https://opencode.ai/config.json>`** — the published JSON Schema. Fetch
  and read it before writing any config shape not shown above.
- **`customize-opencode`** — opencode's own built-in skill, shipped in the
  binary. Load it with the `skill` tool for the maintained version of this
  material, including the built-in agent list and the plugin type surface.
- **`opencode debug skill`** — undocumented, but prints every discovered skill
  as JSON including its resolved `location`. This is how you find out why a
  skill is not being discovered.
- **`opencode --version`** — settles whether you are writing v1 or v2 keys.