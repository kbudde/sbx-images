---
name: wiki-ingest
description: Use when the user asks to ingest, process, summarize, or file a source document into the OKF wiki. Triggers include "ingest this", "process raw/", "add this article to the wiki", "I dropped a PDF in raw/", "summarize this source into the wiki". Requires a file already present in the active bundle's raw/ directory.
---

# Ingest a source into the OKF wiki

Operates the wiki described by `AGENT.md` at the repo root. Read `AGENT.md`
§ "Ingest a source" before starting; this skill is the operational checklist
and the traps, not a replacement.

**Active bundle:** `bundles/main/` unless the user named another bundle. All
paths below are bundle-root relative — the bundle *is* the Obsidian vault root.

## Preconditions

- A source file must already exist in `<bundle>/raw/`. Never write into `raw/`
  yourself — it is immutable source material. If the user gives a URL instead,
  ask them to clip it in (Obsidian Web Clipper) before continuing.
- Read `AGENT.md` § Boundaries first. Ingesting a source the user did not name
  requires asking.

## Procedure

1. **Read** the raw source in full.
2. **Discuss takeaways with the user before writing.** Ask what to emphasize.
   This is a required checkpoint in `AGENT.md`, not an optional courtesy.
3. **Create** `<bundle>/sources/<Title Case Name>.md` with
   `type: source-summary`, and a `source:` field pointing at the raw material.
   Sections: `# Overview`, `# Key Claims` (numbered, `[1]`-cited), `# Style`/
   domain section as the source warrants, `# Relationships`, `# Citations`.
4. **Update or create entity pages** in `entities/` for named things discussed.
5. **Update or create concept pages** in `concepts/` for ideas, theories,
   frameworks, methods.
6. **Cross-link** bidirectionally: new source page → affected pages, and each
   affected page → back to the source.
7. **Update BOTH indexes** by calling the `index` verb once per index file,
   with the page's frontmatter `description` as `<desc>` **verbatim**:

   ```bash
   bash .opencode/skills/wiki-page/scripts/wiki-helpers.sh index <bundle> <dir> <name> <desc>
   ```

   The verb inserts into the correct root section, emits `%20`, and refuses an
   empty description. Hand-writing the bullet is what produces entries that
   paraphrase the description and then fail a later link check.
8. **Append** an entry to `<bundle>/log.md`:

   ```bash
   bash .opencode/skills/wiki-page/scripts/wiki-helpers.sh log <bundle> <action> <message>
   ```

Expect to touch 10–15 pages. Filing a single summary page without integrating it
is a failed ingest.

## Traps

- **Filenames are Title Case with spaces** in `bundles/main/` —
  `MicroVM isolation.md`, `Proxy-managed credentials.md` — *not* the
  `kebab-case.md` that `AGENT.md` § Naming prescribes. The committed pages won.
  Every absolute link already points at those exact filenames, so introducing a
  kebab-case page strands the graph. Match the existing pages in the bundle you
  are writing to. (The placeholder pages this trap used to cite —
  `Exempli gratia.md`, `Style guide.md`, `Id est.md`, `Wikipedia.md` — were
  deprecated on 2026-10-03; the live names above replaced them.)
- **Two indexes, not one.** `AGENT.md` mentions only the root `index.md`, but
  `sources/index.md`, `entities/index.md`, and `concepts/index.md` are all
  populated and must be updated too. Entry text is the page's frontmatter
  `description`, **verbatim** — see step 7 and the `index` verb.
- **`source:` in existing pages holds a full URL**, not a raw-file path
  (`sources/OpenClaw.md` has `source: https://openclaw.ai/`), even though
  `SPEC.md` §5.1 specifies a path. Follow the bundle's precedent. A
  `source-summary` for a local note with no URL of its own keeps a `raw/` path.
- **Quote frontmatter values containing spaces**: `title: "MicroVM isolation"`.
- **Link text inside concept pages is the path itself**:
  `[/concepts/MicroVM isolation](/concepts/MicroVM%20isolation.md)`. Index files
  use display names. Match whichever file you are editing.
- **`index.md` and `log.md` are reserved at every level** (`SPEC.md` §4.2) —
  never use them as concept filenames.
- Bump `timestamp` (ISO 8601, `Z`) on **every** page you touch, including
  pages you only added a backlink to. Preserve all existing frontmatter keys.
- Wrap body prose at ~80 columns. Tables and citation URLs run long; that's
  intentional.
- `log.md`: `## YYYY-MM-DD` heading, entries newest-first, bold action word
  (`**Ingest**`), and list the pages touched.

## Scripts

Use `.opencode/skills/wiki-page/scripts/wiki-helpers.sh` for deterministic
tasks (full path — the `skill` tool does not change the working directory):

```bash
bash .opencode/skills/wiki-page/scripts/wiki-helpers.sh bump <file>       # Bump timestamp
bash .opencode/skills/wiki-page/scripts/wiki-helpers.sh index <bundle> <dir> <name> <desc>
bash .opencode/skills/wiki-page/scripts/wiki-helpers.sh log <bundle> <action> <message>
bash .opencode/skills/wiki-page/scripts/wiki-helpers.sh citations <file>  # Check [n] markers
```

An ingest adds several pages at once, so `bump` takes every file in one call
rather than one call per page.

## Do not

- Modify anything in `raw/`.
- Edit `.obsidian/` config files.
- Remove or change a `type` value on an existing page.
- Use relative (`./`) links for cross-page references.
- Touch `AGENT.md`, `SPEC.md`, or `CLAUDE.md` without asking.