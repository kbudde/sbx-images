# debug-research — usage and learnings

Written by `auto-skill` from mined session data. Sessions are named by id so an
entry traces back to its evidence. Newest first.

## Usage

| Metric | Value |
|---|---|
| Loads recorded | 1 |
| Sessions | `ses_ef29ef3e…` (2026-10-05/06) · `ses_ef77ed92…` (content delivered inline, not via the `skill` tool) |
| Last used | 2026-10-06T05:55:36Z |
| Tool calls after load (heuristic) | 219 in `ses_ef29ef3e…` |

`ses_ef29ef3e…` is the session that rewrote this skill: 219 tool calls, 10
failed calls, **718,778 input / 75,976 output tokens**, against **17 user turns**.
That ratio is the finding — see the first entry below.

The attribution figure is a heuristic: the session store records no skill scope,
so it credits every call after the load to the most recently loaded skill. Read
it as an upper bound. The 2026-10-04 session delivered the skill content inline
in the user turn, so its load was never recorded and must not be read as zero.

## Learnings

### 2026-10-06 — `sweep` was built; the two entries that proposed it are now applied

- **Signal:** `ses_ef29ef3e…` called
  `wiki-helpers.sh sweep bundles/tech` and got the usage banner. The 2026-10-04
  and 2026-10-06 entries below both recorded it as "proposed, not applied".
- **Why:** the same loop — `for f in ...; do validate; citations; links; done` —
  had been retyped in three sessions. It is deterministic, which is the test
  `auto-skill` uses to decide something belongs in a script.
- **Fix:** applied. `sweep <bundle|path> [--wrap]` in
  `.opencode/skills/wiki-page/scripts/wiki-helpers.sh`, with `quiet` modes added
  to `validate`, `citations` and `wrap` so it reports findings rather than forty
  OK lines. `wrap` is opt-in: 37 of 60 pages in `bundles/tech` carry
  pre-existing one-or-two-column overruns, so a default that included it would
  be permanently red and ignored — the same failure as a verb that never fails.
  Covered by nine assertions in `scripts/test/test-wiki-helpers.sh`, verified
  against a sabotaged copy that always reported success (four assertions fail).
  `debug-research` §6 and `wiki-page` §Scripts now name it.
- **Class:** missing script
- **Recurrence:** 3× across 3 sessions (`ses_ef77ed92…` 2026-10-04,
  `ses_ef8c2adb…`, `ses_ef29ef3e…` 2026-10-06) → now applied

### 2026-10-06 — the corrections miner missed the highest-value correction again; fixed and widened

- **Signal:** `mine-sessions.py corrections` over `ses_ef29ef3e…` returned six
  candidates, **all six pasted command output**, and missed
  *"btw. did you check open github issues?"* — the turn that redirected the whole
  diagnosis. Same shape as the 2026-10-04 entry below: `stop` matched inside a
  pasted `openclaw gateway stop` transcript, `no,` inside `No change`, `do not`
  inside a `health --json` dump.
- **Why:** two independent defects. (1) The detector matched correction markers
  anywhere in a user message, and in this skill the dominant user message *is*
  pasted terminal output, which contains those words as ordinary text. (2) There
  was no positive signal at all for a correction that answers the diagnosis
  without using a marker word.
- **Fix:** applied, with three filters that are each **counted and reported**
  rather than silently applied — pastes (prompt, TUI glyph, timestamped log
  line, or a ≥60%-indented/bracketed dump), turns that open a new task
  ("update the docs"), and bare progress nudges ("go on", "status?"). The last
  is reported as a *signal*, because a run of "status?" is the agent going
  quiet. Added the positive signal: a user turn following an assistant turn that
  asserts a cause, matched on a real per-session ordering (`ord`, assigned
  during load) because timestamps collide at millisecond resolution and the
  first attempt — comparing every turn against the *last* cause in the session —
  silently dropped early corrections.
  Result on the session that prompted it: 8 substantive turns instead of 6
  pastes, and the missed correction now appears.
- **Also fixed:** `filter_sessions` omitted `user_skills` and the new
  `assistant_text` from its bucket list, so `--session` left them unscoped —
  observable because each skill row prints the sessions it was loaded in.
- **Class:** script bug | missing step
- **Recurrence:** 2× across 2 sessions (`ses_ef77ed92…` 2026-10-04,
  `ses_ef29ef3e…` 2026-10-06) → applied, and the 2026-10-04 proposal was only
  half the fix

### 2026-10-06 — The user became the diagnostic instrument: 12 of 17 turns were evidence the agent never asked for

- **Signal:** `ses_ef29ef3e…` — 206 assistant turns to **17 user turns**, 718,778
  input tokens. Of the 17 user turns, **12** were the user pasting command
  output or correcting a published cause; only 5 were new instructions. The
  decisive artifacts were all volunteered: the `models list` output, the
  `health --json` dump, and the `model-fallback` log containing
  `reason=model_not_found` — the single line that refuted the policy theory,
  which the agent had never asked for.
