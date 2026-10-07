# auto-skill — usage and learnings

Written by `auto-skill` from mined session data. Sessions are named by id so an
entry traces back to its evidence. Newest first.

## Usage

| Metric | Value |
|---|---|
| Loads recorded | 2 |
| Sessions | `ses_ef5520920ffeNFV6a4wubuNSmX` |
| Last used | 2026-10-05T07:25:27Z |

The load was an `@auto-skill` mention, not a `skill` tool call. Before
2026-10-05 the counter could not see it — see the last entry.

## Learnings

### 2026-10-05 — the miner read the whole v2 schema wrong, and failed silently

- **Signal:** `mine-sessions.py report` exited 0 on a healthy 18-session
  database reporting **0 tool calls and 0 errors** across every session.
  `audit-skills.sh` printed `(miner unavailable)` for the usage counter.
- **Why:** four independent v1→v2 renames, none of which raised. v2 dropped
  `message`, `part`, and `session_input` and renamed `session` to `session_v2`;
  tool calls moved from a `parts` array to `content`, from key `tool` to `name`,
  timing out of `state` into a top-level `time`, and `state.error` became an
  object. Every lookup found nothing, and finding nothing is not an error. A
  second defect compounded it: `open_db`'s fallback probed for the session table
  inside a `try`, then fell through to a path running *the same probe* with no
  `try`, so the branch meant to handle this failure raised on it.
- **Fix:** `session_table()` resolves `session_v2` or `session` and reports the
  tables it found instead of raising `no such table`; `load_new` reads the v2
  shapes; queued prompts read from whichever of `session_input`,
  `session_inbox`, `session_pending` exists. Covered by
  `scripts/test/test-mine-sessions.py`, whose central assertion is that the
  counters are **non-zero** — a clean exit with empty counters is
  indistinguishable from a healthy report.
- **Class:** script bug
- **Recurrence:** once in `ses_ef5520920ffeNFV6a4wubuNSmX`, latent since the v2
  upgrade

### 2026-10-05 — the role lives in the SQL column, so user text was never read

- **Signal:** the counter showed only `opencode` while the database held a user
  message invoking `@auto-skill`. Corrections and user text buckets were empty
  across 18 sessions.
- **Why:** v2 keeps a message's role in `session_message.type`, a **column** — a
  user message's JSON payload has keys `time`/`text`/`files`/`agents`/`skills`
  and no `type` at all. The miner read the role from the JSON, so every message
  resolved to `"?"` and the user branches never ran.
- **Fix:** select and use the `type` column. Two assertions added: an
  `@mention` load is counted, and marker-matched user text reaches the
  corrections bucket. The second needed a marker in the fixture deliberately —
  without one the assertion passes vacuously.
- **Class:** script bug
- **Recurrence:** once in `ses_ef5520920ffeNFV6a4wubuNSmX`

### 2026-10-05 — a fixture encoded the assumption instead of the artifact

- **Signal:** the v2 fixture written on 2026-10-05 to test the miner put
  `"type": "user"` and `"type": "assistant"` **inside the JSON**, and all 28
  assertions passed — while the role-column bug above was live.
- **Why:** the fixture was built from how the schema was assumed to look rather
  than from a row read out of the database. It passed because it agreed with the
  bug.
- **Fix:** the fixture was rebuilt by reading an actual `session_message` row:
  role in the column, user payload keys `time`/`text`/`files`/`agents`/`skills`.
  This is the same lesson the skill already records for web sources — verify
  against the artifact, not the prose — applied to a fixture.
- **Class:** wrong depth
- **Recurrence:** once in `ses_ef5520920ffeNFV6a4wubuNSmX`

### 2026-10-05 — the skill could not see its own most common invocation

- **Signal:** one user message carried `skills: [auto-skill]`; the counter
  reported only `opencode`.
- **Why:** a skill invoked by `@mention` never becomes a `skill` tool call, and
  the counter only read tool calls. The primary way users reach this skill was
  invisible to the thing that measures its use.
- **Fix:** `load_new` collects `skills` from user messages and the counter adds
  them as loads, with a `mentioned` count distinguishing the two paths.
- **Class:** missing step
- **Recurrence:** structural

### 2026-10-04 — the skill audited the skills instead of the sessions

- **Signal:** the original procedure read each `SKILL.md` and researched
  comparable skills online. Its one session-mining step was the last of seven,
  phrased as optional ("skip this step silently if the session was empty"), and
  the whole report was then written without a single count from a session.
