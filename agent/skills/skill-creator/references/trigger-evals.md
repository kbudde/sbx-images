# Trigger evals

A skill that reads well but never loads is a dead file. The description is the
entire triggering surface, so it deserves a measurement, not a vibe check. This
is the procedure `skill-creator` Step 5 runs. It follows the Agent Skills guide
on optimizing descriptions (agentskills.io/skill-creation/optimizing-descriptions).

## 1. Write eval queries

Aim for ~20, split roughly evenly:

```json
[
  { "query": "I've got ~/data/q4.xlsx, add a profit margin column", "should_trigger": true },
  { "query": "whats the quickest way to convert json to yaml", "should_trigger": false }
]
```

- **Should-trigger**: vary phrasing (formal/casual, typos), explicitness (name
  the domain vs. describe the need), detail, and complexity. The best cases are
  ones where the skill helps but the query does not say so outright.
- **Should-not-trigger**: use **near-misses** that share keywords but need a
  different skill. "Write a fibonacci function" tests nothing.

## 2. Split train / validation

- **Train (~60%)** guides the edits.
- **Validation (~40%)** is set aside and only checks whether an edit
  generalizes. Keep the split fixed across iterations.

Do not optimize against the validation set, or you overfit the phrasing.

## 3. Run

```bash
bash .opencode/skills/skill-creator/scripts/trigger-eval.sh train_queries.json my-skill
bash .opencode/skills/skill-creator/scripts/trigger-eval.sh validation_queries.json my-skill
```

The script runs each query 3× and reports a **trigger rate** per query. A
should-trigger query passes above 0.5; a should-not-trigger query passes below.
Model behavior is nondeterministic, so one run is not evidence.

First, confirm the skill is even discovered:

```bash
opencode debug skill   # the skill must appear in this list
```

If detection looks wrong, dump a raw run (`TRIGGER_EVAL_DUMP=...` with 1 run)
and read the output, then tune `detect_triggered()` in the script. The event
schema is version-dependent; the default matcher is a heuristic.

## 4. Iterate

1. Evaluate on train; use only train failures to guide changes.
2. Revise:
   - Should-trigger missed → description too narrow; broaden scope or add
     "even if they don't mention X".
   - Should-not-trigger fired → too broad; add an explicit boundary
     ("Not for …").
   - Do **not** add the failed queries' literal keywords — address the general
     category they represent.
3. Re-run both sets; select the iteration with the best **validation** pass
   rate, which may not be the last one.

Five iterations is usually enough. If nothing improves, the queries are the
problem — too easy, too hard, or mislabeled.

## 5. Apply

1. Update the `description` in the SKILL.md frontmatter.
2. Keep it under the 1024-character limit — descriptions grow during
   optimization.
3. Sanity-check with 5–10 fresh queries that were never part of the loop.