- **Why:** §1 read "Ask **one** question, and only when a missing field would
  change which cause you investigate. Otherwise proceed on what you have… Do not
  interrogate the user before doing any work." That is anti-asking guidance, and
  it was followed: the agent researched alone, published **three** wrong causes
  in sequence, and each was killed by one command the user could have run in the
  first ten minutes. The skill never distinguished *interrogating the user about
  the problem* (correctly discouraged) from *requesting a diagnostic artifact*
  (should be the default).
- **Fix:** new §1a "Stay in the loop — ask for evidence as you go", stating the
  rhythm (hypothesis → ask for the one decisive artifact → update → repeat),
  plus three rules: ask before verifying, never go quiet, ask for artifacts not
  narratives. §1 rewritten to separate the two kinds of asking. §5 gained "put
  each hypothesis to the user with its decisive command". New `Do not` entries
  for going silent and for self-refuting a published cause. New
  `references/evidence-requests.md` (137 lines) with per-platform recipes — tool
  logs, services, containers, GUI clients, config-driven failures — and an
  explicit never-ask list (secrets, whole logs, anything already pasted).
  Description updated: "Asks the user for command output as it goes".
- **Class:** missing step | wrong depth
- **Recurrence:** 12× in `ses_ef29ef3e…` (each unsolicited evidence paste is one
  instance) → escalated to a new numbered step per the repeat rule

### 2026-10-06 — The issue tracker was searched once and never refined; the bug was filed and labelled P1 the whole time

- **Signal:** `ses_ef29ef3e…`. The verbatim error was queried in the issue
  tracker **once**, returned 10,297 hits across unrelated repositories, and was
  never refined. The user eventually had to ask *"btw. did you check open github
  issues?"* and then supply the link. Five reports of the actual bug existed
  throughout — `#142793` (filed against the exact version in use), `#144016`,
  `#157847`, and two **open P1** issues (`#135858` canonical, `#165414` filed
  that same day).
- **Why:** the 2026-10-04 fix put the GitHub issue-search call into a **table
  row** in §3, alongside six other tools. A table row reads as an option, not an
  obligation. There was also no instruction to *refine* a noisy query: 10k hits
  was treated as a result rather than as a failed search. And no instruction to
  search for the *mechanism* in maintainer vocabulary ("frozen seed catalog",
  `resolveOpencodeGoModel`), which is what would have matched the issue titles.
- **Fix:** §3 retitled "issue tracker first" and rewritten from a table into an
  ordered step: search before reading source, refine until it finds the bug or
  comes back genuinely empty, with four concrete query shapes and an explicit
  "a broad query returning noise is not an empty result". Added the mechanism
  search, an instruction to read a closed-as-duplicate issue's canonical target,
  and the rule that **a filed bug outranks your own reasoning** — stop deriving
  and cite it. New trap and `Do not` entry.
- **Class:** missing step | stale claim
- **Recurrence:** 2× across 2 sessions (`ses_ef77ed92…` 2026-10-04,
  `ses_ef29ef3e…` 2026-10-06) → escalated from a table row to a numbered step

### 2026-10-06 — Filing the page blocked the conversation, and the write-up is the slowest thing the skill does

- **Signal:** `write` has the **highest mean latency of any non-subagent tool**
  across the mined corpus — 29 calls, 416,209 ms total, **14,352 ms mean**.
  `ses_ef29ef3e…` rewrote one page three times as the diagnosis changed, the
  largest being a 507-line replacement.
- **Why:** §6 described filing as a synchronous block: write the page, update
  both indexes, log, cross-link, verify, commit — then reply. The user waits
  through all of it, and the agent cannot answer a follow-up that arrives
  mid-write. The skill also had no way to reconcile that with §4's "skeleton is
  the checkpoint", so the whole page was written inline.
- **Fix:** §6 retitled "File it — in a background job". The skeleton stays
  inline (§4, cheap, survives a context reset); the full write-up, bookkeeping
  and commit run as a `subagent(background=true)`, with an explicit list of what
  must be passed to it since a background subagent starts with fresh context.
  Answer the user first, report when the page lands.
- **Class:** missing step
- **Recurrence:** once, but the latency evidence is corpus-wide (14.4 s mean over
  29 calls)

### 2026-10-06 — A config write that reports success can still be wrong

- **Signal:** `ses_ef29ef3e…`. `openclaw config set models.providers…` reported
  "Updated" and the model then resolved — but the omitted `maxTokens` had
  silently defaulted to **8192**, and the omitted `reasoning` flag to false.
  Both were found only by reading back the stored config with
  `config get … --json` and comparing it against the upstream catalog. The
  `baseUrl` omission produced a *different* error the user had to report
  ("requires an explicit base URL").
