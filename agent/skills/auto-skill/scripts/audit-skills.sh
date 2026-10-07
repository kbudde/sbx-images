#!/usr/bin/env bash
#
# audit-skills.sh — inventory a skills directory and flag script/overlap
# candidates. Read-only; prints a Markdown report to stdout.
#
# Usage: audit-skills.sh [skills-dir] [agents-dir]
#        Default skills-dir: .opencode/skills
#        Default agents-dir: .opencode/agents
#
# This is the deterministic half of the auto-skill procedure. The model still
# decides what to do with the findings — this only gathers them.
#
# Tests: ./scripts/test/test-audit-skills.sh   (or ./scripts/test/run-all.sh -k audit)
#         Run this script against known-bad fixtures before blaming an agent for
#         ignoring it. A verb that reports success while checking nothing is
#         worse than a missing verb: it provokes improvisation, and the
#         improvisation then gets recorded as a discipline problem.

set -euo pipefail

SKILLS_DIR="${1:-.opencode/skills}"
AGENTS_DIR="${2:-.opencode/agents}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STOPWORDS_FILE="$SCRIPT_DIR/../references/stopwords.txt"
HISTORY_DIR="$SCRIPT_DIR/../history"

if [ ! -d "$SKILLS_DIR" ]; then
    echo "ERROR: Skills directory not found: $SKILLS_DIR" >&2
    exit 1
fi

echo "# AutoSkill Inventory — $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# --- inventory -------------------------------------------------------------
echo "## Current Skills"
echo ""
echo "| Skill | Lines | Scripts | References | Frontmatter |"
echo "|-------|-------|---------|------------|-------------|"

for skill_md in "$SKILLS_DIR"/*/SKILL.md; do
    [ -f "$skill_md" ] || continue

    skill_name=$(basename "$(dirname "$skill_md")")
    lines=$(wc -l < "$skill_md" | tr -d ' ')

    has_scripts="no"
    [ -d "$(dirname "$skill_md")/scripts" ] && has_scripts="yes"

    has_refs="no"
    [ -d "$(dirname "$skill_md")/references" ] && has_refs="yes"

    has_name="no"
    has_desc="no"
    grep -q "^name:" "$skill_md" && has_name="yes"
    grep -q "^description:" "$skill_md" && has_desc="yes"

    fm_status="OK"
    [ "$has_name" = "no" ] && fm_status="MISSING name"
    [ "$has_desc" = "no" ] && fm_status="MISSING description"

    echo "| $skill_name | $lines | $has_scripts | $has_refs | $fm_status |"
done

# --- script replacement candidates ----------------------------------------
echo ""
echo "## Script Replacement Candidates"
echo ""
echo "Skills with a numbered step that is mechanical work — something a script"
echo "could own. The step text is printed so the finding can be judged rather"
echo "than counted: the earlier heuristic matched any mention of the words"
echo "'validate' or 'check' anywhere in a body, which flagged all eight skills"
echo "including ones that merely describe a concept."
echo ""

for skill_md in "$SKILLS_DIR"/*/SKILL.md; do
    [ -f "$skill_md" ] || continue
    skill_name=$(basename "$(dirname "$skill_md")")

    # An imperative step: a numbered list item opening with a doing-word.
    hits=$(grep -inE '^[[:space:]]*[0-9]+\.[[:space:]]*\*{0,2}(Validate|Check|Verify|Scaffold|Create|Generate|Regenerate|Update|Bump|Append|Insert|Run|Collect|Gather|Sweep|Search|Read the index)' "$skill_md" || true)
    [ -n "$hits" ] || continue

    if [ -d "$(dirname "$skill_md")/scripts" ]; then
        echo "- **$skill_name** — has scripts/; these steps may belong there:"
    else
        echo "- **$skill_name** — no scripts/ yet:"
    fi
    printf '%s\n' "$hits" | sed 's/^/    /'
done

echo ""
echo "A skill that produces a *design* legitimately has nothing to script"
echo "(go-architect). Read the step before proposing a script for it."

# --- trigger overlap -------------------------------------------------------
# Significant word = lowercased, alphanumeric (hyphens kept), length > 4,
# not in references/stopwords.txt.

filter_words() {
    tr ' ' '\n' \
        | tr '[:upper:]' '[:lower:]' \
        | sed 's/[^a-z0-9-]//g' \
        | awk 'length > 4' \
        | sort -u \
        | { if [ -f "$STOPWORDS_FILE" ]; then grep -vwF -f "$STOPWORDS_FILE" || true; else cat; fi; }
}

