# wiki-lint — usage and learnings

Written by `auto-skill` from mined session data. Sessions are named by id so an
entry traces back to its evidence. Newest first.

## Usage

| Metric | Value |
|---|---|
| Loads recorded | 0 |
| Sessions | — |
| Last used | never |

Never loaded, though its subject matter came up. Two readings are possible and
the evidence does not choose between them: the description does not fire on the
phrasings actually used, or the work was done under `wiki-page` because that is
where the scripts live. Worth resolving before assuming the skill is redundant.

## Learnings

### 2026-10-04 — a lint pass inherited four false findings before the cause was known

- **Signal:** a link sweep reported 5 `BROKEN` lines in two pages; four were
  real and one was a helper artefact. For three runs the working assumption was
  that all five were false positives, which was wrong.
- **Why:** the report mixed two causes — a whitespace bug in the helper, and
  link targets genuinely split by the 80-column wrap — and the cheaper
  explanation ("the tool is wrong") was reached first and repeated.
- **Fix:** `wiki-helpers.sh` v2.0 fixed the helper, which left the real defects
  visible. The lesson for this skill: a finding that survives a re-run with a
  changed tool is a finding about the repository, and `history/wiki-page.md`
  records the wrapper bug so it is not mistaken for content rot again.
- **Class:** unclear trigger
- **Recurrence:** 3× in `ses_ef8c2adb5ffeesKjR0Gu1yLPxH`

### 2026-10-04 — three of the six checks are deterministic and none are scripted

- **Signal:** the skill's checks are numbered 1–6, and orphans, redlinks and
  conformance are all decidable from the filesystem. The session implemented
  conformance and link checks ad hoc instead of following the skill.
- **Why:** the six checks are presented as one list with no indication of which
  need judgement, so all six read as model work.
- **Fix:** proposed — split the list into deterministic and judgement halves,
  and port the link-graph statistics (`graph_analyzer.py` in
  `alirezarezvani/claude-skills`) so orphans and hubs are measured rather than
  asserted.
- **Class:** missing step
- **Recurrence:** 1× in `ses_ef8c2adb5ffeesKjR0Gu1yLPxH`

### 2026-10-05 — the same regex trap, in a skill whose whole job is checking links

- **Signal:** 5 of 17 failed `grep` calls in `ses_ef5520920ffeNFV6a4wubuNSmX`
  were link-form patterns. `rg: regex parse error … look-ahead and look-behind
  is not supported`, and three `unclosed group` failures from escaped
  parentheses inside an alternation.
- **Why:** `wiki-lint` owns link checking, and its own script
  (`wiki-helpers.sh links`) already does the work the patterns were reaching
  for. The step is documented; it was skipped in favour of a regex that cannot
  express the check.
- **Fix:** trap added to `wiki-lint`'s Traps, naming the script as the answer.
  This skill also carried a `Style guide.md` link-shape example for a page
  deleted on 2026-10-03; replaced with a live one.
- **Class:** missing trap
- **Recurrence:** 5× in `ses_ef5520920ffeNFV6a4wubuNSmX`

### 2026-10-05 — a subagent was given this skill's judgement and got it wrong

- **Signal:** `wiki-link-checker`, run against `bundles/tech`, reported
  "5 broken, 0 orphaned, 0 casing mismatches". Verified by hand: **zero** broken
  links in scope. The three unresolvable targets it reacted to were all
  placeholders in `templates/log-entry.md`, and it reported 579 link
  *occurrences* as though each were a finding.
- **Why:** link-graph work is deterministic — resolve each target, count
  failures — but a subagent was handed it as judgement. It had no denominator
  to check itself against, so a confident wrong number looked identical to a
  right one. This is the same lesson as the `wiki-graph` rejection already in
  `skill-memory.md`, arriving as an instance of it.
- **Fix:** the subagent's prompt now requires unique targets rather than
  occurrences, excludes `templates/`, and must state its denominators; it also
  reports "clean" explicitly. `wiki-lint`'s SKILL.md gained a "Skill or
  subagent?" section saying which to prefer and warning that a subagent adds a
  fresh context, not accuracy.
- **Class:** wrong depth
- **Recurrence:** 1× in `ses_ef539a3c3ffeRuFkzh`

### 2026-10-05 — the skill did not know two subagents covering its ground existed

- **Signal:** `wiki-lint` and `wiki-page` contained zero mentions of
  `wiki-auditor` or `wiki-link-checker`, added earlier the same day. A skill
  cannot route to an alternative it does not know is there.
- **Why:** the subagents were committed as `.opencode/agents/*.md`, which the
  wiki skills do not reference and are not pointed at. Nothing fails — the
  overlap is invisible until both are used and disagree.
- **Fix:** `wiki-lint` gained a table naming both, when to prefer each, and the
  over-counting caveat. Escalation per the procedure's table: two things fighting
  for one trigger is resolved by sharpening a description to name the other, not
  by merging a skill and a subagent that serve genuinely different needs.
- **Class:** missing step
- **Recurrence:** once in `ses_ef5520920ffeNFV6a4wubuNSmX`