- **Why:** the purpose was defined as "audit and improve skills" — a property of
  the skill files — so the evidence it gathered was also a property of the skill
  files. Everything it produced was arguable and nothing was measurable: eleven
  session observations had to be reconstructed by hand at the end, after the
  report was already written, and they were the most valuable part of it.
- **Fix:** purpose changed to read recorded sessions first and treat the skill
  files as the thing being explained. Mining is step 1 and mandatory; the
  comparable-skills research demoted to a reference file consulted only when the
  evidence says a skill's approach is the problem.
- **Class:** wrong purpose
- **Recurrence:** structural, present since the skill was written

### 2026-10-04 — no usage counter, so "which skills earn their place" was unanswerable

- **Signal:** 8 skills, no usage data. Whether `wiki-lint` was ever loaded, or
  whether two skills served one job, could not be established — questions the
  session database answers in one query.
- **Why:** the original procedure counted lines, scripts and reference files.
  Those describe what a skill *contains*; the counter describes what it is
  *for*.
- **Fix:** `mine-sessions.py counter` reads skill loads from the database, and
  `audit-skills.sh` prints the count in its inventory.
- **Class:** missing step
- **Recurrence:** structural

### 2026-10-04 — findings had nowhere durable to go

- **Signal:** eleven session observations were written into a chat report and a
  commit message body. The next run starts from zero and would re-derive them.
- **Why:** the skill had no artifact to write to, so the only durable record was
  prose in a message.
- **Fix:** `history/<skill>.md` per skill, with a fixed entry shape carrying
  `Class` and `Recurrence` so an entry can be triaged later; and
  `references/skill-memory.md` as the ledger of candidate new skills, where a
  rejected idea records its reason so it is not re-proposed.
- **Class:** missing step
- **Recurrence:** structural

### 2026-10-04 — the inventory script flagged all 8 skills as script candidates

- **Signal:** the heuristic matched any occurrence of `validate|check|scaffold`
  in a body, so all 8 skills were listed — including `go-architect`, which
  produces a design and has nothing to script.
- **Why:** a keyword search cannot tell "do this" from "this is the thing being
  discussed".
- **Fix:** the heuristic now matches an imperative numbered step and prints the
  step text so the finding can be judged; overlap reporting ignores words used by
  three or more descriptions and names the shared words.
- **Class:** script bug
- **Recurrence:** 1× in `ses_ef8c2adb5ffeesKjR0Gu1yLPxH`

### 2026-10-05 — the corrections signal was two-thirds subagent noise

- **Signal:** 12 user messages matched a correction marker; 8 were subagent task
  prompts ("Do not edit any files", "your only job is…"). 3 candidates remain
  after filtering, of which 1 is a real correction. `mine-sessions.py corrections`
  before the fix listed almost entirely agent-authored text.
- **Why:** a subagent session's user-role message is the parent agent's
  instruction. The marker heuristic cannot distinguish that from a person typing
  "don't stop" — both contain `do not`, `don't`, or `stop` — because instructions
  and corrections use the same English. Narrowing the marker list would not fix
  it: the words that fire most often are the ones ordinary prose needs.
- **Fix:** `session_v2.parent_id` identifies subagent sessions exactly, so the
  filter keys off a column rather than prompt text, which would break the moment
  the harness words its prefix differently. The report states how many matches
  were dropped and why, and each survivor is annotated with the marker that fired
  so a weak match is visible rather than silently credible.
- **Class:** script bug
- **Recurrence:** once in `ses_ef5520920ffeNFV6a4wubuNSmX`, but structural — the
  noise scales with subagent use, which is exactly what this repo just added

### 2026-10-05 — a positional fixture insert misaligned silently

- **Signal:** the v2 fixture gained a second session row and every assertion
  failed at once with `TypeError: unsupported operand type(s) for /: 'str' and
  'int'` inside `iso()`.
- **Why:** the new row was inserted positionally and sat one column off, so
  `time_created` received the string `'ses_a'`. Nothing warns about a positional
  insert; it simply starts writing values into the wrong columns until one lands
  somewhere type-checked.
- **Fix:** every fixture insert now names its columns.
- **Class:** script bug
- **Recurrence:** once in `ses_ef5520920ffeNFV6a4wubuNSmX`
