---
name: wiki-page
description: Use when the user asks to create, write, file, edit, or update a single OKF wiki page — triggers include "add a page on X", "write a concept page", "new entity page for Y", "update the Style guide page", "fix this page", "rewrite the overview", "add a section to Z", "refresh the index". Also use when a page already exists but its timestamp, links, or index entries are stale. Not for ingesting a whole source (use wiki-ingest) or for auditing the whole wiki (use wiki-lint).
---

# Create or update one wiki page

Operates the wiki described by `AGENT.md` at the repo root. Read `AGENT.md`
§ "Conventions" and § "Update the index" before starting.

**Active bundle:** `bundles/main/` unless the user named another bundle. All
paths below are bundle-root relative — the bundle *is* the Obsidian vault
root.

## Steps

1. **Locate before creating.** Read the root `index.md` and the relevant
   directory's `index.md` (`sources/`, `entities/`, `concepts/`,
   `synthesis/`). If a page for the subject already exists, this is an
   **update**, not a create — do not add a near-duplicate.
2. **Pick the type** from the taxonomy in `AGENT.md` § Type values and put the
   page in the matching directory. Never change an existing page's `type`.
3. **Write the frontmatter** (see below), preserving every key already on the
   page when editing — `tags`, `source`, `resource` must survive an edit.
4. **Write the body.** Lead with the claim. Use headings, lists, tables, and
   fenced blocks. Cite sources inline as `[1]` against a `# Citations` or
   `# References` section. One subject per page — if it sprawls, say so and
   offer to split rather than splitting silently.
5. **Cross-link.** Link the first mention of any entity or concept that has its
   own page, and add the reciprocal link from that page back.
6. **Update both indexes** by calling the verb once per index file — the
   `index` verb writes the entry into the correct root section or directory
   index, emits `%20`, and **refuses an empty description**, which is the one
   guarantee that the entry matches the frontmatter:

   ```bash
   bash .opencode/skills/wiki-page/scripts/wiki-helpers.sh index <bundle> <dir> <name> <desc>
   ```

   Pass the frontmatter `description` as `<desc>`, **verbatim**. Do not
   hand-write the bullet: the step-6 rule is that entry text equals the
   description, and paraphrasing it is the single most common way this step
   goes wrong — a link check later catches five paraphrased entries at once,
   and fixing them costs more than calling the verb would have. Preserve the
   root `index.md` frontmatter key `okf_wiki_version: "0.1"`.
7. **Append to `log.md`** with today's date heading and a bolded `**Creation**`
   or `**Update**` action word:

   ```bash
   bash .opencode/skills/wiki-page/scripts/wiki-helpers.sh log <bundle> <action> <message>
   ```

## Frontmatter

```yaml
---
type: source-summary | entity | concept | synthesis | query
title: "Display Name"
description: "One sentence, used verbatim as the index entry"
tags: []
timestamp: 2026-06-30T00:00:00Z
source: "https://..." # source-summary only, required
---
```

- `title` and `description` are **double-quoted** in the committed pages
  because the values contain spaces. Templates emit `title: "{{title}}"`.
- `timestamp` is ISO 8601 with a `Z` suffix, and must be **bumped on every
  edit**.
- `source:` holds a full URL in practice, not a path under `raw/`. For a
  `source-summary`, `source:` is required and non-empty.

## Filenames: follow precedent, not the docs

`AGENT.md` and `SPEC.md` say `kebab-case.md`. Every committed page in
`bundles/tech/` is **Title Case with spaces** — `MicroVM isolation.md`,
`Proxy-managed credentials.md`, `Model provider allowlist.md`. Match the
precedent: a `kebab-case` page would break every existing absolute link into the
bundle.

(Those examples were `Exempli gratia.md`, `Id est.md`, `Style guide.md`, and
`Wikipedia.md` until 2026-10-03, when the placeholder cluster was deprecated.
They are gone; the live pages above replaced them.)

