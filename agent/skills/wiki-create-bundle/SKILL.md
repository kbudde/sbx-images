---
name: wiki-create-bundle
description: Use when the user asks to create, scaffold, or add a new OKF bundle (a self-contained Obsidian vault) under bundles/ — triggers include "create bundle", "/create-bundle research", "new vault for my reading notes", "set up a second knowledge base". Runs scripts/create-bundle.sh and verifies the result.
---

# Create an OKF bundle

Operates the wiki described by `AGENT.md` at the repo root. Read `AGENT.md`
§ "Create a bundle" before starting.

## Procedure

**Run the script. Do not hand-implement the nine steps** — `scripts/create-bundle.sh`
is the executable source of truth for scaffolding:

```bash
./scripts/create-bundle.sh <kebab-case-name>
```

`-h` / `--help` prints usage. It requires bash 3.2+, an existing
`bundles/main/` to copy from, and a name matching `^[a-z][a-z0-9-]*$`. It
refuses to overwrite an existing bundle.

Then verify and report:

1. `ls` the new bundle — expect `.obsidian/`, `templates/`, `raw/`, `sources/`,
   `entities/`, `concepts/`, `synthesis/`, `index.md`, `log.md`.
2. Confirm `.obsidian/` holds exactly five files — `app.json`,
   `appearance.json`, `core-plugins.json`, `community-plugins.json`,
   `templates.json` — plus `workspace.json` **absent**. That omission is
   deliberate so each vault generates a fresh workspace.
3. Confirm `templates/` received all three files (`concept.md`,
   `source-summary.md`, `log-entry.md`) and `raw/.gitkeep` exists.
4. Confirm `log.md` carries an `## YYYY-MM-DD` heading dated today with an
   `**Initialization**` entry.
5. Tell the user how to open it: Obsidian → "Open folder as vault" →
   select `bundles/<name>/`. And that switching the active bundle is just
   saying so.

## Traps

- **`workspace.json` must not be copied.** An earlier create-bundle skill
  (`.claude/skills/create-bundle.md`, since removed) step 3 listed it among the
  config files *and then contradicted itself* — the "Do NOT copy" rule wins.
  The script already implements the correct behavior.
- **Scaffolding is specified in four places.** Any change to bundle structure
  must land in all of them or the docs lie:
  1. `scripts/create-bundle.sh`
  2. `.opencode/skills/wiki-create-bundle/SKILL.md` (this skill)
  3. `AGENT.md` § "Create a bundle"
  4. `QUICKSTART.md` § "Create additional bundles" Option C
- The root `index.md` the script writes carries `okf_wiki_version: "0.1"` in its
  frontmatter. Preserve it on any later edit.
- A new bundle is an independent vault — its internal links are relative to
  *its own* root, never the repo root.

## Do not

- Overwrite or scaffold inside an existing bundle.
- Edit `.obsidian/` config files in `bundles/main/`.
- Modify `AGENT.md`, `SPEC.md`, `CLAUDE.md`, or any of the four create-bundle
  references without asking — they are on `AGENT.md`'s "ask first" list, and
  `SPEC.md` §4.0 enumerates the repo layout.