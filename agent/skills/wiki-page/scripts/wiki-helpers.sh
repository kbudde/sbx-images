#!/usr/bin/env bash
#
# wiki-helpers.sh — deterministic helpers for the OKF wiki skills.
#
# These own the mechanical parts of a wiki operation so no skill has to
# re-derive them: timestamp bumping, index bookkeeping, frontmatter and link
# conformance, citation-marker consistency, prose wrapping, and repo-wide
# reference sweeps. Read the page, decide the content — let the script hold
# the rules.
#
# Conventions this file encodes, all of them observed rather than prescribed:
#   - Link targets are percent-encoded (spaces become %20), the form every
#     committed index entry uses.
#   - index.md and log.md are reserved at every level and exempt from page
#     frontmatter (AGENT.md); every other page needs non-empty type and title
#     (SPEC.md §11).
#   - The root index is sectioned (## Sources / Entities / Concepts /
#     Synthesis); a directory index is a flat list.

set -euo pipefail

WIKI_HELPERS_VERSION="2.0"

# --- helpers ----------------------------------------------------------------

urlencode_path() {
    # Obsidian writes spaces in link targets as %20. Emit that form so a new
    # entry matches the file it joins.
    printf '%s' "$1" | sed 's/ /%20/g'
}

section_heading() {
    case "$1" in
        sources)   printf 'Sources' ;;
        entities)  printf 'Entities' ;;
        concepts)  printf 'Concepts' ;;
        synthesis) printf 'Synthesis' ;;
        *)         printf '' ;;
    esac
}

now_iso() {
    date -u +%Y-%m-%dT%H:%M:%SZ
}

# --- bump -------------------------------------------------------------------

bump_timestamp() {
    local new_ts errors=0
    new_ts=$(now_iso)

    for file in "$@"; do
        if [ ! -f "$file" ]; then
            echo "ERROR: No such file: $file"
            errors=$((errors + 1))
            continue
        fi

        if grep -q "^timestamp:" "$file"; then
            sed -i "s/^timestamp:.*/timestamp: $new_ts/" "$file"
        else
            # No timestamp yet: insert it after the closing delimiter of the
            # frontmatter block. An awk pass is unambiguous about which `---`
            # is the second one; sed would append after both.
            if [ "$(grep -c '^---[[:space:]]*$' "$file")" -lt 2 ]; then
                echo "ERROR: $file has no frontmatter block to add a timestamp to"
                errors=$((errors + 1))
                continue
            fi
            awk -v ts="$new_ts" '
                /^---[[:space:]]*$/ { n++; if (n == 2) { print; print "timestamp: " ts; next } }
                { print }
            ' "$file" > "$file.tmp"
            mv "$file.tmp" "$file"
        fi
        echo "Bumped timestamp in $file → $new_ts"
    done
    return "$errors"
}

# --- index ------------------------------------------------------------------

update_index() {
    local bundle="$1" dir="$2" name="$3" desc="$4"
    local entry decoded encoded heading index_file

    if [ -z "$desc" ]; then
        echo "ERROR: description is required — the index entry is the page's frontmatter description verbatim"
        return 1
    fi

    decoded="/$dir/$name.md"
    encoded="/$(urlencode_path "$dir/$name").md"
    entry="- [$name]($encoded) — $desc"
    heading=$(section_heading "$dir")

    # Root index when dir is one of the four taxonomy sections; otherwise the
    # directory's own index.
    if [ -n "$heading" ] && [ -f "$bundle/index.md" ]; then
        index_file="$bundle/index.md"
    else
        index_file="$bundle/$dir/index.md"
    fi

    if [ ! -f "$index_file" ]; then
        printf '# %s\n\nIndex for %s pages.\n\n' "${dir^}" "$dir" > "$index_file"
        echo "Created $index_file"
    fi

    # Dedupe against both spellings: an older entry may hold a literal space.
    if grep -Fq "$encoded" "$index_file" || grep -Fq "$decoded" "$index_file"; then
        echo "$name is already listed in $index_file"
        return 0
    fi

    if [ -n "$heading" ] && grep -q "^## $heading$" "$index_file"; then
        # Insert after the section's last non-blank line, so the entry lands
        # with its peers and one blank line still separates it from the next
        # heading. Printing straight before the next `## ` would leave the
        # section's trailing blank line stranded above the new entry.
        awk -v heading="$heading" -v entry="$entry" '
            function flush(   i, last) {
                last = n - 1
                while (last >= 0 && buf[last] ~ /^[[:space:]]*$/) last--
                for (i = 0; i < n; i++) {
                    print buf[i]
                    if (insection && i == last) print entry
                }
                if (insection && n == 0) { print ""; print entry }
                n = 0
            }
            BEGIN { n = 0; insection = 0 }
            # flush() must run first, with the outgoing section flag, so an entry
            # lands in the section it belongs to. Then print this heading — `next`
            # discards the matched line, so omitting the print here deleted every
            # `## ` heading from the index while still reporting success. Only then
            # set the flag for the section being entered.
            /^## / { flush(); print; insection = ($0 == "## " heading); next }
            { buf[n++] = $0 }
            END { flush() }
        ' "$index_file" > "$index_file.tmp"
        mv "$index_file.tmp" "$index_file"
        echo "Added $name to the $heading section of $index_file"
    else
        printf '%s\n' "$entry" >> "$index_file"
        if [ -n "$heading" ] && [ "$(basename "$index_file")" = "index.md" ] && [ "$index_file" = "$bundle/index.md" ]; then
            echo "WARN: $index_file has no '## $heading' section; appended at the end — check its placement"
        else
            echo "Added $name to $index_file"
        fi
    fi
}

