# wiki-auditor — usage and learnings

Written by `auto-skill` from mined session data. Sessions are named by id so an
entry traces back to its evidence. Newest first.

A subagent, not a skill: defined in `.opencode/agents/wiki-auditor.md`, loaded
by `build` and `plan`. Covered by `audit-skills.sh` since 2026-10-05.

## Usage

| Metric | Value |
|---|---|
| Launches recorded | 0 |
| Sessions | — |
| Last used | never launched |
| Failed calls attributable | 0 |

Zero launches is a finding about the routing, not about the agent. Two subagents
with adjacent remits exist and only one is being used: conformance auditing and
link-graph checking are the same fan-out over a bundle, and the link checker is
picking up work the auditor owns — its 2026-10-05 run reported frontmatter and
orphan findings that are in this agent's remit. Its own definition warns about
the same overlap in the other direction, citing a run that counted template
placeholders as broken links.

## Learnings

### 2026-10-05 — it denied all shell while owning the checks a script already does

- **Signal:** `audit-skills.sh`'s new Subagent Convention Coverage section
  reported `wiki-auditor` as "Denies shell: yes (no re-allow)" and "Names
  wiki-helpers: no", on its first run against this repo.
- **Why:** the agent owns frontmatter completeness and index-coverage checks,
  and `wiki-helpers.sh validate` and `links` do both deterministically — it was
  also denied the shell needed to run them. The identical defect had just been
  fixed in `wiki-link-checker`, which is how this one came to light: the
  detector, not a human, found the second instance.
- **Fix:** `shell` re-allowed for the same five read-only verbs, with the
  writing verbs still denied, and a "Run the script; do not reimplement its
  checks" section naming `validate` as the frontmatter check and `links` as the
  bundle-wide one. The definition now states what stays with the agent —
  reserved-page misuse, naming drift, index round-trip, log format, and stray
  artifacts — so narrowing the tool does not look like dropping the work.
- **Class:** wrong depth (the convention existed, at the wrong layer)
- **Recurrence:** never launched, so the latent defect never fired — which is the
  argument for keeping the detector rather than waiting for a second report