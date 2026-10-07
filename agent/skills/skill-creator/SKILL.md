---
name: skill-creator
description: Use when the user wants to create, write, scaffold, or improve an opencode skill — triggers include "create a skill", "make a skill for X", "write a SKILL.md", "add a skill to this repo", "turn this workflow into a skill", "why doesn't my skill trigger", "improve this skill's description", "review my skill". Also use when choosing between a skill, command, agent, plugin, MCP server, or references — triggers include "should this be a skill or a command", "which extension point should I use". Produces a validated `.opencode/skills/<name>/SKILL.md`, optionally with bundled scripts/ and references/. For authoring agents, commands, or plugins themselves, load the `customize-opencode` skill instead. To audit the whole skill collection rather than one skill, use auto-skill.
---

# Create or improve an opencode skill

opencode discovers skills from `<skills-dir>/<name>/SKILL.md` and advertises
only `name` + `description` to the model. The model calls the `skill` tool to
pull in the body when the description matches. Both halves matter: the
description decides whether the skill ever loads, the body decides whether it
does anything useful.

**Skill locations:**

| Scope | Path |
|---|---|
| Project | `.opencode/skills/<name>/SKILL.md` |
| Global | `~/.config/opencode/skills/<name>/SKILL.md` |
| Compat | `.claude/skills/`, `~/.claude/skills/`, `.agents/skills/`, `~/.agents/skills/` |

Non-default locations can be registered with `"skills": { "paths": [...] }` in
`opencode.json`.

## Step 0 — confirm it should be a skill at all

The question that decides everything is **who chooses to run it**. A skill
fires because the model judged the `description` matched; a command fires
because the user typed `/name`; a plugin runs because opencode started. If the
user wants control over *when* it runs, they want a command, and a skill will
disappoint them because they cannot force it.

Before writing anything, place the request against the full extension surface
in `references/opencode-extensions.md`. Read it when the user is choosing a
mechanism, or when they ask for an agent, command, plugin, MCP server, or
`references` entry rather than a skill. It covers the routing table, the
v1-vs-v2 config key split (a wrong top-level key hard-fails startup), and the
per-mechanism frontmatter fields.

If the answer is "not a skill", say so and name the mechanism that fits before
writing any file. The rest of this skill assumes the answer was "skill".

## Step 1 — capture intent

Before writing anything, resolve these. Pull answers out of the conversation
first; the user may be describing a workflow they just performed, in which case
the tools used, step order, and corrections they made are the spec.

1. **What should the skill enable?** One job. If the answer is "and also…",
   that is two skills.
2. **When should it trigger?** Collect the literal phrases a user would type.
   These become the description.
3. **What does the agent produce?** Files, a report, a diff, a question.
4. **What must it never do?** The failure modes worth naming up front.

Ask about edge cases and dependencies. Do not write test prompts until this is
settled.

## Step 2 — write the frontmatter

```markdown
---
name: my-skill
description: Use when the user asks to <task> — triggers include "<phrase>", "<phrase>". <what it does and what it refuses to do>.
---
```

- `name` — required, 1–64 chars, `^[a-z0-9]+(-[a-z0-9]+)*$`, **must equal the
  folder name**.
- `description` — required, 1–1024 chars. This is the entire triggering
  surface; everything else lives in the body.
- Optional: `license`, `compatibility`, `metadata` (flat string map).

Write the description in third person, front-load the concrete keywords and
filenames a user would actually say, and include the negative boundary ("Not
for X") so an adjacent request doesn't drag the skill in. Undertriggering is
the common failure, so lean slightly pushy on the positive side.

## Step 3 — write the body

Imperative voice, one subject per section. Explain *why* a rule exists — a
model given the reason generalizes to cases the skill never anticipated, while
a stack of bare MUSTs just produces brittle compliance.

Useful section shapes:

- **Steps** — numbered, concrete, each with a verifiable outcome.
- **Traps / Do not** — the specific mistakes this repo's conventions invite.
- **Output format** — give the literal template when there is one.
- **Examples** — one or two real input→output pairs, not toy ones.

Keep the body under ~500 non-blank lines. Past that, move depth into
`references/` and point at it:

```
my-skill/
├── SKILL.md
├── scripts/       # deterministic work the model would otherwise rewrite
└── references/    # docs read only when the body says to read them
```

Supporting files are *sampled*, not loaded: the `skill` tool injects a list of
at most 10 sibling paths as absolute paths, and never their contents. The body
has to tell the model when to open each one.

The tool does **not** change the working directory — it prints an advisory
`Base directory for this skill: …` line and expects the model to resolve
relative paths against it. Write the repo-root path explicitly
(`.opencode/skills/<name>/scripts/x.sh`), or `${base}/scripts/x.sh`, or tell
the model to `cd` into the announced base first. A body that just says
`scripts/x.sh` is ambiguous and may resolve against the repo root instead.

Scripts earn their place when you notice the agent rewriting the same helper
every run — a validator, a scaffolder, a formatter. Deterministic work belongs
in a script, not in prose instructions.

## Step 4 — validate

```bash
.opencode/skills/skill-creator/scripts/validate-skill.sh .opencode/skills/<name>
```

Checks the filename, frontmatter delimiters, name regex, name/folder match,
description presence and length, empty body, and name collisions among
siblings. Run it before showing the user anything.

Then **restart opencode** — skills load at startup and the running session
keeps its old skill list.

## Step 5 — test the trigger, not just the body

A skill that reads well but never triggers is a dead file. First confirm it is
discovered:

```bash
opencode debug skill   # the new skill must appear in the list
```

Then measure triggering instead of eyeballing it. Read
`references/trigger-evals.md`, write ~20 labeled queries (half should-trigger,
half near-miss negatives), and run:

```bash
bash .opencode/skills/skill-creator/scripts/trigger-eval.sh queries.json <name>
```

The rate exposes the two failure modes:

- **Never loads** — the description is missing the user's vocabulary. Add the
  general category their phrasing belongs to, not the literal words.
- **Loads when it shouldn't** — the description is too broad, or an adjacent
  skill is winning. Add an explicit boundary ("Not for X").

Treat the user's real phrasing as the source of truth for the description, not
your summary of it. For a quick one-off fix a full eval is overkill — at
minimum run three real prompts and read the transcript.

## Step 6 — iterate

Read the transcript, not just the final output. If the agent wasted steps,
the body is probably prescribing an order it shouldn't. Cut what isn't pulling
its weight, then re-run.

Stop when the user is happy, the test prompts pass, or further edits aren't
producing meaningful change.

## Do not

- Put `name` in the frontmatter that differs from the folder name — opencode
  keys skills by that frontmatter `name`. On a collision the later copy wins
  and a `duplicate skill name` warning logs both locations, but disk discovery
  is concurrent, so never rely on shadowing.
- Add frontmatter fields opencode does not read (`allowed-tools` is parsed by
  other tools' loaders, not enforced here). Gate access with
  `"permission": { "skill": { "my-skill": "ask" } }` in `opencode.json`
  instead.
- Write v2 config keys (`permissions`, `agents`, `commands`, `plugins`, or
  `skills` as a bare array) against a v1 release. Run `opencode --version`
  first; a wrong top-level key is a startup failure, not a warning.
- Inline `prompt:`/`template:` bodies in `opencode.json` when a file would
  work — skills belong in files.
- Create a skill and assume it is live. Restart, then confirm it appears with
  `opencode debug skill`.
- Create a second skill that overlaps an existing one's triggers. Extend the
  existing skill, or write the boundary into both descriptions.
