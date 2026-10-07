---
name: wiki-lint
description: Use when the user asks to lint, health-check, audit, or find problems in the OKF wiki — triggers include "lint the wiki", "health check", "find orphan pages", "check for broken links or redlinks", "are there contradictions", "what needs fixing". Read-only by default; reports findings and applies only the fixes the user approves.
---

# Lint the OKF wiki

Operates the wiki described by `AGENT.md` at the repo root. Read `AGENT.md`
§ "Lint the wiki" before starting.

**Active bundle:** `bundles/main/` unless the user named another bundle. All
paths below are bundle-root relative.

## Skill or subagent?

This skill runs in the current context. Two subagents cover overlapping ground
and are the better choice when the point is a **fresh context** or **several
bundles at once**:

| Use | When |
|---|---|
| **this skill** | the user is asking about the wiki and you will act on the answer, or the checks need your judgement |
| `wiki-auditor` subagent | a bundle-wide conformance sweep you only need the findings from |
| `wiki-link-checker` subagent | verifying the link graph across a whole bundle |

Both are read-only and both are in the allowlist in
`.opencode/opencode.jsonc`, so `build` and `plan` may launch them. A subagent
returns its conclusion; it does not carry your reasoning into the next step, so
prefer the skill when the findings will drive edits.

One caveat earned the hard way: give a link-graph judgement to
`wiki-link-checker` and it will over-count. It reported "5 broken" on
`bundles/tech` where the true in-scope count is **zero** — it had counted
template placeholders as broken links and reported 579 link *occurrences* as
though each were a finding. The deterministic count is
`wiki-helpers.sh links <bundle>`; a subagent adds a fresh context, it does not
add accuracy.

## Checks

Run all six, then report as a single structured list grouped by category. Fix
nothing until the user approves.

1. **Contradictions** — claims on different pages that cannot both be true.
   Present each with its page references.
2. **Orphans** — pages with zero inbound links from other wiki pages.
   **Index entries do not count** (`SPEC.md` §9.3). A page linked only from
   `index.md` is still an orphan.
3. **Missing cross-references** — mentions in prose of an entity or concept
   that has its own page but is not linked on first mention in a section.
4. **Redlinks** — concepts referenced across multiple pages that deserve their
   own page but do not have one yet. Redlinks are tolerated by design: they mark
   not-yet-written knowledge. Surface, don't auto-create.
5. **Staleness** — pages whose `timestamp` predates a newer source covering the
   same topic.
6. **Conformance** — every non-reserved `.md` outside `raw/`, `templates/`,
   `.obsidian/` needs parseable frontmatter with non-empty `type` and `title`;
   `type: source-summary` needs non-empty `source:`; every cross-link must be
   bundle-root absolute.

On approval for each fix: apply it, bump the touched pages' `timestamp`, update
both indexes, and append a `**Lint**` entry to `log.md`.

## Known findings — do not re-report as new

- **`bundles/main/example.md`** is a stray artifact from testing Obsidian
  template insertion: empty `type:`, unindexed, absent from `log.md`. It
  violates conformance. Offer to delete it; don't delete silently.
- **Docs-vs-reality drift** is real and intentional-to-keep: `AGENT.md` /
  `SPEC.md` prescribe `kebab-case.md` filenames but every committed page is
  Title Case with spaces. Also `source:` holds URLs in practice, not raw paths.
  These are documented in `AGENTS.md`; do not "fix" them during a lint pass.
  Report them once, as a doc-drift item, if asked for a full audit.

## Traps

- **Two indexes, not one** — root `index.md` plus `sources/index.md`,
  `entities/index.md`, `concepts/index.md`. Missing a directory index is a lint
  finding.
- `index.md` and `log.md` are reserved at every level and must never hold
  concept content.
- Link text inside concept pages is the path
  (`[/concepts/MicroVM isolation](/concepts/MicroVM isolation.md)`); index files
  use display names. Both are valid — don't flag the path-style as a defect.
- Broken links are tolerated by design (`AGENT.md` § Linking). Report them as
  redlinks, not errors.
- `log.md`: `## YYYY-MM-DD`, newest-first, bold action word (`**Lint**`).
- Wrap prose at ~80 columns when applying fixes; tables and citation URLs run
  long by design.
- **Do not find links with a regex.** `grep` uses ripgrep's engine, which has no
  look-around — `(?!`, `(?=`, `(?<=`, `(?<!` fail with `look-around … is not
  supported` — and escaped `\(` / `\)` inside an alternation failed with
  `unclosed group` too. Five of seventeen failed calls in one session were
  attempts to enumerate link targets by pattern. Run
  `wiki-helpers.sh links <file>` instead; it is the whole reason it exists.
- Link examples in this file and in `wiki-page` used to cite deleted pages
  (`Exempli gratia.md`, `Style guide.md`). Deprecated 2026-10-03; live examples
  are in `bundles/tech/`.

## Scripts

Use `.opencode/skills/wiki-page/scripts/wiki-helpers.sh` for deterministic
checks (full path — the `skill` tool does not change the working directory):

```bash
bash .opencode/skills/wiki-page/scripts/wiki-helpers.sh validate <file>   # Non-empty type + title
bash .opencode/skills/wiki-page/scripts/wiki-helpers.sh links <file>      # Links resolve
bash .opencode/skills/wiki-page/scripts/wiki-helpers.sh citations <file>  # [n] markers consistent
bash .opencode/skills/wiki-page/scripts/wiki-helpers.sh wrap <file>       # Prose width, stray glyphs
```

Checks 2, 4 and 6 below are decidable from the filesystem and these verbs cover
them; 1, 3 and 5 need judgement. Run the verbs across the bundle first, then read.

## Do not

- Edit `raw/`, `.obsidian/`, or an existing page's `type` value.
- Restructure directories, change the type taxonomy, or delete pages without
  asking — those are on `AGENT.md`'s "ask first" list.
- Modify `AGENT.md`, `SPEC.md`, or `CLAUDE.md` without asking.