**Execution history:** `.opencode/skills/auto-skill/history/wiki-page.md` records what
this skill got wrong in past sessions, with the evidence. Read it before
changing this skill's steps, traps, or scripts; `auto-skill` writes it.

## Do not

- Edit `raw/`, `templates/`, or `.obsidian/` — `raw/` is immutable source
  material and gets no frontmatter.
- Use `index.md` or `log.md` as a concept page; both are reserved at every
  directory level.
- Use relative links (`./`) for cross-page references — bundle-root absolute
  only, or Obsidian will not resolve them.
- Drop frontmatter keys when editing, or change a page's `type`.
- Delete, rename, or restructure pages without asking — that is on
  `AGENT.md`'s "ask first" list, as is modifying `AGENT.md`, `SPEC.md`, or
  `CLAUDE.md`.
- **Wrap inside a link.** Every page here links to a Title Case filename, so
  every link target contains a space — and a markdown link target cannot span a
  line break. Hard-wrapping at 80 columns in the middle of `](/concepts/Style
  guide.md)` silently breaks the link. Four such links exist in
  `synthesis/Choosing an architecture in Go.md` and one malformed target in
  `concepts/Monolith first.md`. `wrap` exempts link lines; `links` is the
  detector.
- **Hand-write a regex to check link form.** `grep` runs ripgrep's engine, which
  has **no look-around**: `(?!`, `(?=`, `(?<=` and `(?<!` fail with
  `look-around, including look-ahead and look-behind is not supported`.
  Escaped `\(` / `\)` mixed into an alternation failed twice more with
  `unclosed group`. Five of seventeen failed calls in one session were this, all
  of them an attempt to find link targets by pattern. The script already does
  it — use `wiki-helpers.sh links <file>` below, or `literal: true`. Do not
  reconstruct it as a regex over `](/...)`.

## Scripts

`.opencode/skills/wiki-page/scripts/wiki-helpers.sh` provides deterministic
helpers — use them instead of rewriting the logic. Always call it by this
repo-root-relative path: the `skill` tool does not change the working
directory, so a bare `scripts/...` resolves against the repo root and fails.

```bash
# Bump timestamp on a page
bash .opencode/skills/wiki-page/scripts/wiki-helpers.sh bump <file>

# Add entry to directory index
bash .opencode/skills/wiki-page/scripts/wiki-helpers.sh index <bundle> <dir> <name> <desc>

# Append entry to log.md
bash .opencode/skills/wiki-page/scripts/wiki-helpers.sh log <bundle> <action> <message>

# Validate frontmatter completeness
bash .opencode/skills/wiki-page/scripts/wiki-helpers.sh validate <file>

# Check all bundle-relative links resolve
bash .opencode/skills/wiki-page/scripts/wiki-helpers.sh links <file>

# Check [n] citation markers are defined where they are used
bash .opencode/skills/wiki-page/scripts/wiki-helpers.sh citations <file>

# Check prose wraps and flag unexpected glyphs
bash .opencode/skills/wiki-page/scripts/wiki-helpers.sh wrap <file> [limit]

# validate + citations + links over every page in a bundle, in one call
bash .opencode/skills/wiki-page/scripts/wiki-helpers.sh sweep <bundle> [--wrap]

# Sweep the repo for every mention of a path or string (report-only)
bash .opencode/skills/wiki-page/scripts/wiki-helpers.sh refs <needle>
```

`bump` accepts several files at once. `index` percent-encodes the target and
inserts into the right section of the root index. `links`, `citations`,
`wrap` and `sweep` exit non-zero on findings — that is the signal, not a
failure.

`sweep` is the one to reach for before reporting a page filed: it runs the
three per-page checks over the whole bundle and prints only the findings.
`--wrap` is opt-in because the committed bundles carry pre-existing
one-or-two-column overruns, so including it by default would make the verb
permanently red.

## Wrap

Hard-wrap prose at ~80 columns. Tables, link lists, and citation URLs
intentionally run longer — match the surrounding page instead of re-wrapping
the whole file.