- **Why:** the skill's `Local tests` section required stating what a run would
  prove, but had no rule that an accepted write must be *read back*. "The
  command runs" was already a trap for the config file; this is the same failure
  one layer down — the command succeeds and the stored value is wrong.
- **Fix:** new trap: a declaration can be accepted and still be wrong; read back
  what the tool stored and compare field by field against the source of truth.
- **Class:** missing trap
- **Recurrence:** 3× in `ses_ef29ef3e…` (maxTokens, reasoning, baseUrl)

### 2026-10-06 — Container reproduction was the breakthrough, and the skill's description discouraged it

- **Signal:** `ses_ef29ef3e…`. Pulling `docker/sbx-kit-openclaw:2026.9.3` and
  exercising the failing path reproduced the bug **with a placeholder key and no
  account**, then verified the fix end to end — because the failure happened
  before any network call. This converted a question for the user into an answer
  the agent could give, and it is how `maxTokens`/`reasoning` were caught.
- **Why:** the description said "Runs local reproduction only when asked, since
  the agent's sandbox usually cannot reproduce the user's environment", and
  §"Local tests" opened by warning the sandbox is not the user's machine. Both
  are true in general and both discouraged the single highest-value move of the
  session. The missing question was "does this failure need credentials, or does
  it fail before the first request?"
- **Fix:** `Local tests` now leads with container reproduction against the
  user's own image tag and names the credential-free test. Description updated
  from "runs local reproduction only when asked" to "Reproduces in a matching
  container when the failure needs no credentials". New trap: do not ask the
  user for what you can reproduce.
- **Class:** stale claim | wrong depth
- **Recurrence:** once, but it is the only verified-fix path in the session

### 2026-10-06 — The skill told the agent to call a script verb that does not exist

- **Signal:** `ses_ef29ef3e…` invoked
  `wiki-helpers.sh sweep bundles/tech`; it printed the usage banner. `sweep` was
  **proposed but never built** in the 2026-10-04 entry below.
- **Why:** §6 instructed "a `sweep` over the pages you touched if more than
  three", and the skill's own history recorded `sweep` as *proposed, not
  applied*. A proposal recorded in history leaked into the procedure as though
  it were shipped. The agent then ran the three checks per file in a loop, which
  is what `sweep` would have done.
- **Fix:** §6 and `Traps` now state plainly that there is **no `sweep` verb** and
  to run `validate`/`citations`/`links` per file.
- **Class:** stale claim
- **Recurrence:** once, but the source is the 2026-10-04 entry, so the mistake
  was available for two sessions

### 2026-10-06 — The corrections miner missed the highest-value correction for the second time

- **Signal:** `mine-sessions.py corrections` over `ses_ef29ef3e…` returned six
  candidates. The one that mattered — *"btw. did you check open github issues?"*,
  which redirected the entire diagnosis — **matched no marker and does not
  appear**. The six returned were marker collisions on ordinary prose: `stop`
  inside a pasted `openclaw gateway stop` transcript, `no,` inside
  `No change`, `do not`/`stop` inside a pasted `health --json` dump.
- **Why:** the same mechanism as the 2026-10-04 entry below, still unfixed. The
  detector matches correction *markers* (`no`, `stop`, `instead`, `don't`, `do
  not`) anywhere in a user message, so it fires on pasted command output that
  contains those words and misses a genuine correction phrased as a question.
  A user pasting terminal output is the dominant interaction in this skill, which
  makes the false-positive rate structurally high here.
- **Fix:** proposed, not applied — see the proposal in the reply. Two changes to
  `mine-sessions.py corrections`: down-weight or exclude candidate text that
  looks like pasted terminal output (shell prompts, banner lines, `$` prefixes),
  and add a positive signal for a user turn that follows an assistant turn
  asserting a root cause. The 2026-10-04 entry proposed only the second half.
- **Class:** script bug
- **Recurrence:** 2× across 2 sessions (`ses_ef77ed92…` 2026-10-04,
  `ses_ef29ef3e…` 2026-10-06) → escalated: the 2026-10-04 proposal was
  half a fix and was never applied

### 2026-10-04 — Prose docs produced three claims a schema and one source file overturned

