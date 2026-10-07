---
name: debug-research
description: Use when the user reports a bug, error, failure, or unexpected behaviour, or asks to be given a debugger before supplying the issue — triggers include "here's the error I'm getting", "this stack trace", "why does X fail", "help me debug this", "act as my debugging assistant", "debug this issue", "this command doesn't work". The issue may arrive before or after the skill loads. Asks the user for command output as it goes, reads the wiki first, then the issue tracker, upstream docs and source, and files the diagnosis as a wiki page in a background job. Reproduces in a matching container when the failure needs no credentials. Not for questions the wiki already answers (wiki-query), filing a single page (wiki-page), or linting (wiki-lint).
---

# Diagnose an issue by research, then file what you learned

You are a research-first debugger. An issue arrives — an error message, a stack
trace, a command that behaves wrongly — and your job is to explain it from
evidence, not to guess, and then leave the explanation in the wiki so the next
session starts from what you learned instead of from nothing.

Two habits carry this skill:

- **Evidence before diagnosis.** The `# Evidence` section exists before any
  cause is proposed. A fix without a cause is a coincidence that will be
  re-diagnosed next week.
- **The page is the checkpoint.** Write the skeleton before the long research
  and fill it section by section. Research burns credits and gets cut off by
  rate limits and context compaction; a skeleton means the findings you already
  paid for survive the interruption.

A third habit is what keeps the first two honest: **stay in the loop.** The user
has the affected machine, so ask them for command output early and often rather
than reconstructing their environment from documentation. §1a is that loop.

**Active bundle:** read `bundles/index.md` and pick by subject matter —
tooling, sandboxes, and coding agents belong in `bundles/tech/`. State the bundle
at the start. All page paths below are bundle-root relative, because the bundle
*is* the Obsidian vault root.

## The sandbox is not the user's machine

Expect that you **cannot reproduce the issue** here: different OS, different
versions, no access to their host, their config, their credentials, or their
data. A local run that "works" in this sandbox is evidence about the sandbox,
not about their bug.

That is a constraint, not a limitation to apologise for. Documentation, source
code, and issue trackers are version-matched and authoritative; a local
reproduction is neither. Default to reading, and treat execution as a tool you
must justify before using — see § "Local tests".

The one exception worth reaching for early is a **container reproduction
against the user's own image tag**, when the failure happens before it needs
their credentials. That is version-matched by construction, and it turns a
question for the user into an answer. § "Local tests" says how to decide.

## Steps

### 1. Take the issue

Extract, from whatever the user pasted or dropped:

| Field | Why it changes the diagnosis |
|---|---|
| Verbatim error text | The primary evidence. Quote it, never paraphrase |
| Tool, library, version | Most bugs are version-specific behaviour |
| Exact command or call | Configuration and flags are half of most causes |
| Platform, architecture, runtime | Path separators, case sensitivity, cgroups |
| What changed | Upgrade, config edit, new host, new key — narrows the space fast |
| Expected vs actual | Distinguishes a bug from a misunderstanding |

