---
name: auto-skill
description: Use when the user asks to improve the agent's own skills from evidence — triggers include "audit the skills", "why did that skill misfire", "which skills are never used", "mine the session", "improve the skills", "review skill performance". Reads recorded opencode sessions, counts skill usage, surfaces failures and repeated work, writes per-skill history, and proposes fixes, scripts, and new skills. For authoring or validating a single skill use skill-creator; for a wiki operation use the wiki-* skills.
---

# Improve the skills from what actually happened

A skill is a hypothesis about how a task should be done. This skill tests it
against recorded sessions: what was loaded, what failed, what was retried,
what the user corrected, and what a human had to do by hand. The output is
evidence-backed changes to `SKILL.md`, new scripts, and — when the evidence
points at work no skill owns — a new skill.

Two things this skill does not do: it does not invent improvements from reading
the skill in isolation, and it does not guess at usage. Both come from the
session database.

**Evidence lives in `~/.local/share/opencode/opencode.db`** (SQLite; newer
versions also expose JSON session files — the miner reads the database and says
which schema it found).

## Procedure

### 1. Mine

Never parse the database by hand. Run the miner, by its full repo-root-relative
path:

```bash
# everything, as one Markdown report
python3 .opencode/skills/auto-skill/scripts/mine-sessions.py report

# or one section at a time
python3 .opencode/skills/auto-skill/scripts/mine-sessions.py counter
python3 .opencode/skills/auto-skill/scripts/mine-sessions.py errors
python3 .opencode/skills/auto-skill/scripts/mine-sessions.py retries
python3 .opencode/skills/auto-skill/scripts/mine-sessions.py latency
python3 .opencode/skills/auto-skill/scripts/mine-sessions.py corrections
python3 .opencode/skills/auto-skill/scripts/mine-sessions.py hotspots
```

Useful flags: `--unmined` (sessions not yet recorded in `history/`),
`--since 2026-10-01`, `--session ses_…`, `--limit 0` for no cap, `--json`.

The companion inventory, which counts skills and finds trigger overlap:

```bash
bash .opencode/skills/auto-skill/scripts/audit-skills.sh .opencode/skills
```

### 2. Triage

Sort every signal into one of two piles before acting.

**Deterministic** — trust the count: failed calls by tool and message, repeated
calls, tool latency, skill usage, edit hotspots, missing frontmatter, broken
links, unresolved citations.

**Judgement** — read before believing: correction candidates (marker-matched
user messages; "no" opens a follow-up as often as it reopens a decision), a
skill with a high load count and no history, a slow tool that was slow once.

Then discard what is not about a skill:

- A 403 from `webfetch` is the provider or the site, not a skill defect.
- A failing tool the agent called directly, with no skill loaded, is an
  execution note — record it, and only escalate it if it recurs.
- A repeated call is a *candidate* for a script. Three reads of one file in one
  session is usually the agent verifying an edit; eight near-identical shell
  commands is a loop that a script should own.

### 3. Record the learning

History is central, one file per skill, under
`.opencode/skills/auto-skill/history/`. Create a file only when there is
something to record; no empty files. Newest entry first.

```
# <skill> — usage and learnings

Written by `auto-skill` from mined session data. Sessions are named by id so an
entry can be traced back to the evidence.

## Usage

| Metric | Value |
|---|---|
| Loads recorded | <n> |
| Sessions | <ids> |
| Last used | <ISO> |

## Learnings

### <YYYY-MM-DD> — <one line: what went wrong>
- **Signal:** <the count, session id, and command that shows it>
- **Why:** <the mechanism, not the symptom>
- **Fix:** <what changed, in which file>
- **Class:** script bug | unclear trigger | missing step | missing trap |
  wrong depth | stale claim
- **Recurrence:** <n>× in <session id> | <n>× across <k> sessions | once
```

`Class` and `Recurrence` are what make the escalation rule auditable six months
from now. Fill them in; an entry without them cannot be triaged later.

Also refresh the `## Usage` table from the counter in the same pass.

### 4. Propose quick fixes

High impact, low effort, applied only after the user approves. These are the
findings a single session already proves:

- A script bug that produced wrong output — fix it and say what was wrong.
- A trap that was missing from a skill whose failure mode just occurred — add it
  phrased as *why* it went wrong.
- A stale claim in a skill — a path that moved, a script verb that no longer
  exists, a documented behaviour the tool does not have.

