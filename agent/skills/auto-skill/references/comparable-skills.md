# Comparable opencode/agent skills (reference)

A starting map for auto-skill's Step 3. It is a snapshot, not the truth —
re-run `firecrawl_search` for anything newer before relying on it. Sources are
linked so the reader can check a claim rather than trust this file.

## Skill collections and individual skills

| Skill | Repo / source | What it does | Verdict |
|-------|---------------|--------------|---------|
| llm-wiki v2.9.0 | github.com/alirezarezvani/claude-skills | The same Karpathy llm-wiki pattern this repo implements, as a plugin. Ships **eight stdlib-only Python tools**: `init_vault.py`, `ingest_source.py`, `update_index.py` (regenerates `index.md` from page frontmatter), `append_log.py`, `wiki_search.py` (BM25), `lint_wiki.py`, `graph_analyzer.py` (hubs, orphans, clusters, disconnected components), `export_marp.py`. Plus three sub-agents and nine reference docs. | **Port two scripts, install nothing** — its five slash commands duplicate `wiki-ingest`, `wiki-query`, `wiki-lint`, `wiki-page` and `wiki-create-bundle` one for one. `update_index.py`'s semantics became `wiki-helpers.sh index`; `graph_analyzer.py` is proposed for `wiki-lint`. Its "pure stdlib, runs everywhere" argument settled the question of whether a wiki script may depend on anything. |
| research-llm-wiki | Hermes bundled skill (hermes-agent.nousresearch.com) | Same pattern. Two things this repo does not do: it **fetches the URL itself** into `raw/articles/` rather than asking the user to clip it, and it stores a **sha256 of the raw body** so a re-ingest of the same URL can skip an unchanged source and flag drift — "the difference between a growing wiki and a pile of duplicates." | **Adopt both ideas.** The URL gap is recorded in `history/wiki-page.md`; the sha256 check is the cheapest defence against duplicate ingests this repo lacks. |
| Wiki Builder | academy.dair.ai plugin write-up | Generalises the pattern past research (personal, business, team wikis) and keeps one prompt file per operation instead of one skill. | Situational — the prompts-as-files shape is what `references/` already is here. |
| skill-optimizer | github.com/hqhq1025/skill-miner etc. | Three skills: `skill-miner` (mines session history for skill-worthy workflows), `skill-personalizer` (diagnoses undertriggering/overtriggering), `skill-generalizer` (strips private data for publishing). Ships a deterministic `scripts/scan_sessions.py`. | **Superseded** — `mine-sessions.py` now does the session mining this repo needs, against this repo's own database. Revisit `skill-personalizer` if trigger problems persist; trigger-eval already exists in `skill-creator`. |
| superpowers | github.com/obra/superpowers | Full lifecycle framework: brainstorming, git worktrees, writing-plans, subagent-driven development, TDD, `systematic-debugging`, `verification-before-completion`. Plugin injects a bootstrap every session. | **Learn from** — heavy; adopt individual ideas, not the whole harness |
| stop-slop | github.com/hardikpandya/stop-slop | Strips AI prose tells (throat-clearing, binary contrasts, em dashes) with a 1–10 rubric across five dimensions; ships three reference files. | **Install** — this repo's output is prose-heavy |
| handoff | github.com/mattpocock/skills | Compresses a session into a markdown doc for a fresh session or a different agent. | **Install** — 4.07M input tokens in one session; recorded in `skill-memory.md` |
| grill-me | github.com/mattpocock/skills | Interviews the user about a plan until shared understanding, before code is written. | **Install** — pairs with `go-architect` |
| vault-daydream | github.com/glebis/claude-skills (`daydream`) | Samples random note pairs from an Obsidian vault, dispatches generator/critic subagents, files accepted connections. | **Adapt** — this repo *is* an Obsidian vault |
| caveman | github.com/JuliusBrussee/caveman | Compresses output tokens by stripping narration while keeping facts. | Situational — adds ~1–1.5k input tokens/turn |
| understand-anything | github.com/Egonex-AI/Understand-Anything | Builds an interactive knowledge graph of a codebase. | Situational — first run is token-heavy |
| firecrawl | github.com/firecrawl/firecrawl-cli | Live web search/scrape/crawl for agents. | Installed as an MCP server, not a skill |
| composio | github.com/ComposioHQ/skills | Teaches the agent to use 1000+ SaaS integrations. | Situational |
| awesome-agent-skills | github.com/kodustech/awesome-agent-skills | A large curated index with topical sections (Testing & QA, Code Review, …). | Reference — a discovery entry point when the snapshot has nothing |

## Best-practice references

| Source | Why read it |
|--------|-------------|
| agentskills.io/skill-creation/optimizing-descriptions | The trigger-eval loop: train/validation split, trigger rate. `skill-creator` implements a version of this. |
| agentskills.io/home | The canonical folder layout, and the discovery rule that only name and description load at startup — the reason a description is the whole routing decision. |
| platform.claude.com — Agent Skills overview | Official structure and the "what + when" description rule. |
| github.com/mgechev/skills-best-practices | Structure, progressive disclosure, scripts-as-tiny-CLIs. |
| larryludlow.com/blog/ai-skills-audit | "The description is the routing mechanism" — how `commit these changes` reaches the commit skill rather than the create-pr skill. |
| firecrawl.dev/blog/best-opencode-skills | Roundup of the collections above with honest trade-offs. |

## How to use this file

1. Read the "Verdict" column against the repo's actual gaps — and against
   `references/skill-memory.md`, which records what was already considered and
   why it was adopted or refused.
2. Search for anything published after the snapshot; note the date you ran it.
3. Never install without reading the candidate's `SKILL.md` **and** every
   bundled script — see auto-skill's Traps.
