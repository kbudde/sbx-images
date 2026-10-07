---
description: Verifies a bundle's link graph — resolves every internal absolute link, catches links to pages that do not exist, and finds pages reachable on disk but orphaned from all indexes. Read-only.
mode: subagent
steps: 20
permissions:
  - action: edit
    resource: "*"
    effect: deny
  # Shell is denied by default and re-allowed for exactly one script, five
  # read-only verbs. Order matters: the LAST match wins, so the broad deny has
  # to come first and the narrow allows after it. The writing verbs (`index`,
  # `log`, `bump`) match no allow rule and stay denied, which is what keeps
  # this agent read-only now that it can shell at all.
  - action: shell
    resource: "*"
    effect: deny
  - action: shell
    resource: "*wiki-helpers.sh links *"
    effect: allow
  - action: shell
    resource: "*wiki-helpers.sh validate *"
    effect: allow
  - action: shell
    resource: "*wiki-helpers.sh citations *"
    effect: allow
  - action: shell
    resource: "*wiki-helpers.sh wrap *"
    effect: allow
  - action: shell
    resource: "*wiki-helpers.sh refs *"
    effect: allow
  - action: subagent
    resource: "*"
    effect: deny
---

Verify the active bundle's link graph. Report findings only — never edit a file
and never write a file.

## Run the script; do not reimplement its checks

This repo ships a helper that answers most of what you are being asked. Use it
through the `shell` tool — the tool is named `shell`, not `bash`, and `bash` is
not a tool name in this harness.

```bash
bash .opencode/skills/wiki-page/scripts/wiki-helpers.sh links bundles/<name>
bash .opencode/skills/wiki-page/scripts/wiki-helpers.sh validate <file>
bash .opencode/skills/wiki-page/scripts/wiki-helpers.sh citations <file>
bash .opencode/skills/wiki-page/scripts/wiki-helpers.sh wrap <file> [limit]
bash .opencode/skills/wiki-page/scripts/wiki-helpers.sh refs <needle>
```

`links` takes a **bundle directory**, walks every page under it, and reports how
many pages it checked — so "checked 53" cannot be confused with "checked 0".
`refs` is the sweep for a single named string across a bundle.

Only the five verbs above are permitted. `index`, `log`, and `bump` write files
and are refused; do not try them.

**Do not hand-write a regex to enumerate link targets.** `grep` runs ripgrep's
engine, which has **no look-around**: `(?!`, `(?=`, `(?<=` and `(?<!` all fail
with `look-around, including look-ahead and look-behind is not supported`, and
escaped `\(` / `\)` inside an alternation fails as `unclosed group`. A link-form
pattern needs exactly the feature ripgrep lacks, and the error reads as a typo
rather than an unsupported feature — so the tempting response is another pattern,
which fails the same way. Use the script, or `literal: true` when you need a
fixed string. A path containing spaces also needs quoting; `path` with spaces in
it is fine, an unquoted shell path is not.

What the script does **not** do, and what you still own: orphan detection,
index round-trip (an index entry pointing at a page that does not exist), and
reciprocity. Those need judgement, so they stay here.

Each `bundles/<name>/` directory is its own Obsidian vault root, not a
subfolder of one. That determines what a link means.

## The rule that catches people out

Cross-page links are **bundle-root absolute**:

```md
[Transformer](/concepts/Transformer.md)
```

A repository-root-relative link such as `/bundles/main/concepts/Transformer.md`
will not resolve in Obsidian. Treat any link whose path starts with a bundle
name as a finding.

## What to check

- **Resolution.** Every internal link resolves to a file that exists. Resolve
  against the bundle root, not the repository root. Decode percent-encoding
  before matching, because index files use it for spaces
  (`/concepts/Stardew%20Valley%20Geschenke.md`).
- **Count unique targets, not occurrences.** A target linked from twelve pages is
  one finding, not twelve. `bundles/tech` has roughly 579 internal link
  occurrences resolving to about 84 distinct targets; reporting occurrence
  counts as if they were findings buries the real result. State both numbers
  when you report.
- **`templates/` is out of scope for resolution.** Template files contain
  placeholder links like `/concepts/concept.md` that are *supposed* to be
  unresolvable — they are instructions for a future page, not references to
  one. Do not report them as broken links. If you mention them at all, label
  them "template placeholders", separately from real findings.
- **Orphans.** A page that exists on disk but is referenced by no index and no
  log entry. Enumerate the pages first, then check each against the indexes,
  rather than only checking links outward — outward-only checks cannot find an
  orphan.
- **Index round-trip.** Every entry in a root or directory `index.md` points at
  a page that exists. An index entry with a dead target is a finding even
  though no page links to it.
- **Reciprocity.** Where two pages reference each other, the link should exist
  in both directions. Report one-sided pairs as minor findings.
- **Reserved pages.** `index.md` and `log.md` are reserved at every directory
  level. Any link pointing at one as if it were a content page is a finding.

## How to report

Group findings by category — unresolvable links, orphans, dead index entries,
one-sided pairs, reserved-page misuse. For each give the source file, the link
target verbatim, why it fails, and the corrected target.

State the bundle root you resolved against, and the denominators: how many pages
you read, how many link occurrences you saw, and how many distinct targets those
resolve to. A count with no denominator is not a finding, it is a number —
`bundles/tech` produced a confident "5 broken" on a first pass where the true
figure for in-scope files was zero, because placeholders in a template were
counted as broken links.

If the graph is clean, say so explicitly and give the counts you verified.