- **Signal:** `ses_ef77ed92…`, 119 tool calls, 588,070 input tokens. Hypothesis
  H1 ("`opencode mcp add` rejects `--url`/`--header`") was recorded at
  *likely* confidence and cited `opencode.ai/docs/cli`; the maintainer reported
  the flags work. A follow-up check of `opencode.ai/config.json` and
  `packages/opencode/src/config/config.ts` refuted three separate page claims:
  `enabled_providers` exists and is documented ("When set, ONLY these providers
  will be enabled"), `mcp` is flat `additionalProperties` in both versions
  (there was no `mcp.servers` migration), and `OPENCODE_CONFIG_DIR` is honoured
  by `ConfigPaths.directories`.
- **Why:** every wrong claim came from a prose page, and all three doc pages
  deferred to `opencode.ai/config.json` as "source of truth" while mentioning it
  only as an editor-autocomplete tip. Worse, `opencode.ai/docs/cli` served the
  **1.x** page while the kit installs 2.x — the only signal was a site banner
  pointing at `/v2/docs`. The skill had no step requiring an artifact check and
  no trap about version drift, so prose was treated as authoritative.
- **Fix:** `SKILL.md` §3 table now leads with `webfetch` on
  `api.github.com/search/issues` and marks firecrawl "when available"; new
  §3a "Check the version you are reading — then check the artifact" with the
  prose-vs-artifact table; new traps for version drift, absence-of-docs, and
  citation renumbering.
- **Class:** missing step | stale claim
- **Recurrence:** 3× in `ses_ef77ed92…` (three distinct claims, one root cause)

### 2026-10-04 — The named search tool was unavailable and the page did not say so

- **Signal:** 2 failed `websearch` calls in `ses_ef77ed92…`, both
  `StatusCode: non 2xx (403 POST https://search.parallel.ai/mcp)` — the
  provider, not the query. The `firecrawl_*` tools named in §3 were not present
  in the session at all.
- **Why:** the skill's tool table names one search tool with no fallback, so the
  agent substituted a weaker one silently. The page's Evidence section then read
  as though the stronger search had run. The substitute that worked —
  `webfetch` on the GitHub issue-search API — was the highest-yield move of the
  whole session and was not in the skill.
- **Fix:** §3 table rewritten with the GitHub issue-search row first, firecrawl
  marked "when available", plus an explicit instruction to state the fallback on
  the page.
- **Class:** stale claim | missing trap
- **Recurrence:** 2× in `ses_ef77ed92…`

### 2026-10-04 — A hand-edited `log.md` entry was duplicated twice

- **Signal:** `ses_ef77ed92…`, `log.md` edited 3× and the same `**Query**` entry
  present twice; lines 12–15 deleted to repair it, then the identical duplication
  recurred one commit later and lines 12–15 were deleted again.
- **Why:** both times the insertion was a hand-written `edit` anchored on
  `## 2026-10-04` whose `newString` re-supplied the existing entry text — once
  because the surrounding context was pasted in to make the anchor unique. The
  skill told the agent to append a log entry but never said to use
  `wiki-helpers.sh log`, so the helper sat unused while its own output went
  unfixed.
- **Fix:** §6 now names the helper command and forbids hand edits anchored on a
  date heading. `wiki-helpers.sh append_log` also emitted `* **Action**:` while
  every established entry uses `- **Action**:` — fixed, and the pre-existing
  `*` entries in `bundles/tech/log.md` and `bundles/gesundheit/log.md` are
  visible residue of it.
- **Class:** missing step | script bug
- **Recurrence:** 2× in `ses_ef77ed92…` → escalated to an explicit step per the
  repeat rule

### 2026-10-04 — The per-page verification loop is a script, not a shell habit

- **Signal:** `ses_ef77ed92…` ran the same `for f in …; do validate; links; done`
  sweep 3× over growing file lists, 4–5 calls each; the
  `ses_ef8c2adb…` session proposed the same `sweep` verb and it was never built.
- **Why:** every wiki skill needs the same four checks over the same bundle, and
  the loop is retyped per skill and per session. It is deterministic, which is
  the test `auto-skill` uses to decide something should be a script.
- **Fix:** proposed, not applied — `wiki-helpers.sh sweep <bundle>` running
  `validate` + `citations` + `links` + `refs` in one call. Owner is `wiki-page`,
  which owns the helpers; `wiki-lint` consumes it.
- **Class:** missing script
- **Recurrence:** 3× in `ses_ef77ed92…`, proposed in `ses_ef8c2adb…` → 2
  sessions

### 2026-10-04 — The miner's correction detection missed both substantive corrections

- **Signal:** `corrections` in `ses_ef77ed92…` returned 2 candidates, both being
  the skill-invocation messages themselves. The two corrections that actually
  changed the diagnosis — "The issue was the jq script. The source file did not
  exist" and "it looks like opencode version 2 allows loading config from a
  directory" — matched no marker and appear nowhere in the output.
- **Why:** both arrived lowercase, mid-thread, with no correction marker. They
  are the highest-value signal `auto-skill` consumes, and the section that
  exists to surface them was empty for the one session where they mattered most.
- **Fix:** proposed, not applied — broaden marker matching in
  `mine-sessions.py corrections` to include a user turn that follows an
  assistant turn asserting a root cause.
- **Class:** missing script
- **Recurrence:** 2× in `ses_ef77ed92…`