Ask for any field whose absence would change which cause you investigate.
**Asking for artifacts is the default, not the exception** — see §1a below.
What is discouraged is *interrogating the user about the problem* ("tell me
more about what you meant"), which shifts description work onto them and rarely
changes the investigation. Requesting a command's output is the opposite: the
highest-yield move available, and chronically under-used.

Write any assumption you did not ask about into the page, labelled as one.

**If no issue has arrived yet**, the load itself is the request. Name the bundle
you would work in, say what you need — the verbatim error, the tool and its
version, the exact command — and wait. Do not go looking for a problem to
debug, and do not read the wiki speculatively; an issue you guessed at produces
a page about the wrong thing.

### 1a. Stay in the loop — ask for evidence as you go

**The user is the only person with hands on the affected machine, and the loop
with them is the skill's heartbeat, not an interruption of it.** Read
`references/evidence-requests.md` before the first research pass.

The rhythm is:

> form a hypothesis → ask for the one artifact that would confirm or kill it →
> update the page → repeat

Three rules, each paid for by a session that broke it:

- **Ask before verifying, not after.** Do not spend a research pass confirming
  something the user can settle with one command. Asking *after* you have
  published a cause means the cause was never load-bearing.
- **Never go quiet for long stretches.** Say what you are doing and what you
  need next. A user who cannot see progress cannot help, and cannot tell
  stalling from work.
- **Ask for artifacts, not narratives.** Give a copy-pasteable command and name
  the field you need — "the line containing `reason=`". "Paste the output"
  invites a paraphrase; naming the field gets evidence.

The evidence-request file carries the per-platform recipes — tool logs, running
services, containers, GUI clients, config-driven failures — plus what never to
ask for (secrets, whole logs, anything already in the transcript).

**When the user's evidence settles a hypothesis, cite it as theirs**, with the
command that produced it. They did the work.

### 2. Wiki first — always

The wiki is the accumulated answer to this exact question. Reading it before
the internet is not ceremony; it is the difference between one research pass
and two.

1. `bundles/index.md` → choose the bundle.
2. `<bundle>/index.md` → the page catalog. Never grep the tree first.
3. Read the hits and follow links outward.

Report what the wiki already knows before you search online. If it answers the
issue, you are done — say so, and offer to correct or extend the page instead
of filing a duplicate.

### 3. Research the tool itself — issue tracker first

**The issue tracker is step one, not one row of a table.** Search it before
reading source, and **refine the query until it either finds the bug or comes
back genuinely empty.**

The failure this guards against, from a session that cost hours: the verbatim
error was searched **once**, returned 10,297 hits across unrelated repositories,
and was never refined. Five reports of the actual bug existed the whole time —
two labelled P1, one filed against the exact version in use. The agent then
re-derived all of it from source, got it wrong three times, and the user
eventually supplied the issue link themselves.

A broad query returning noise is **not** an empty result. Refine it:

```
repo:<owner>/<repo> "<verbatim error>"
repo:<owner>/<repo> "<verbatim error>" <subsystem>
repo:<owner>/<repo> "<distinctive identifier>"          # a function, a config key
repo:<owner>/<repo> "<the mechanism, in maintainer words>"
```

Search for the **mechanism** too, not only the symptom. Maintainers describe
bugs in their own vocabulary — "frozen seed catalog", a function name, a config
key — and the issue titled with that vocabulary will not match your error
string. Once you have read one relevant issue, its language is the best query
you have for the next one.

| Question you are answering | Tool |
|---|---|
| Has anyone hit this exact error? | `webfetch` on `https://api.github.com/search/issues?q=<query>` — indexes issue **bodies** and PR descriptions. Start here, and refine |
| Is there a canonical or open issue? | Read the hits' `state`, labels and `state_reason`. Closed-as-duplicate points at a canonical issue; read **that** one, and any still-open issue it names |
| Has anyone hit this exact error? | `firecrawl_search` with `categories: ["developer"]`, **when available** — also indexes READMEs and code docs, which issue search misses |
| What does one known page say? | `firecrawl_scrape` on that URL, `formats: ["markdown"]`; `webfetch` when firecrawl is absent |
| Where is this enforced in the code? | `ask_wiki_question` on `owner/repo` |
| What pages exist under these docs? | `firecrawl_map` with a `search` term |
| Long hunt, URLs not yet known | `firecrawl_agent` with a schema, then poll `firecrawl_agent_status` |
| A plain URL, no index needed | `webfetch` |

Tabulate every hit by **what line precedes the error**, not just by whether it
mentions the error. One generic string can stand for a dozen unrelated causes,
and the invariant across hits ("all six reports end at a failing install hook")
is worth more than any single report. That is how this skill's own page turned
one opaque message into a one-line proof.

**A filed bug outranks your own reasoning.** If the tracker says the behaviour
is broken and unfixed, stop deriving it — cite the issue, state the workaround,
and say which release fixes it (or that none does). Re-deriving a known bug from
source is how a session publishes three wrong causes for something already
labelled P1.

**When the named search tool is unavailable, say so and fall back.** Do not
silently substitute a weaker tool and then write the page as if the stronger
search had run — the page's confidence labels have to describe the search that
actually happened.

### 3a. Check the version you are reading — then check the artifact

Two failures in one session came from prose documentation, and both were
corrected only by reading something the prose defers to.

**Version.** A docs site can serve a different major version than the one you
are running, at the *same* URL, with nothing but a banner saying so. Before
drawing a behavioural conclusion from a doc page, look for a version banner, a
`/v2/`-style path, or a stated version in the page itself. If the user named a
version, read that version's docs.

**Artifact.** When a project publishes a machine-readable artifact — a JSON
Schema, a manifest, a lockfile, readable source — that artifact outranks the
prose, because the prose is a claim about it. Specifically:

| The prose said | The artifact said | Consequence |
|---|---|---|
| `mcp.servers.<name>` | `mcp` typed as flat `additionalProperties` | a "documented" schema migration did not happen; a caveat built on it was wrong |
| provider restriction needs `experimental.policies` | `enabled_providers` present and described | the "field is probably inert" warning was wrong |

Both doc pages deferred to `opencode.ai/config.json` as "the source of truth" —
and mentioned it only as an editor-autocomplete tip. **Look for the artifact
explicitly.** Read source when the schema is silent: a raw file beats a
speculation, and the line you cite becomes the citation in the page.

When prose and artifact disagree, say so on the page and cite the artifact.
Do not average them.

Read the version the user runs. "Latest" docs describe someone else's
machine. Check release notes and the changelog across the version boundary when
the bug appeared after an update — that diff is usually the answer.

For a starting point by symptom class, read
`references/source-playbook.md` — it maps "works in CI but not locally",
"401/403", "broke after an update", and similar classes to the source that
settles them fastest. Read it when you have a symptom and no lead; skip it when
the error names its own subsystem.

### 4. Create the page skeleton now

Before the deep research, not after. Create the page with its frontmatter and
empty section headings, then fill each section as its sources come in, citing
as you go.

```bash
# frontmatter shape — see wiki-page for the full field list
---
type: query
title: "<Tool> <symptom>"
description: "<one sentence: the symptom and the cause, or the symptom alone>"
tags: [<tool>, <subsystem>, <error-kind>]
timestamp: <ISO 8601 with Z>
resource: <canonical upstream URL — docs page, issue, or repo>
---
```

Filename is **Title Case with spaces** (`Container exec fails.md`), matching
every committed page — see § Traps.

### 5. Diagnose

- **Symptom is not cause.** The error text is where the failure surfaced. Say
  where the cause lives, and if you cannot, say that.
- **One hypothesis at a time**, stated as "I think X because Y". Two
  simultaneous explanations are zero explanations.
- **Put each hypothesis to the user with its decisive command** before spending
  a research pass on it (§1a). A hypothesis you publish and then refute yourself
  was never load-bearing — and three of those in one session is how a user
  loses confidence in every answer.
- **A filed upstream bug ends the derivation.** If the tracker shows the
  behaviour is broken and unfixed, cite it and stop reasoning from source. See
  §3.
- **Label confidence** — confirmed, likely, speculative.
- **Record what you ruled out and why.** This is the section that makes the
  page worth more than the answer it contains: it stops the next session from
  re-walking the same dead ends.
- **"The docs say X" is a ruled-out, not a cause**, when X does not match the
  symptom. Documented behaviour that does not explain the failure eliminates a
  hypothesis; it does not establish one.
- **A claim refuted after you published it stays on the page.** Do not quietly
  delete it. Keep it under `Ruled out` with the evidence that killed it — that
  section is what stops the next session re-walking it, and what shows a later
  reader which claims were load-bearing.
- **"Could not determine" is an acceptable result.** Say which sources you read
  and what would settle it. Inventing a plausible cause to fill the page is the
  one failure this skill exists to prevent.

### 6. File it — in a background job

**The write-up runs in the background.** Filing a page is minutes of writing,
verifying and committing, and the user should not be waiting on it. Answer them
first, launch the write-up as a background subagent, and report when it lands.

```
subagent(background=true) →
  write the page, update both indexes, log the entry, cross-link,
  run validate/citations/links, commit
```

Pass the subagent everything it cannot re-derive: the page path, the verbatim
symptom, the evidence already gathered **with its sources**, the confirmed
cause, what was ruled out and why, and the pointer to `wiki-page` for the
conventions. A background subagent starts with fresh context — anything you do
not pass, it will invent.

Keep §4's skeleton **inline**. It is cheap, it is the checkpoint that survives a
context reset, and it is what the background job fills in.

Page shape:

```markdown
# Overview          — symptom verbatim, tool + version, expected vs actual
# Evidence           — what each source says, [n] citations, version-matched
# Diagnosis          — cause, or ranked hypotheses with confidence
# Fixes and workarounds
# Ruled out          — hypothesis + why it was dropped
# Relationships      — links to entity/concept pages, both directions
# Citations          — [1] URL — what it supports
```

Then, as one bookkeeping step:

- Update the **root** `index.md` and the **directory** `index.md` — entry text
  is the frontmatter `description`, verbatim. Note the helper's `index` verb
  dedupes on the **link**, so it will report "already listed" and silently keep
  a stale description; when a description changes, edit the index line directly.
- Append a `**Query**` entry to `log.md` under today's `## YYYY-MM-DD`, with
  `bash .opencode/skills/wiki-page/scripts/wiki-helpers.sh log <bundle> <action>
  <message>`. **Use the helper, never a hand-written edit anchored on
  `## <date>`.** Pasting the surrounding entries into an `edit` call to get the
  anchor is how the same entry ends up in the log twice; that happened twice in
  one session before it was noticed. If the helper's output does not fit,
  append with `sed`/`awk` against the heading — never by re-supplying context.
- Cross-link every entity and concept page the diagnosis relies on, and add the
  reciprocal link from those pages.

Verify before committing: `validate`, `citations` and `links` on the page — or
`sweep <bundle>` for all three over every page in one call. Add `--wrap` only
when the column check is what you mean to fix; the committed bundles carry
pre-existing one-or-two-column overruns, so the default sweep leaves it out.

```bash
bash .opencode/skills/wiki-page/scripts/wiki-helpers.sh sweep bundles/tech
```

**Then propose, and wait.** The investigation page is always filed. New
`entity` and `concept` pages — a tool, a flag, a mechanism — are proposed in
your reply with a one-line description each, and created only when the user
agrees. A wiki that grows a page per flag stops being readable; a wiki that
files the diagnosis stays worth reading.

Answer the user **before** describing the filing work, in **their language**.
The page itself is English (`AGENT.md` § Language) — persisted wiki data is
always English.

## Local tests

Allowed, and occasionally right — but the burden is on the run to earn its
place, because this sandbox is not the user's machine.

**One local run that is almost always worth it: reproduce the failure in a
container.** Pull the same image tag the user runs and exercise the failing
path inside it. This converts a question you would otherwise have to ask into an
answer you can give — the strongest form of responsiveness available. It is
also cheap and read-only with respect to the user's machine.

The trick is finding the part of the failure that needs no credentials. In the
session that proved this, the bug happened *before* any network call, so the
whole resolution path was reproducible with a placeholder key and no account.
Ask what your failure needs before concluding it needs the user's environment:
"does this fail before or after the first request?" is often the whole test.

When a local run *does* settle something, say so on the page and give the
command — the next session can re-run it.

Before running anything else, state out loud what the command would prove and
why this environment can answer it. Then:

- Prefer documentation and source. Reading a released config schema beats
  running the tool against a config you invented.
- Reading the project's own files, `git log`, `git diff`, and `git blame` is
  always safe — read-only, and it is how you find which change introduced the
  bug.
- A `--help` or `--version` probe is cheap and often settles a version-drift
  hypothesis. Say that it is a probe.
- **Never install packages, start services, or mutate state** without asking.
- **Never run the user's failing workload** unasked — on their machine it would
  be evidence, here it is a simulation that will mislead the page.
- The wiki helper scripts are always fine. They only read and write this repo.

## Traps

Inherited from the sibling skills; all of them have bitten a real session.

- **Title Case filenames with spaces**, not `kebab-case.md` as `AGENT.md` says.
  Every committed page follows the precedent; a kebab-case page breaks every
  absolute link into the bundle.
- **`source:` holds a full URL** in practice, not a path under `raw/`.
- **Two indexes, not one** — root `index.md` *and* the directory `index.md`.
  Root index entries percent-encode spaces (`%20`).
- **Never hard-wrap inside a link target.** Every link here points at a
  filename with a space, and a markdown link cannot span a line break. Wrapping
  `](/concepts/Style` / `guide.md)` silently breaks the link — this has shipped.
- Bump `timestamp` on every edited page. Preserve existing frontmatter keys.
- `index.md` and `log.md` are reserved at every level; never page them.
- `raw/` is immutable, needs no frontmatter, and is not for pasting an issue
  into uninvited.
- `log.md`: `## YYYY-MM-DD`, newest first, bolded action word.
- Wrap prose at ~80 columns; tables, link lists, and citation URLs run long.
- **The docs site may not serve the version the user runs.** Same URL, older
  major version, one banner of warning. Every behavioural claim drawn from such
  a page inherits the wrong version. Check the banner and the canonical path
  before citing, and say which version the page was.
- **Absence of documentation is not evidence of absence.** A hypothesis built on
  "the docs do not mention these flags" plus "the reference kit avoids that
  call" is two claims about what is *written down* stacked into a claim about
  what the tool *does*. That hypothesis was confidently wrong and the flags
  worked. Absence eliminates a documented-behaviour hypothesis; it never
  establishes a behavioural one.
- **Number citations above the highest existing one.** Adding `[7]` and `[8]`
  mid-page collided with two issue references already using them, and the repair
  was four line-targeted `perl` renumbering passes. Read the `# Citations`
  section before writing the first `[n]`, not after.
- **A hypothesis you published stays on the page after it is refuted.** Do not
  quietly delete it. Keep it under `Ruled out` with the reason it fell — that
  section is what stops the next session from re-walking it, and what shows a
  later reader which claims were load-bearing. Three claims on the page this
  skill produced were overturned by the schema, and each is worth more recorded
  than deleted.
- **A resolved case is not a closed case.** Naming what the fix leaves inert or
  unverified is part of the diagnosis. "The command runs" is not "the config
  takes effect" — check that the file is one the tool actually reads.
- **A declaration can be accepted and still be wrong.** `config set` reporting
  success means it validated, not that it is correct. Fields that default
  silently — a token limit, a capability flag — leave a working-looking config
  that misbehaves later. Read back what the tool *stored* (`config get … --json`)
  and compare it against the source of truth, field by field. In the session
  that proved this, the omitted token limit defaulted to 8192 and would have
  truncated every reply, with no error anywhere.
- **Searching an issue tracker once is not searching it.** A broad query that
  returns thousands of unrelated hits is not an empty result. See §3.
- **Going quiet is a defect, not a style.** Long autonomous stretches without a
  word to the user read as stalling and remove the one person who can settle the
  question. See §1a.
- **Do not ask the user for what you can reproduce.** A container run against
  the same image tag is often enough, and it is strictly better than a question:
  it answers without spending the user's time. See `Local tests`.

## Scripts

`.opencode/skills/wiki-page/scripts/wiki-helpers.sh`, called by its
repo-root path — the `skill` tool does not change the working directory, so a
bare `scripts/...` resolves against the repo root and fails.

```bash
bash .opencode/skills/wiki-page/scripts/wiki-helpers.sh bump <file>       # timestamp
bash .opencode/skills/wiki-page/scripts/wiki-helpers.sh index <bundle> <dir> <name> <desc>
bash .opencode/skills/wiki-page/scripts/wiki-helpers.sh log <bundle> <action> <message>
bash .opencode/skills/wiki-page/scripts/wiki-helpers.sh validate <file>  # frontmatter
bash .opencode/skills/wiki-page/scripts/wiki-helpers.sh citations <file>  # [n] markers
bash .opencode/skills/wiki-page/scripts/wiki-helpers.sh links <file>      # targets resolve
bash .opencode/skills/wiki-page/scripts/wiki-helpers.sh sweep <bundle>    # the three above,
                                                                          # every page, one call
bash .opencode/skills/wiki-page/scripts/wiki-helpers.sh refs <needle>    # every mention
```

Run `sweep <bundle>` before you report a page filed. It exits non-zero on
findings, which is what makes it usable as a check.

**Execution history:** `.opencode/skills/auto-skill/history/debug-research.md`
records what actually went wrong in past sessions — which tool was unavailable,
which claim a doc page produced and a schema overturned, and which bookkeeping
step had to be redone. Read it before starting a diagnosis.

## Do not

- Propose a cause before the `# Evidence` section has content.
- Present an unverified hypothesis as a root cause, or a documented behaviour
  that does not match the symptom as an explanation.
- Go silent for a long stretch, or research alone what one command from the user
  would settle. See §1a.
- Publish a cause and then refute it yourself in the same session without
  having asked the user first — that is three wrong answers where one question
  would have done.
- Declare the tracker searched after a single broad query. See §3.
- Run the user's failing workload, install anything, or mutate state unasked.
- File the issue into `raw/` uninvited — that is ingesting a source, which is
  on `AGENT.md`'s "ask first" list.
- Create `entity` or `concept` pages before the user approves them.
- Add a second page for an issue the wiki already answers. Extend the existing
  page and bump its `timestamp`.
- Modify `AGENT.md`, `SPEC.md`, or `CLAUDE.md`.
- Edit `.obsidian/`, change an existing page's `type`, or use relative links.