# --- log --------------------------------------------------------------------

append_log() {
    local bundle="$1" action="$2" message="$3"
    local log_file today
    log_file="$bundle/log.md"
    today=$(date -u +%Y-%m-%d)

    if [ ! -f "$log_file" ]; then
        printf '# Wiki Log\n\n' > "$log_file"
    fi

    if ! grep -q "^## $today" "$log_file"; then
        # Newest-first: a new day's heading goes above everything. The bullet is
        # `-`, matching every established entry — a `*` here mixed two marker
        # styles into one list, which is what AGENT.md's log rules forbid.
        sed -i "1a\\
## $today\\
\\
- **$action**: $message\\
" "$log_file"
    else
        sed -i "/^## $today/a\\
- **$action**: $message\\
" "$log_file"
    fi
    echo "Logged to $log_file: $action"
}

# --- conformance ------------------------------------------------------------

validate_frontmatter() {
    local file="$1" quiet="${2:-}" base errors=0
    base=$(basename "$file")

    # Reserved filenames carry no page frontmatter (AGENT.md).
    case "$base" in
        index.md|log.md)
            if [ -z "$quiet" ]; then
                echo "SKIP: $file — reserved filename, exempt from page frontmatter"
            fi
            return 0
            ;;
    esac

    if [ ! -f "$file" ]; then
        echo "ERROR: No such file: $file"
        return 1
    fi

    # Non-empty, not merely present: `type:` with no value is what
    # bundles/main/example.md carries, and SPEC.md §11 requires a value.
    if ! grep -qE '^type:[[:space:]]*[^[:space:]]' "$file"; then
        echo "ERROR: Missing or empty 'type' in $file"
        errors=$((errors + 1))
    fi

    if ! grep -qE '^title:[[:space:]]*[^[:space:]]' "$file"; then
        echo "ERROR: Missing or empty 'title' in $file"
        errors=$((errors + 1))
    fi

    if grep -qE '^type:[[:space:]]*source-summary' "$file"; then
        if ! grep -qE '^source:[[:space:]]*[^[:space:]]' "$file"; then
            echo "ERROR: source-summary missing a non-empty 'source' in $file"
            errors=$((errors + 1))
        fi
    fi

    if [ "$errors" -eq 0 ]; then
        if [ -z "$quiet" ]; then
            echo "OK: $file"
        fi
    fi
    return "$errors"
}

