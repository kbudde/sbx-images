---
name: wiki-query
description: Use when the user asks a question whose answer lives in the OKF wiki — triggers include "what does the wiki know about", "compare X and Y", "what contradictions exist between our sources", "who wrote Y", "what did the Z article say". Reads index.md and cited pages, synthesizes a cited answer, then offers to file it as a query or synthesis page.
---

# Answer a question from the OKF wiki

Operates the wiki described by `AGENT.md` at the repo root. Read `AGENT.md`
§ "Answer a query" before starting.

**Active bundle:** `bundles/main/` unless the user named another bundle. All
paths below are bundle-root relative — the bundle *is* the Obsidian vault root.

## Procedure

1. **Read `<bundle>/index.md` first.** It is the catalog of everything the wiki
   knows. Do not grep the tree before reading it.
2. **Read the relevant pages**, following links outward from the index hits.
3. **Synthesize an answer** with inline `[1]`-style citations resolving to each
   page's `# Citations` section. Say plainly when the wiki does not know
   something — do not fill gaps from general knowledge without labelling them as
   outside the wiki.
4. **Offer to file** the answer if it has lasting value:
   - `type: query` — a focused direct answer.
   - `type: synthesis` — multi-source analysis, comparison, or thesis.
   Filed queries may live in whichever directory fits best; the `type` field,
   not the directory, is what classifies the page (`SPEC.md` §4.5).
5. **If filed:** cross-link to every page cited, update **both** the root and
   directory `index.md`, and append a `**Query**` entry to `log.md`.

Answer the question first. Filing is optional and only happens if the user
agrees.

## Traps

- **Two indexes, not one.** Root `index.md` plus the per-directory
  `index.md` (`sources/`, `entities/`, `concepts/`, `synthesis/`). All must be
  updated.
- **Filenames are Title Case with spaces** — `Style guide.md`, `Id est.md`,
  not kebab-case, despite `AGENT.md` § Naming.
- **Link text inside concept pages is the path**:
  `[/concepts/Id est](/concepts/Id est.md)`. Index files use display names.
- **Do not assume the wiki's size.** Read `<bundle>/index.md` to learn what it
  actually holds before claiming it does or does not cover something. Say
  plainly when the wiki has no page for a question rather than inventing
  support.
- Bump `timestamp` on every page edited. Preserve existing frontmatter keys.
- Wrap body prose at ~80 columns; tables and citation URLs run long.
- `log.md`: `## YYYY-MM-DD`, newest-first, bold action word (`**Query**`).
- `index.md` and `log.md` are reserved filenames — never use them for a filed
  page.

## Scripts

Use `.opencode/skills/wiki-page/scripts/wiki-helpers.sh` for deterministic
tasks (full path — the `skill` tool does not change the working directory):

```bash
bash .opencode/skills/wiki-page/scripts/wiki-helpers.sh bump <file>       # Bump timestamp
bash .opencode/skills/wiki-page/scripts/wiki-helpers.sh log <bundle> <action> <message>
bash .opencode/skills/wiki-page/scripts/wiki-helpers.sh citations <file>  # Check an answer's [n] markers
```

## Do not

- Edit `raw/`, `.obsidian/`, or an existing page's `type` value.
- Modify `AGENT.md`, `SPEC.md`, or `CLAUDE.md` without asking.