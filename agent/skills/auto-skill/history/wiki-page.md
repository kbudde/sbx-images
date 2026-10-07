# wiki-page — usage and learnings

Written by `auto-skill` from mined session data. Sessions are named by id so an
entry traces back to its evidence. Newest first.

## Usage

| Metric | Value |
|---|---|
| Loads recorded | 2 |
| Sessions | `ses_ef8c2adb5ffeesKjR0Gu1yLPxH`, voice-research session 2026-10-05 |
| Last used | 2026-10-05T11:00:14Z |
| Tool calls after load (heuristic) | 25 |

The attribution figure is a heuristic: the session store records no skill scope,
so it credits every call after the load to the most recently loaded skill. Read
it as an upper bound.

## Learnings

### 2026-10-05 — the verbatim rule was stated but never wired to the verb

- **Signal:** five new pages produced **10 paraphrased index entries** (5 pages
  times root `index.md` plus the directory `index.md`). The link-check subagent
  reported "Index-entry accuracy (VERBATIM vs frontmatter `description`) —
  **FAIL**, all five fail in all three index files". `index.md` is an edit
  hotspot at 4x, `concepts/index.md` and `synthesis/index.md` at 2x each.
- **Why:** step 6 said "Entry text is the page's frontmatter `description`,
  verbatim" — a rule, not an instruction to call anything. The `index` verb
  already emits `%20`, inserts into the correct root section, and **hard-refuses
  an empty description** with "ERROR: description is required — the index entry
  is the page's frontmatter description verbatim". That guard is exactly the
  check that failed and it was never invoked, so nothing stopped the paraphrase
  until a subagent read both files and compared strings.
- **Fix:** steps 6 and 7 now name the verb with the exact invocation and say
  why — a link check catches five paraphrased entries at once and fixing them
  costs more than calling the verb would have. `wiki-ingest/SKILL.md` steps 7
  and 8 got the same treatment; the audit's script-candidate heuristic had been
  printing both steps as mechanical work with no script named.
- **Class:** missing step
- **Recurrence:** 10 instances in one session; the same bypass was recorded 2x
  in `ses_ef8c2adb…`, when the reason was that the verb could not yet insert
  into a root section. The verb was fixed; the step was not.

### 2026-10-05 — a fix recorded against a skill never reached the subagent

- **Signal:** the ripgrep look-around trap below was added to this skill's "Do
  not" list on 2026-10-05 after 5 failures in `ses_ef552092…`. The same day then
  produced **7 more invalid-regex failures, 4 cancelled greps, and 2 calls to a
  tool named `bash`** — from the `wiki-link-checker` subagent.
- **Why:** a subagent loads its own definition from `.opencode/agents/`, not the
  parent skill. `wiki-link-checker.md` contained **zero** references to
  `wiki-helpers.sh`, and it *denied all shell access* — so it could not run the
  script even had it known about it. It kept trying, was refused, and fell back
  to hand-rolled greps. A trap written into a `SKILL.md` is therefore not a fix
  for an agent doing the same job.
- **Fix:** both subagents now carry a "Run the script; do not reimplement its
  checks" section with the exact invocations, the `shell`-not-`bash` tool name,
  and the look-ahead limitation. `wiki-link-checker` and `wiki-auditor` re-allow
  `shell` for five read-only verbs only (`links`, `validate`, `citations`,
  `wrap`, `refs`); the writing verbs stay denied, so read-only still holds.
  `audit-skills.sh` grew a **Subagent Convention Coverage** section that reports
  the combination mechanically, so the next instance is visible without a human
  noticing.
- **Class:** missing step
- **Recurrence:** 5x in `ses_ef552092…`, then 7x in the same class on
  2026-10-05 — the trap existed but reached only one of two consumers.

### 2026-10-04 — `check_links` reported links that resolve

- **Signal:** `links` ran 3× over every page in the repository. Each run
  returned the same 5 `BROKEN` lines. Investigating cost ~4 tool calls and the
  conclusion contradicted the first reading.
- **Why:** `while read -r link` splits on whitespace, so a target containing a
  literal space arrived truncated — `/concepts/Clean` for
  `/concepts/Clean architecture.md`. Every page in this wiki links to a Title
  Case filename, so the majority of links were misread. `IFS= read -r link` is
  the fix.
- **Fix:** `wiki-helpers.sh` rewritten to v2.0; `check_links` uses
  `IFS= read -r link` and treats `log.md` at a bundle root like `index.md`.
- **Class:** script bug
- **Recurrence:** 3× in `ses_ef8c2adb5ffeesKjR0Gu1yLPxH`

### 2026-10-04 — `validate` passed an empty `type:` and flagged exempt files

- **Signal:** `validate bundles/main/example.md` reports OK on the one page the
  lint skill knows violates conformance; `validate index.md` reports ERROR on
  files `AGENT.md` exempts.
- **Why:** `grep -q "^type:"` matches the key whether or not a value follows,
  while `SPEC.md` §11 requires a non-empty `type`. The reserved filenames were
  never excluded, so the validator contradicted the specification it enforces.
- **Fix:** `grep -qE '^type:[[:space:]]*[^[:space:]]'`, plus a basename
  exemption for `index.md` and `log.md`.
- **Class:** script bug
- **Recurrence:** 2× in `ses_ef8c2adb5ffeesKjR0Gu1yLPxH`