check_links() {
    local file="$1" quiet="${2:-}" parent bundle_dir base

    # A directory means "every page under here". This used to be a silent false
    # pass: `grep -oP ... "$dir"` fails with "Is a directory", the `|| true`
    # swallowed it, the loop then read nothing, broken stayed 0, and the verb
    # printed "OK: All links resolve" having checked nothing. Bundle-wide link
    # checking is the common request, so it is supported rather than rejected.
    if [ -d "$file" ]; then
        local rc=0 f n=0
        while IFS= read -r f; do
            n=$((n + 1))
            check_links "$f" quiet || rc=1
        done < <(find "$file" -name '*.md' \
                    -not -path '*/raw/*' \
                    -not -path '*/templates/*' \
                    -not -path '*/.obsidian/*' | sort)
        if [ "$n" -eq 0 ]; then
            echo "WARN: no markdown pages found under $file"
            return 0
        fi
        [ "$rc" -eq 0 ] && echo "OK: all links in $n page(s) under $file resolve"
        return "$rc"
    fi

    if [ ! -f "$file" ]; then
        echo "SKIP: $file does not exist"
        return 0
    fi

    parent=$(dirname "$file")
    base=$(basename "$file")

    # A page inside the bundle sits two levels down (bundles/<b>/entities/X.md),
    # so its links are bundle-root absolute. The two reserved files at the bundle
    # root are only one level down, and taking dirname twice for them would
    # resolve every link against bundles/ instead. A sibling log.md marks the
    # bundle root.
    case "$base" in
        index.md|log.md)
            if [ -f "$parent/log.md" ]; then
                bundle_dir="$parent"
            else
                bundle_dir=$(dirname "$parent")
            fi
            ;;
        *) bundle_dir=$(dirname "$parent") ;;
    esac

    local broken=0 link decoded target

    # IFS= matters: an unquoted `read` splits on whitespace, so a link target
    # containing a literal space arrived truncated (`/concepts/Clean` for
    # `/concepts/Clean architecture.md`) and was reported broken every time.
    # Process substitution, not a pipe: a `while read` on the right of a pipe
    # runs in a subshell, so `broken` would never escape and this would always
    # report OK.
    while IFS= read -r link; do
        [ -n "$link" ] || continue
        # Links encode spaces as %20 (Obsidian's form); decode before stat.
        decoded=$(printf '%s' "$link" | sed 's/%20/ /g')
        target="$bundle_dir$decoded"
        if [ ! -f "$target" ]; then
            echo "BROKEN: $link in $file"
            broken=$((broken + 1))
        fi
    done < <(grep -oP '\]\(\K/[^)]+' "$file" || true)

    if [ "$broken" -eq 0 ] && [ -z "$quiet" ]; then
        echo "OK: All links in $file resolve"
    fi
    return "$broken"
}

check_citations() {
    local file="$1" quiet="${2:-}" errors=0
    local defined used_body report

    if [ ! -f "$file" ]; then
        echo "ERROR: No such file: $file"
        return 1
    fi

    # A citation index is 1..99: a bare number in brackets, no leading zero.
    # Without the cap, [2020] (a year in prose) and [401] (an HTTP status in a
    # quote) are read as citation markers and reported as undefined.
    #
    # A citation is defined by sitting at the start of a line, and a citation
    # is used anywhere else — so the two are read from disjoint sets of lines.
    # Set arithmetic on "all markers" cannot work here: a marker that is both
    # used and defined would cancel itself out. Reading it this way also works
    # whether the section is headed "# Citations" or "# References".
    #
    # sort -u, not sort -un: comm needs both sides in the *same* order, and
    # numeric order ([2] before [10]) is not the order comm compares in.
    #
    # The marker is extracted from the anchored match, never from a bare digit
    # run: a definition line is a sentence full of numbers, and scanning it for
    # [1-9][0-9]? finds years and commit hashes as citations. `|| true` because
    # a page with no citation markers at all is the normal case, and under
    # pipefail a non-matching grep would otherwise abort the script.
    defined=$(grep -oE '^\[[1-9][0-9]?\]' "$file" | tr -d '[]' | sort -u || true)
    used_body=$(grep -vE '^[[:space:]]*\[[1-9][0-9]?\]' "$file" \
        | grep -oE '\[[1-9][0-9]?\]' | tr -d '[]' | sort -u || true)

    if [ -z "$defined" ] && [ -z "$used_body" ]; then
        if [ -z "$quiet" ]; then
            echo "SKIP: $file — no [n] citation markers (a # References link list is not a citation index)"
        fi
        return 0
    fi

    report=$(comm -23 <(printf '%s\n' "$used_body") <(printf '%s\n' "$defined"))
    if [ -n "$report" ]; then
        while IFS= read -r n; do
            [ -n "$n" ] || continue
            echo "ERROR: [$n] used in $file but never defined"
            errors=$((errors + 1))
        done <<< "$report"
    fi

    report=$(comm -13 <(printf '%s\n' "$used_body") <(printf '%s\n' "$defined"))
    if [ -n "$report" ]; then
        while IFS= read -r n; do
            [ -n "$n" ] || continue
            echo "WARN: [$n] defined in $file but never cited"
        done <<< "$report"
    fi

    if [ "$errors" -eq 0 ]; then
        if [ -z "$quiet" ]; then
            echo "OK: citation markers in $file are consistent"
        fi
    fi
    return "$errors"
}