echo ""
echo "## Trigger Overlap Check"
echo ""
echo "Pairs sharing more than three significant description words, with the words"
echo "named. Two corrections to the earlier version of this check: the threshold"
echo "was low enough to report 17 of 21 pairs, and words appearing in three or"
echo "more descriptions are corpus vocabulary rather than evidence of a conflict"
echo "— 'description' and 'references' say nothing about two skills overlapping."
echo "A high count is still a hint to sharpen a boundary, not proof of one."
echo ""

names=()
wordlists=()

# Words used by three or more descriptions carry no routing signal.
corpus_tmp=$(mktemp)
CORPUS=$(mktemp)
trap 'rm -f "$corpus_tmp" "$CORPUS"' EXIT

for skill_md in "$SKILLS_DIR"/*/SKILL.md; do
    [ -f "$skill_md" ] || continue
    desc=$(grep -m1 "^description:" "$skill_md" | sed 's/^description: *//')
    printf '%s\n' "$desc" | filter_words >> "$corpus_tmp"
done
sort "$corpus_tmp" | uniq -c | awk '$1 >= 3 { print $2 }' > "$CORPUS"

for skill_md in "$SKILLS_DIR"/*/SKILL.md; do
    [ -f "$skill_md" ] || continue
    names+=("$(basename "$(dirname "$skill_md")")")
    wordlists+=("$(grep -m1 "^description:" "$skill_md" | sed 's/^description: *//' | filter_words | grep -vwF -f "$CORPUS" || true)")
done

for i in "${!names[@]}"; do
    for j in "${!names[@]}"; do
        [ "$i" -ge "$j" ] && continue
        shared=$(comm -12 <(printf '%s\n' "${wordlists[$i]}") <(printf '%s\n' "${wordlists[$j]}") || true)
        common=$(printf '%s\n' "$shared" | grep -c . || true)
        if [ "$common" -gt 3 ]; then
            echo "- **${names[$i]}** and **${names[$j]}** share $common: $(printf '%s' "$shared" | tr '\n' ' ')"
        fi
    done
done

echo ""
echo "## Subagent Convention Coverage"
echo ""
echo "Subagents load their own definition, not the parent skill, so a trap"
echo "written into a SKILL.md never reaches them. This section is the check"
echo "that the conventions a skill owns were propagated to the agents that do"
echo "the same job."
echo ""
echo "| Agent | Lines | Denies shell | Names wiki-helpers | Has history |"
echo "|-------|-------|---------------|--------------------|-------------|"

if [ ! -d "$AGENTS_DIR" ]; then
    echo ""
    echo "No agents directory at $AGENTS_DIR — nothing to check."
else
    for agent_md in "$AGENTS_DIR"/*.md; do
        [ -f "$agent_md" ] || continue
        agent_name=$(basename "$agent_md" .md)
        lines=$(wc -l < "$agent_md" | tr -d ' ')

        # "Denies shell" means the agent declares a broad shell deny and never
        # re-allows it — that combination forces hand-rolled tooling.
        denies_shell="no"
        if grep -A2 'action: shell' "$agent_md" | grep -q 'effect: deny'; then
            allows_helper="no"
            grep -q 'wiki-helpers.sh' "$agent_md" && allows_helper="yes"
            if [ "$allows_helper" = "no" ]; then
                denies_shell="yes (no re-allow)"
            else
                denies_shell="yes (re-allowed)"
            fi
        fi

        names_helper="no"
        grep -q 'wiki-helpers.sh' "$agent_md" && names_helper="yes"

        has_history="no"
        [ -f "$HISTORY_DIR/$agent_name.md" ] && has_history="yes"

        echo "| $agent_name | $lines | $denies_shell | $names_helper | $has_history |"
    done

    echo ""
    echo "Two of those columns are the finding. **Denies shell (no re-allow)**"
    echo "means the agent cannot run the script its skill wrote, so it will"
    echo "reimplement the check — and ripgrep has no look-around, so the"
    echo "reimplementation fails on link patterns. **Has history = no** means"
    echo "this repo has never recorded anything about how the agent behaves,"
    echo "which is why nothing noticed either time."
fi

echo ""
echo "## Usage"
echo ""
echo "How often each skill was loaded, from the session database. A load is not"
echo "proof of use — read it as a routing signal, and a skill with a high count"
echo "and no history entries is a description that over-promises."
echo ""
if [ -x "$SCRIPT_DIR/mine-sessions.py" ] || [ -f "$SCRIPT_DIR/mine-sessions.py" ]; then
    python3 "$SCRIPT_DIR/mine-sessions.py" counter 2>/dev/null || echo "(miner unavailable)"
else
    echo "(mine-sessions.py not present)"
fi