### 2026-10-04 — index entries had to be written by hand, twice

- **Signal:** `update_index` was bypassed for the root index on two consecutive
  changes, each time with a hand-written Python edit, because the verb appends
  to the end of a file and the root index is sectioned.
- **Why:** the verb had no notion of the root index's `## Sources` / `## Entities`
  / `## Concepts` / `## Synthesis` sections, and emitted unencoded spaces where
  every committed entry uses `%20`.
- **Fix:** `index` now inserts into the matching root section after the last
  non-blank line, emits `%20`, and warns when the section is missing.
- **Class:** missing step (script gap, worked around by hand)
- **Recurrence:** 2× in `ses_ef8c2adb5ffeesKjR0Gu1yLPxH`

### 2026-10-04 — three checks were written as one-off shell and Python

- **Signal:** citation-marker consistency, prose wrapping, and a stale-path
  sweep after a directory move were each written inline, twice, in the same
  session — roughly 6 tool calls that produced no reusable artifact.
- **Why:** the skill documents three verbs (`bump`, `index`, `log`) and points
  at the helper for those; nothing covered verification, so verification
  stayed improvised.
- **Fix:** `citations`, `wrap`, and `refs` verbs added, plus multi-file `bump`.
- **Class:** missing step
- **Recurrence:** 6× in `ses_ef8c2adb5ffeesKjR0Gu1yLPxH`

### 2026-10-04 — the 80-column wrap breaks links, and the docs invite it

- **Signal:** 4 broken links in `bundles/tech/synthesis/Choosing an architecture
  in Go.md`, one malformed link in `concepts/Monolith first.md`. All pre-existing.
- **Why:** `AGENTS.md` says hard-wrap prose at ~80 columns, and every page links
  to a Title Case filename whose name contains a space. Wrapping inside a link
  target splits it across lines, and a markdown link target cannot span a line
  break — so following the wrap rule at the wrong place silently breaks the
  link. The second defect is a `]` where a `)` belongs.
- **Fix:** pending a decision. `wrap` now exempts link-list lines so it cannot
  encourage the break, and `links` is the detector.
- **Class:** missing trap
- **Recurrence:** present in the repository before this session; 5 instances

### 2026-10-05 — the trap was aimed at the symptom; the script was the cause

- **Signal:** the 22× grep loop over `bundles/tech` across five sessions — the
  largest near-repeat in the mine — was attributed to agents ignoring the
  scripts. The trap added earlier the same day ("use `wiki-helpers.sh links`")
  was already in place, and the loop predates it.
- **Why:** `wiki-helpers.sh links bundles/tech` did not work. It printed
  `grep: Is a directory`, swallowed the error through a `|| true`, read zero
  links, and reported `OK: All links resolve` with exit 0. Bundle-wide link
  checking is the common request; the verb accepted one file only; so the
  obvious response to a tool that quietly declines is to reimplement it.
- **Fix:** `links` now takes a directory and checks every page under it,
  excluding `raw/`, `templates/`, and `.obsidian/`, and reports how many pages
  it checked so "checked 53" cannot be confused with "checked 0". Six tests
  added, including the false-pass regression. Verified against `bundles/tech`,
  where it immediately surfaced four truncated link targets in
  `synthesis/Choosing an architecture in Go.md` — damage this repo has flagged
  as pre-existing since 2026-10-04 and that nothing could detect while the
  sweep silently passed.
- **Class:** script bug
- **Recurrence:** once in `ses_ef5520920ffeNFV6a4wubuNSmX`, latent until today

### 2026-10-05 — five failed calls reconstructing a check the script already does

- **Signal:** 5 of 17 failed `grep` calls in `ses_ef5520920ffeNFV6a4wubuNSmX`,
  all attempts to enumerate link targets by pattern.
  `rg: regex parse error: (?:\]\((?!/|\w+:|#)[^)]*\)) ^^^ error: look-around,
  including look-ahead and look-behind is not supported`, plus three
  `unclosed group` failures from escaped `\(` / `\)` inside an alternation.
- **Why:** ripgrep's engine has no look-around, and a link-form pattern needs
  exactly that. The failure reads as a malformed regex rather than an
  unsupported feature, so the response was to try a different pattern — which
  is why the same class recurred. `wiki-helpers.sh links` answers the question
  directly and was not used.
- **Fix:** trap added to the skill's "Do not" list with the engine limitation,
  the exact error text, and the instruction to reach for the script or
  `literal: true` rather than a narrower regex.
- **Class:** missing trap
- **Recurrence:** 5× in `ses_ef5520920ffeNFV6a4wubuNSmX`

### 2026-10-05 — the naming precedent pointed at four deleted pages

- **Signal:** the skill's "Filenames: follow precedent, not the docs" section
  cited `Exempli gratia.md`, `Id est.md`, `Style guide.md`, `Wikipedia.md`, and
  two link-shape examples cited `Style guide.md`. All were removed on
  2026-10-03 when the placeholder cluster was deprecated.
- **Why:** the section is the one place a reader goes to learn the convention,
  and every example in it was unopenable. The same drift was found in
  `AGENTS.md` in the same session; fixing only the repo root left the skills
  asserting the old names.
- **Fix:** examples replaced with live `bundles/tech/` pages, and the old names
  kept in place with the deprecation date so a reader who remembers them learns
  why they vanished.
- **Class:** stale claim
- **Recurrence:** present in the repository before this session