check_wrap() {
    local file="$1" limit="${2:-80}" quiet="${3:-}" errors=0
    local long nonlatin

    if [ ! -f "$file" ]; then
        echo "ERROR: No such file: $file"
        return 1
    fi

    # Prose only. Tables, link lists, citation definitions, fenced code and
    # URL-bearing lines are allowed to run long by convention (AGENTS.md), so
    # they are excluded rather than re-wrapped. Note the link-list exemption:
    # every page in this wiki links to a Title Case filename, so such a line is
    # long by nature — and wrapping it is not merely ugly, it splits the link
    # target and breaks the link.
    #
    # awk classifies, bash measures. mawk's length() counts bytes, so a German
    # line with ten umlauts reads as ten columns over budget; `wc -m` counts
    # characters and is right. Measuring the candidate lines rather than the
    # whole file keeps the loop short.
    local classified measured lineno
    classified=$(LC_ALL=C.UTF-8 awk '
        NR == 1 && /^---[[:space:]]*$/ { infm = 1; next }
        infm && /^---[[:space:]]*$/ { infm = 0; next }
        infm { next }                                # frontmatter: descriptions
                                                  # are long by convention and
                                                  # are copied into the indexes
        /^```/            { infence = !infence; next }
        infence           { next }
        /^\|/             { next }        # table row
        /^\[[0-9]+\]/     { next }        # citation definition
        /\]\(/            { next }        # link list entry
        /https?:\/\//    { next }        # bare URL
                        { print NR }
    ' "$file")

    long=""
    while IFS= read -r lineno; do
        [ -n "$lineno" ] || continue
        # tr drops the newline sed adds, so wc counts the line and not the
        # line plus its terminator. Deleting 0x0A bytes is safe under UTF-8:
        # no multibyte sequence contains one.
        measured=$(sed -n "${lineno}p" "$file" | tr -d '\n' | LC_ALL=C.UTF-8 wc -m)
        measured=${measured// /}
        if [ "$measured" -gt "$limit" ]; then
            long="$long$lineno: $measured chars"$'\n'
        fi
    done <<< "$classified"

    long=${long%$'\n'}
    if [ -n "$long" ]; then
        while IFS= read -r line; do
            [ -n "$line" ] || continue
            echo "WRAP: $file:$line"
            errors=$((errors + 1))
        done <<< "$long"
    fi

    # Characters outside the ranges these documents actually use: ASCII, Latin
    # supplement and Latin Extended-A, general punctuation, currency, arrows and
    # math, dingbats and emoji (the gesundheit tables use ✅/❌ deliberately),
    # box drawing (the ASCII diagrams), and CJK punctuation. Anything else — a
    # CJK ideograph in an English page or a German README — is nearly always a
    # typo, and it is invisible in a diff.
    #
    # (*UTF) is required: without it PCRE matches bytes, and every byte of a
    # three-byte ideograph lands inside the allowed Latin ranges.
    nonlatin=$(grep -nP '(*UTF)[^\x00-\x7F\x{A0}-\x{FF}\x{100}-\x{17F}\x{2000}-\x{206F}\x{20A0}-\x{20BF}\x{2190}-\x{2BFF}\x{FE0F}\x{1F300}-\x{1FAFF}\x{3000}-\x{303F}]' "$file" || true)
    if [ -n "$nonlatin" ]; then
        while IFS= read -r line; do
            [ -n "$line" ] || continue
            echo "GLYPH: $file:$line — character outside this repo's text ranges"
            errors=$((errors + 1))
        done <<< "$nonlatin"
    fi

    if [ "$errors" -eq 0 ]; then
        if [ -z "$quiet" ]; then
            echo "OK: $file wraps at ~${limit} columns and uses no unexpected glyphs"
        fi
    fi
    return "$errors"
}

# --- sweep ------------------------------------------------------------------

# One call for the three checks every wiki skill runs before committing, over a
# whole bundle or one page. This exists because the same
# `for f in ...; do validate; citations; links; done` loop was retyped three
# times in one session and again in the next, over growing file lists.
#
# It must actually check, and must actually fail. A verb that prints "OK"
# having verified nothing is worse than no verb: `links <bundle>` once did
# exactly that (it passed a directory to a grep, the error was swallowed, and
# it reported success), and the improvisation it provoked was recorded as an
# agent discipline problem rather than as this script's bug.
#
# `wrap` is opt-in. It is a real check, but the committed bundles carry
# pre-existing one-or-two-column overruns (37 of 60 pages in bundles/tech), so
# including it by default would make the verb permanently red and therefore
# ignored — the same failure as a verb that never fails.
sweep_path() {
    local target="$1" with_wrap="${2:-}"
    local -a files=()
    local f out rc pages=0 findings=0 clean=0

    if [ -z "$target" ]; then
        echo "ERROR: usage: sweep <bundle|path> [--wrap]"
        return 1
    fi

    if [ ! -e "$target" ]; then
        echo "ERROR: no such path: $target"
        return 1
    fi

    if [ -d "$target" ]; then
        while IFS= read -r f; do
            [ -n "$f" ] || continue
            files+=("$f")
        done < <(find "$target" -name '*.md' \
                    -not -path '*/raw/*' \
                    -not -path '*/templates/*' \
                    -not -path '*/.obsidian/*' | sort)
    else
        files=("$target")
    fi

    if [ "${#files[@]}" -eq 0 ]; then
        echo "WARN: no markdown pages found under $target"
        return 0
    fi

    for f in "${files[@]}"; do
        pages=$((pages + 1))
        rc=0
        out="$(validate_frontmatter "$f" quiet)" || rc=$?
        if [ "$rc" -ne 0 ]; then printf '%s\n' "$out"; findings=$((findings + rc)); fi

        rc=0
        out="$(check_citations "$f" quiet)" || rc=$?
        if [ "$rc" -ne 0 ]; then printf '%s\n' "$out"; findings=$((findings + rc)); fi

        rc=0
        out="$(check_links "$f" quiet)" || rc=$?
        if [ "$rc" -ne 0 ]; then printf '%s\n' "$out"; findings=$((findings + rc)); fi

        if [ -n "$with_wrap" ]; then
            rc=0
            out="$(check_wrap "$f" 80 quiet)" || rc=$?
            if [ "$rc" -ne 0 ]; then printf '%s\n' "$out"; findings=$((findings + rc)); fi
        fi
    done

    echo "---"
    if [ "$findings" -eq 0 ]; then
        echo "sweep: $pages page(s), no findings"
        return 0
    fi
    echo "sweep: $pages page(s), $findings finding(s)"
    return 1
}

# --- repository sweeps ------------------------------------------------------

# Report-only on purpose. A mass rewrite is the agent's edit to make, staged
# and reviewed path by path; a script that rewrites 40 files in one call is the
# thing this repo's commit discipline exists to prevent.
sweep_refs() {
    local needle="$1" hits total=0 file count

    if [ -z "$needle" ]; then
        echo "ERROR: usage: refs <needle>   (report every mention, grouped by file)"
        return 1
    fi

    while IFS= read -r file; do
        [ -n "$file" ] || continue
        count=$(grep -cF -- "$needle" "$file" || true)
        if [ "$count" -gt 0 ]; then
            printf '%-70s %s\n' "$file" "$count"
            grep -nF -- "$needle" "$file" | sed 's/^/    /'
            total=$((total + count))
        fi
    done < <(find . -type f \( -name '*.md' -o -name '*.sh' -o -name '*.yaml' -o -name '*.yml' \) \
        -not -path './.git/*' -not -path './.opencode/node_modules/*' -not -path './out/*' | sort)

    echo "---"
    echo "$total mention(s) of '$needle'"
}

# --- dispatch ---------------------------------------------------------------

usage() {
    cat <<EOF
Wiki Helpers v$WIKI_HELPERS_VERSION

  bump <file>...                       Bump timestamps on one or more pages
  index <bundle> <dir> <name> <desc>   Add a page to an index; %20-encoded,
                                       inserted into the right root section
  log <bundle> <action> <message>      Prepend a dated entry to log.md
  validate <file>                      Non-empty type + title; source for
                                       source-summary; reserved files skipped
  links <file>                         Every bundle-root absolute link resolves
  citations <file>                     [n] markers used are defined, and used
  wrap <file> [limit]                  Prose within the column limit; no
                                       unexpected glyphs
  refs <needle>                        Repo-wide mention sweep, grouped by file
  sweep <bundle|path> [--wrap]         validate + citations + links over every
                                       page in one call; --wrap adds the
                                       column and glyph check

Report-only verbs (links, citations, wrap, refs, sweep) exit non-zero on
findings.
EOF
}

case "${1:-}" in
    bump)       shift; bump_timestamp "$@" ;;
    index)      update_index "$2" "$3" "$4" "$5" ;;
    log)        append_log "$2" "$3" "$4" ;;
    validate)   validate_frontmatter "$2" ;;
    links)      check_links "$2" ;;
    citations)  check_citations "$2" ;;
    wrap)       check_wrap "$2" "${3:-80}" ;;
    refs)       sweep_refs "$2" ;;
    sweep)      sweep_path "$2" "${3:-}" ;;
    version)    printf '%s\n' "$WIKI_HELPERS_VERSION" ;;
    *)          usage; exit 1 ;;
esac
