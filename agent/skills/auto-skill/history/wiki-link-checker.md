# wiki-link-checker — usage and learnings

Written by `auto-skill` from mined session data. Sessions are named by id so an
entry traces back to its evidence. Newest first.

A subagent, not a skill: it is defined in `.opencode/agents/wiki-link-checker.md`
and is loaded by `build` and `plan`. The `auto-skill` miner and
`audit-skills.sh` were extended to cover it on 2026-10-05 — see the entry below
for why that extension was needed.

## Usage

| Metric | Value |
|---|---|
| Launches recorded | 2 |
| Sessions | voice-research session 2026-10-05, nesting-probe session 2026-10-05 |
| Last used | 2026-10-05T11:05:00Z |
| Failed calls attributable | 13 |

Launches are counted from the session database by agent ID, not by skill load,
because a subagent load does not appear in the skill counter.

## Learnings

### 2026-10-05 — it denied all shell, so the script it should have run was unreachable

- **Signal:** 13 failed calls in one session — 7 × `Invalid regex pattern: rg:
  regex parse error … look-around … is not supported`, plus 3 × `unclosed group`
  from escaped `\(` / `\)` inside an alternation, 4 × `grep` cancelled, and 2 ×
  `No tool named "bash" is currently available`.
- **Why:** its `permissions` block denied `shell` on `*` with no re-allow, so
  `wiki-helpers.sh` could not be invoked at all. The agent tried anyway, was
  refused, and rebuilt the check by hand — with patterns needing exactly the
  look-around ripgrep lacks. The `bash` failures are the same blind spot: the
  tool is named `shell`, and the definition never said so.
- **Fix:** `shell` is re-allowed for five read-only verbs only — `links`,
  `validate`, `citations`, `wrap`, `refs` — as narrow patterns placed *after* the
  broad deny, because the last matching rule wins. `index`, `log`, and `bump`
  match no allow rule and stay denied, so the agent remains read-only. The
  definition now also names the script, the `shell`-not-`bash` tool name, and
  the look-ahead limitation verbatim.
- **Class:** wrong depth (the convention existed, at the wrong layer)
- **Recurrence:** the same failure class was recorded 5× against `wiki-page` in
  `ses_ef552092…` and fixed in that skill's "Do not" list. This agent then
  repeated it 7×, because a subagent does not load the parent skill.

### 2026-10-05 — it reports well, but it is expensive and has no history file

- **Signal:** the same run produced a correct verdict — links PASS, frontmatter
  PASS, orphans PASS — and the one real finding, which was 10 paraphrased index
  entries the parent agent had hand-written. It also reported two out-of-scope
  observations (a `query`-typed page in `concepts/`, relative links in `raw/`).
- **Why:** useful, but 13 failed calls to reach it, and nothing in this repo had
  ever recorded how it behaves. `references/skill-memory.md` already records one
  prior run where it reported "5 broken links" on `bundles/tech` where the true
  in-scope count was zero, having counted template placeholders as broken. That
  is a judgement failure in a counting task, which is the argument for
  `wiki-helpers.sh links` owning absolute-link resolution outright.
- **Fix:** none to the agent's remit. What the code now does is narrow it: the
  deterministic checks are delegated to the script, and the definition states
  explicitly that orphan detection, index round-trip, and reciprocity stay with
  the agent. `history/wiki-link-checker.md` exists so the next run has somewhere
  to be recorded.
- **Class:** missing step
- **Recurrence:** one false-reporting run previously, one expensive run now

### 2026-10-05 — `auto-skill` could not see this agent at all

- **Signal:** neither `mine-sessions.py` nor `audit-skills.sh` read
  `.opencode/agents/`. `history/` held five files, none for a subagent, so the
  trap-to-subagent propagation gap had no detector.
- **Why:** the gap and the failure share one cause — a subagent is a separate
  context with its own definition, so a convention owned by a skill does not
  reach it, and tooling scoped to skills cannot observe that it did not.
- **Fix:** `audit-skills.sh` takes an optional agents directory (default
  `.opencode/agents`) and prints a **Subagent Convention Coverage** table:
  per agent, whether it denies shell, whether that deny is re-allowed, whether it
  names the helper, and whether a history file exists. It was written and run
  against this repo in the same pass and immediately flagged `wiki-auditor` as
  the second instance of the same defect — which was then fixed.
- **Class:** missing step
- **Recurrence:** latent until 2026-10-05