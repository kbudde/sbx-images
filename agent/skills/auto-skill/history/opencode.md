# opencode — usage and learnings

Written by `auto-skill` from mined session data. Sessions are named by id so an
entry traces back to its evidence. Newest first.

This is a **harness-provided** skill, not one this repository defines — it ships
with OpenCode rather than living in `.opencode/skills/`. It is recorded here
because it governed a whole session and its central instruction turned out to
be contested by this repo's own research.

## Usage

| Metric | Value |
|---|---|
| Loads recorded | 1 |
| Sessions | `ses_ef5520920ffeNFV6a4wubuNSmX` |
| Last used | 2026-10-05T06:09:00Z |

253 tool calls followed the load. One load that is used heavily is worth
recording; a load that is never used is a description problem, and this was
neither.

## Learnings

### 2026-10-05 — the skill's advice on the config schema is contested by this repo

- **Signal:** the skill states that `opencode.ai/config.json` "may describe V1"
  and must not be used to infer V2 field names. `bundles/tech/log.md` on
  2026-10-04 concluded the opposite after reading the schema and source: that it
  types `mcp` as a flat `additionalProperties` and contains `enabled_providers`,
  and that prose docs and schema contradict each other while both name the
  schema as source of truth.
- **Why:** both cannot be right, and the answer decides which artifact to verify
  configuration against. Neither source is wrong about its own subject: the
  skill is describing a distribution hazard, the log entry is describing what the
  schema currently says.
- **Fix:** not adjudicated. The work settled every claim against the **live
  resolved agent list** (`opencode debug agents`) and against real spawns, which
  depend on neither source. Recorded on
  `bundles/tech/concepts/OpenCode subagents.md` under "A caveat on sources", and
  left open deliberately — resolving it by preference would be guessing.
- **Class:** unclear trigger
- **Recurrence:** 1× in `ses_ef5520920ffeNFV6a4wubuNSmX`

### 2026-10-05 — the version policy was the most valuable instruction in it

- **Signal:** the skill opens with "Always answer for OpenCode V2 unless the user
  explicitly asks about V1" and lists the V1 traps by name.
- **Why:** the surrounding ecosystem was actively misleading. DeepWiki indexes
  this repository at V1 and returned only V1-shaped answers — the `task` tool,
  `subagent_type`, an `agent` (singular) config key, a `permission` object, a
  top-level `subagent_depth`, and a built-in `scout` agent — none of which exist
  in V2, and all of which are **silently ignored** rather than rejected when
  carried over. That last property is what makes them dangerous: a V1 answer
  pasted into a config produces no error, just absence.
- **Fix:** no change to the skill. Recorded because the trap generalises — a
  secondary source indexed at the wrong major version is worse than no source,
  and the tell is a set of names that all look plausible.
- **Class:** stale claim
- **Recurrence:** structural