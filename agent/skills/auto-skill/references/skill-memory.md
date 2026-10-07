# Skill memory — candidate new skills

AutoSkill appends here when the mined evidence points at work no existing skill
owns. One row per idea, **never deleted**: a rejected idea records why, which is
the only thing that stops the same proposal returning every run.

Check this file before proposing anything. A row already here is either adopted
or rejected, and both answers are already recorded.

## Open

| Skill | Trigger | Problem it solves | Evidence | Status |
|---|---|---|---|---|
| `handoff` | "compress session", "continue later", "pick this up tomorrow" | A long wiki operation does not survive context loss. The session that produced this file ran 248 tool calls and 4.07M input tokens across ~5 hours; a context reset mid-way would have lost the reasoning behind the kit's persistence design, not the files. | `ses_ef8c2adb…` — `tokens_input` 4,072,611 · github.com/mattpocock/skills | proposed 2026-10-04 |
| `sandbox-kit` | "edit the kit", "add a kit arg", "update the kit README", "the sandbox workload" | `kits/` is a second product surface with its own sync map — descriptor ↔ Dockerfile ↔ configure script ↔ `sbxenv.yaml` ↔ README — and nothing owns it. `wiki-create-bundle` already does this for bundles by naming its four sync points; the kit has five and no list. | `SPEC.md` §4.0 added `kits/` 2026-10-04 · one workload today, expected to grow | proposed 2026-10-04 |
| `bundle-maintenance` | "move these pages to another bundle", "update all the doc URLs to v2", "make the source fields consistent", "the raw file is in the wrong bundle" | Cross-page mechanical edits that no single-page skill owns: `wiki-page` is scoped to *one* page and says so, `wiki-lint` is read-only, and `wiki-ingest` starts from a new source. Each of these operations is a fan-out with a defined sync surface — the page, both indexes, the log, `raw/`, reciprocal links, and any template that teaches the old convention — and the failure mode is partial completion: one commit moves a page and forgets its index entry. The bundle moves on 2026-10-04 left `raw/docker sbx.md` behind in `main/`, which went undetected until a dangling `source:` was noticed. | `ses_ef552092…` — 22× grep over one bundle path across 5 sessions, 17× single-file edits to one file, 2 cross-bundle sync points missed today (the raw clip, and both `source-summary.md` templates still teaching `source: raw/`) | proposed 2026-10-05 |

## Rejected

| Skill | Why not |
|---|---|
| `llm-wiki` (alirezarezvani/claude-skills) | Its five slash commands duplicate `wiki-ingest`, `wiki-query`, `wiki-lint`, `wiki-page` and `wiki-create-bundle` one for one. Its value is two scripts — `update_index.py` and `graph_analyzer.py` — which were ported into `wiki-helpers.sh` as the `index` verb and proposed for `wiki-lint`. Nothing to install. |
| `skill-health` | Overlaps `skill-creator`, which owns authoring and validation of a single skill. AutoSkill's own scope rule forbids proposing it. |
| `wiki-graph` | The work is deterministic: link-graph statistics are a script, not a judgement. `wiki-lint` plus the analyzer owns it; a skill wrapping a script adds a routing hop and nothing else. **Confirmed empirically 2026-10-05:** the `wiki-link-checker` *subagent* — a fresh-context agent given this judgement — reported "5 broken links" on `bundles/tech` where the true in-scope count is zero. It counted template placeholders as broken and reported link occurrences as findings. Handing graph work to something that reasons rather than counts makes it worse, not better. |
| `wiki-research` | Not a separate skill. "Research X and persist it" is `wiki-ingest` with a URL source; splitting it would give one task two entry points. Recorded as a gap in `wiki-ingest` instead. |

## Adopted

| Skill | Where it came from | What it replaced |
|---|---|---|
| *(none yet)* | | |