Report each as: signal, one-line change, effort, impact. Then stop and wait.

### 5. Propose scripts

For a loop the miner counted, propose a script and state the arithmetic:

> `links` ran 3× over 21 files in one session, after which 5 findings turned out
> to be false. `wiki-helpers.sh sweep` would make it one call.

Name the verb, the inputs, the output, and the skill that should own it. A
script that could live in two skills belongs to the one that owns the
convention, not to whichever was loaded.

### 6. Escalate when it repeats

**A signal seen twice in one session, or in two sessions, is no longer a quick
fix.** Propose a bigger change instead:

| Recurrence | Escalate to |
|---|---|
| same trap, repeated | an explicit step in the procedure, not just a trap line |
| same ad-hoc loop, repeated | a script (step 5) |
| same wrong turn, repeated | a rewritten *ordering* of the steps |
| body over ~500 lines, or depth crowding the procedure | move depth to `references/` |
| two skills fighting for one trigger | merge, or sharpen one description to name the other |
| work no skill owns, twice | a new skill (step 7) |

State the recurrence count in the proposal. "I noticed" is not a reason; "three
times across two sessions" is.

### 7. Propose new skills

Append to `.opencode/skills/auto-skill/references/skill-memory.md`. **Check that
file first** — an idea already recorded there is either already adopted or
already rejected, and re-proposing it is the churn this file exists to prevent.

| Skill | Trigger | Problem it solves | Evidence | Status |
|---|---|---|---|---|
| `handoff` | "compress session", "continue later" | a 250-call session does not survive context loss | `ses_…` 4.0M input tokens | proposed |

Never delete a row. A rejected idea records *why*, which is what stops the same
proposal returning every run.

### 8. Verify, then commit

```bash
bash .opencode/skills/skill-creator/scripts/validate-skill.sh .opencode/skills/<name>
```

For a script change, run it against known-bad input first and confirm it
reports what it should. Then commit, one logical change per commit, following
`AGENTS.md`. Tell the user to restart opencode afterwards — skills load at
startup.

## Traps

- **The database holds credentials.** `account` and `credential` contain access
  and refresh tokens. The miner allowlists the six tables it reads — `session`,
  `session_v2`, `message`, `part`, `session_message`, `session_input` — and opens
  read-only; never extend a query to another table, and never copy the database
  into this repository. Tests must not open the real database at all:
  `scripts/test/test-mine-sessions.py` builds its own fixtures.
- **A load is not a use.** The counter says a skill was loaded. A skill with a
  high count and no history entries is a description promising more than the
  skill delivers — that is a finding about the description.
- **Do not put session learnings in the wiki.** The wiki is a knowledge base;
  execution history belongs in the skill files and in git. File a page only when
  a finding is a durable engineering fact worth reading later.
- **History is central, not per-skill.** The files live in
  `auto-skill/history/`, so a skill only learns from them when something points
  it there. Keep that pointer line in the skill.
- **Do not rewrite history entries.** They are an audit trail; add a new entry
  that supersedes an old one instead.
- **Reference scripts by full repo-root path.** The `skill` tool does not change
  the working directory, so a bare `scripts/x.sh` resolves against the repo root
  and fails.
- **Do not propose an improvement without its evidence.** Every proposal cites a
  count or a session id. A preference is not a finding.
- **Run the script before blaming the agent.** A loop that keeps recurring may be
  a tool that quietly declines. Before recording "agents keep ignoring the
  scripts", invoke the script the way the caller invoked it. A verb that reports
  success without checking anything invites exactly the improvisation it exists to
  prevent — and that improvisation then gets misfiled as disobedience, so the
  real defect stays buried. `wiki-helpers.sh links <bundle>` printed "OK" while
  checking nothing, and the 22 greps it provoked were recorded as a discipline
  problem rather than a script bug.
- **Write fixtures by reading a real row.** A fixture built from the shape you
  expect will pass in agreement with the bug it was meant to catch. The v2
  fixture put `type` inside the JSON while the database keeps it in a column, so
  28 assertions passed while user text was being dropped.
- **Validate after every change**, and expect to restart opencode.

## Do not

- Change a skill without showing the evidence and getting approval
- Install a skill from an unknown author without reading its `SKILL.md` **and**
  every bundled script
- Create a skill that duplicates an existing one's trigger
- Copy session data, prompts, or tool output into a wiki page
- Mine the database by hand when the script exists
