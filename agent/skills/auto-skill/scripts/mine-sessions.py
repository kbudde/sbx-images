#!/usr/bin/env python3
"""mine-sessions.py — turn recorded opencode sessions into skill evidence.

Reads the session database and prints what an agent actually did, which is the
only evidence a skill's quality can be judged against. Everything here is
deterministic: this script counts and groups, and the model reads the result
and decides what it means.

    counter      how often each skill was loaded, and where its work went
    errors       failures grouped by tool and message, with the failing input
    retries      the same call repeated, and repeats that follow a failure
    sessions     per-session rollup: messages, tool calls, failures, tokens
    latency      slowest tools by summed wall time
    corrections  user messages that look like corrections, for the model to judge
    hotspots     files edited, by patch count
    report       all of the above as Markdown, for the analysis step

Design notes, each of them a decision rather than an accident:

  * Read-only, always. The database is opened `mode=ro`. If a stale WAL
    sidecar blocks that (SQLite cannot rebuild the -shm index without write
    access), the db/-wal/-shm trio is copied to a temp directory and the copy
    is read. The original is never opened for writing and never modified.

  * Two schemas. Observed versions fill `message` + `part`, with the newer
    `session_message` + `session_input` tables present but empty. The newer
    path is implemented defensively and is UNTESTED against real rows — when
    `session_message` is non-empty this script prefers it, and says so in its
    output so a reader does not mistake it for verified behaviour.

  * Never reads credentials. The `account` and `credential` tables hold
    tokens. This script allowlists the four tables it touches and has no code
    path that selects from any other.

  * Report-only. Nothing here writes to the repository. Recording what a
    session taught is the model's job, with the user's approval.

Usage:
    mine-sessions.py <command> [options]

    --db PATH        session database (default ~/.local/share/opencode/opencode.db)
    --session ID     restrict to one session
    --since ISO      restrict to sessions created at or after this instant
    --unmined        restrict to sessions not yet named in auto-skill/history/
    --limit N        cap rows per section (default 20, 0 for no cap)
    --json           machine-readable output
"""

from __future__ import annotations

import argparse
import collections
import datetime as dt
import json
import os
import re
import shutil
import sqlite3
import sys
import tempfile

DEFAULT_DB = os.path.expanduser("~/.local/share/opencode/opencode.db")
HISTORY_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "history")

# The only tables this script reads. `account` and `credential` hold tokens.
# `session_v2` is v2's rename of v1's `session`; `session_table()` resolves it.
ALLOWED_TABLES = {"session", "session_v2", "message", "part", "session_message", "session_input"}

# A user message that looks like a correction. These are candidates for the
# model to read, never verdicts: "no" opens a legitimate follow-up question as
# often as it reopens a decision.
CORRECTION_MARKERS = (
    "no,", "no.", "not what i", "that's not", "thats not", "wrong",
    "don't", "do not", "stop", "instead", "revert", "undo", "i said",
    "not what you", "you got it wrong", "incorrect", "misread",
    "actually,", "i meant", "never mind", "nevermind", "why did you",
)

# A user turn that merely *pastes* something. In a debugging session this is
# the dominant interaction, and it is why marker matching alone is not enough:
# a pasted transcript contains "stop", "no," and "do not" as ordinary output.
# Measured on ses_ef29ef3e…, six of six marker candidates were pastes, and the
# one real correction — "btw. did you check open github issues?" — matched no
# marker at all.
PASTE_PROMPT_RE = re.compile(r"^\s*(?:[\w.-]+@[\w.-]+[:~][^\s]*|[$#>])\s", re.M)
PASTE_TUI_RE = re.compile(r"[│◇┃┌└├]")
PASTE_LOG_RE = re.compile(r"^\s*\d{1,2}:\d{2}:\d{2}\s+\S", re.M)

# Below this many characters a turn is too short to be a transcript, so the
# paste heuristics are skipped rather than misfiring on a one-line reply.
PASTE_MIN_LEN = 120

# An assistant turn that asserts a cause. A user turn arriving right after one
# is a correction *candidate* even with no marker, because the thing being
# corrected is the assertion rather than anything the user said earlier.
ROOT_CAUSE_MARKERS = (
    "the cause is", "root cause", "this is caused by", "caused by the",
    "the problem is", "the issue is", "the fix is", "it fails because",
    "that's why", "this is why", "confirmed:", "my hypothesis",
    "i think the", "i think this", "most likely",
)

# A user turn that *starts a new task* rather than responding to the diagnosis.
# "update the docs" and "do 1 and 2" follow a cause assertion like any other
# turn, but they are not corrections, and leaving them in made the after-cause
# list 12 of 17 turns — the same unusability as the paste noise it replaced.
# Only checked on a short turn, so a long message that happens to open with a
# verb is not discarded.
INSTRUCTION_OPENERS = (
    "update", "add ", "create", "write", "make ", "do ", "do noth",
    "fix the", "move ", "remove ", "delete", "generate", "install",
    "implement", "rename", "revert the",
)
INSTRUCTION_MAX_LEN = 200

# A turn that only nudges for progress: "go on", "status?", "done?". These
# follow a cause assertion like any other turn, but they correct nothing. They
# are counted rather than listed, because the count is a finding in its own
# right: four "status?" turns in one session is the agent going quiet, which is
# the failure mode §1a of debug-research exists to prevent.
CONTINUATION_RE = re.compile(
    r"^\s*(?:go on|continue|proceed|next|keep going|carry on|status\??|done\??|"
    r"are you done\??|finished\??|ok(?:ay)?|yes|no|what'?s the status\??|"
    r"any progress\??|still (?:going|working)\??)\s*[.!?]*\s*$",
    re.I,
)

SKILL_DIR_RE = re.compile(r"^\.opencode/skills/([a-z0-9-]+)/")


def looks_like_paste(text: str) -> bool:
    """True when a user turn reads as pasted command output.

    Deliberately conservative: a false positive here *hides* a real correction,
    which is worse than leaving a paste in the list. Every signal below is
    something prose does not contain — a shell prompt, a terminal-UI glyph, a
    timestamped log line, or a structured dump.
    """
    if len(text) < PASTE_MIN_LEN:
        return False
    if PASTE_PROMPT_RE.search(text) or PASTE_TUI_RE.search(text) or PASTE_LOG_RE.search(text):
        return True
    lines = [ln for ln in text.splitlines() if ln.strip()]
    if len(lines) >= 4:
        # An indented or bracket-heavy dump (JSON, config, a diff). Prose
        # starts its lines at column zero.
        structured = sum(
            1 for ln in lines
            if ln[:1] in " \t" or ln.lstrip()[:1] in "{}[]\"'"
        )
        if structured / len(lines) >= 0.6:
            return True
    return False


def asserts_a_cause(text: str) -> bool:
    low = text.lower()
    return any(m in low for m in ROOT_CAUSE_MARKERS)


def starts_a_new_task(text: str) -> bool:
    """True when a turn opens a new instruction rather than answering a cause."""
    stripped = text.strip()
    if stripped.startswith("@"):
        return True
    if len(stripped) > INSTRUCTION_MAX_LEN:
        return False
    return stripped.lower().startswith(INSTRUCTION_OPENERS)


def nudges_for_progress(text: str) -> bool:
    return bool(CONTINUATION_RE.match(text))


# --- database ---------------------------------------------------------------

def table_exists(con: sqlite3.Connection, table: str) -> bool:
    return con.execute(
        "select 1 from sqlite_master where type='table' and name=?", (table,)
    ).fetchone() is not None


def session_table(con: sqlite3.Connection) -> str:
    """Name of the session table. v2 renamed v1's `session` to `session_v2`.

    The columns this script reads are unchanged between the two, so only the
    name has to move. Raises LookupError naming what it did find, so an
    unrecognized schema reports itself instead of raising "no such table".
    """
    for t in ("session_v2", "session"):
        if table_exists(con, t):
            return t
    have = {r[0] for r in con.execute("select name from sqlite_master where type='table'")}
    raise LookupError(
        "no session table found — expected `session_v2` (v2) or `session` (v1). "
        f"Tables present: {', '.join(sorted(have)) or '(none)'}"
    )


def column_names(con: sqlite3.Connection, table: str) -> set:
    return {r[1] for r in con.execute(f"pragma table_info({table})")}


def open_db(path: str) -> tuple[sqlite3.Connection, bool]:
    """Open read-only. Returns (connection, used_temp_copy)."""
    if not os.path.exists(path):
        sys.exit(f"ERROR: no session database at {path}")

    def probe(con: sqlite3.Connection) -> None:
        con.execute(f"select count(*) from {session_table(con)}").fetchone()

    try:
        con = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
        probe(con)
        return con, False
    except LookupError as e:
        # Opened fine, schema unrecognised — a copy of the file cannot help.
        sys.exit(f"ERROR: {e}")
    except sqlite3.Error:
        pass

    # A stale -shm cannot be rebuilt without write access, so read a copy.
    tmpdir = tempfile.mkdtemp(prefix="mine-sessions-")
    for suffix in ("", "-wal", "-shm"):
        src = path + suffix
        if os.path.exists(src):
            shutil.copy2(src, os.path.join(tmpdir, "opencode.db" + suffix))
    con = sqlite3.connect(f"file:{os.path.join(tmpdir, 'opencode.db')}?mode=ro", uri=True)
    try:
        probe(con)
    except LookupError as e:
        sys.exit(f"ERROR: {e}")
    except sqlite3.Error as e:
        sys.exit(f"ERROR: could not read a session table from {path}: {e}")
    return con, True


def table_has_rows(con: sqlite3.Connection, table: str) -> bool:
    if table not in ALLOWED_TABLES:
        raise RuntimeError(f"refusing to read {table}")
    # A v1 database has no session_message, and a v2 one has no message/part.
    # Absence means "not this schema", not an error — probing with `select`
    # raised OperationalError here, which broke the v1 path entirely.
    if not table_exists(con, table):
        return False
    return con.execute(f"select 1 from {table} limit 1").fetchone() is not None


def iso(ms) -> str:
    if not ms:
        return "unknown"
    return dt.datetime.fromtimestamp(ms / 1000, dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def short(text: str, limit: int = 160) -> str:
    text = re.sub(r"\s+", " ", str(text)).strip()
    return text if len(text) <= limit else text[: limit - 1] + "…"


def as_text(raw) -> str:
    """Coerce a stored value to readable text.

    v1 stored errors and queued prompts as plain strings. v2 stores tool errors
    as `{type, message}` objects, and its inbox/pending columns hold JSON text,
    so both need unwrapping rather than `str()` — which would print a Python
    dict repr and make an error message unreadable in the report.
    """
    if raw is None:
        return ""
    if isinstance(raw, (dict, list)):
        return _unwrap(raw)
    if isinstance(raw, str):
        s = raw.strip()
        if s[:1] in "{[":
            try:
                return _unwrap(json.loads(s))
            except ValueError:
                return raw
        return raw
    return str(raw)


def _unwrap(o) -> str:
    if isinstance(o, str):
        return o
    if isinstance(o, dict):
        for key in ("message", "text", "prompt"):
            if isinstance(o.get(key), str):
                return o[key]
    return json.dumps(o, sort_keys=True)


# --- loading ----------------------------------------------------------------

def load(con: sqlite3.Connection) -> dict:
    """Normalize both schemas into one shape."""
    data = {"schema": None, "sessions": {}, "tools": [], "user_text": [],
            "patches": [], "user_skills": [], "assistant_text": [], "_ord": 0}

    stable = session_table(con)
    # v2 records which session spawned which; v1's table has no such column, so
    # ask rather than assume. It is what separates an agent-authored task prompt
    # from something a user actually said.
    has_parent = "parent_id" in column_names(con, stable)
    parent_expr = "parent_id" if has_parent else "null"

    for sid, title, directory, agent, created, parent in con.execute(
        f"select id, title, directory, agent, time_created, {parent_expr} from {stable}"
    ):
        data["sessions"][sid] = {
            "id": sid, "title": title, "directory": directory,
            "agent": agent, "created": created, "created_iso": iso(created),
            "parent": parent,
            "tokens_in": 0, "tokens_out": 0, "cost": 0.0,
        }

    for sid, tin, tout, cost in con.execute(
        f"select id, tokens_input, tokens_output, cost from {stable}"
    ):
        if sid in data["sessions"]:
            data["sessions"][sid].update(tokens_in=tin or 0, tokens_out=tout or 0, cost=cost or 0.0)

    if table_has_rows(con, "session_message"):
        data["schema"] = "session_message (newer; defensive path)"
    else:
        data["schema"] = "message + part (observed)"

    if data["schema"].startswith("session_message"):
        load_new(con, data)
    else:
        load_observed(con, data)

    return data


def load_observed(con: sqlite3.Connection, data: dict) -> None:
    roles = {}
    for mid, sid, raw in con.execute("select id, session_id, data from message"):
        try:
            roles[mid] = json.loads(raw).get("role", "?")
        except (ValueError, TypeError):
            roles[mid] = "?"

    for sid, mid, raw, created in con.execute(
        "select session_id, message_id, data, time_created from part order by time_created"
    ):
        try:
            o = json.loads(raw)
        except (ValueError, TypeError):
            continue
        kind = o.get("type")

        if kind == "tool":
            state = o.get("state") or {}
            start = (state.get("time") or {}).get("start")
            end = (state.get("time") or {}).get("end")
            data["tools"].append({
                "session": sid, "tool": o.get("tool", "?"),
                "status": state.get("status", "?"),
                "error": state.get("error", ""),
                "input": state.get("input") or {},
                "start": start, "end": end,
                "duration_ms": (end - start) if (start and end) else None,
                "at": iso(created), "role": roles.get(mid, "?"),
            })
        elif kind == "text" and roles.get(mid) == "user":
            data["_ord"] += 1
            data["user_text"].append({"session": sid, "text": o.get("text", ""),
                                      "at": iso(created), "ord": data["_ord"]})
        elif kind == "text" and roles.get(mid) == "assistant":
            data["_ord"] += 1
            data["assistant_text"].append({"session": sid, "text": o.get("text", ""),
                                           "at": iso(created), "ord": data["_ord"]})
        elif kind == "patch":
            for path in (o.get("files") or []):
                data["patches"].append({"session": sid, "file": path})


def load_new(con: sqlite3.Connection, data: dict) -> None:
    """Defensive path for the newer schema. Its rows were empty in the observed
    version, so this is written against the documented shape rather than a
    sample: message rows carry role, and parts arrive either inline under
    `parts` or as separate rows keyed by message_id."""
    for sid, mtype, raw, created in con.execute(
        "select session_id, type, data, time_created from session_message order by seq"
    ):
        try:
            o = json.loads(raw)
        except (ValueError, TypeError):
            continue
        # v2 keeps the role in the `type` COLUMN, not in the JSON payload — a
        # user message's JSON has keys time/text/files/agents/skills and no
        # `type` at all. Reading the role from the JSON made every message look
        # role "?", which silently skipped user text and skill mentions.
        role = o.get("role") or mtype or o.get("type") or "?"

        # v2 replaced v1's inline `parts` array with `content`, moved the tool
        # name from `tool` to `name`, lifted timing out of `state` into a
        # top-level `time`, and turned `state.error` into an object. Reading
        # v1's shape here yields zero tool calls with no error raised, so each
        # of these is a separate lookup rather than a fallback chain.
        for p in (o.get("content") or o.get("parts") or []):
            if not isinstance(p, dict):
                continue
            if p.get("type") == "text" and role == "user":
                data["_ord"] += 1
                data["user_text"].append({"session": sid, "text": p.get("text", ""),
                                          "at": iso(created), "ord": data["_ord"]})
            elif p.get("type") == "text" and role == "assistant":
                data["_ord"] += 1
                data["assistant_text"].append({"session": sid, "text": p.get("text", ""),
                                               "at": iso(created), "ord": data["_ord"]})
            elif p.get("type") == "tool":
                state = p.get("state") or {}
                t = p.get("time") or state.get("time") or {}
                start = t.get("created") or t.get("start")
                end = t.get("completed") or t.get("end")
                data["tools"].append({
                    "session": sid, "tool": p.get("name") or p.get("tool") or "?",
                    "status": state.get("status", "?"), "error": as_text(state.get("error", "")),
                    "input": state.get("input") or {},
                    "start": start, "end": end,
                    "duration_ms": (end - start) if (start and end) else None,
                    "at": iso(created), "role": role,
                })
                # Edit hotspots depend on this; load_new must record patches or
                # the section reads as "no files were touched".
                name = p.get("name") or p.get("tool")
                if name in ("edit", "write", "patch"):
                    path = (state.get("input") or {}).get("path")
                    if path:
                        data["patches"].append({"session": sid, "file": path})

        # v2 keeps a user message's text at the top level, not in a part.
        if role == "user" and o.get("text"):
            data["_ord"] += 1
            data["user_text"].append({"session": sid, "text": o["text"],
                                      "at": iso(created), "ord": data["_ord"]})
        if role == "assistant" and o.get("text"):
            data["_ord"] += 1
            data["assistant_text"].append({"session": sid, "text": o["text"],
                                           "at": iso(created), "ord": data["_ord"]})

        # A skill invoked by `@mention` in a user message never becomes a
        # `skill` tool call, so counting tool calls alone misses how a skill is
        # actually invoked. That made auto-skill blind to its own `@auto-skill`
        # mentions, which is the primary way it gets used.
        if role == "user":
            for s in (o.get("skills") or []):
                data["user_skills"].append(
                    {"session": sid, "id": (s or {}).get("id") or "?", "at": iso(created)}
                )

    # Queued/injected prompts. v1 kept these in `session_input` as plain
    # `prompt` text; v2 dropped that table and split the same concept across
    # `session_inbox` (`payload`) and `session_pending` (`data`), both JSON.
    # Read whichever exist rather than assuming one.
    for table, col in (("session_input", "prompt"), ("session_inbox", "payload"), ("session_pending", "data")):
        if not table_exists(con, table):
            continue
        for sid, prompt, created in con.execute(
            f"select session_id, {col}, time_created from {table} order by time_created"
        ):
            data["_ord"] += 1
            data["user_text"].append(
                {"session": sid, "text": as_text(prompt), "at": iso(created),
                 "delivery": True, "ord": data["_ord"]}
            )


def filter_sessions(data: dict, args) -> None:
    keep = set(data["sessions"])
    if args.session:
        keep &= {args.session}
    if args.since:
        cutoff = parse_iso(args.since)
        keep &= {s for s in keep if (data["sessions"][s]["created"] or 0) >= cutoff}
    if args.unmined:
        mined = mined_session_ids()
        keep -= mined

    data["sessions"] = {s: v for s, v in data["sessions"].items() if s in keep}
    # Every per-session bucket must be listed here. A bucket left out is not
    # merely unfiltered: `--session` would then mix other sessions' turns into
    # the output while reporting the filtered count. `assistant_text` and
    # `user_skills` were both missing.
    for bucket in ("tools", "user_text", "patches", "assistant_text", "user_skills"):
        data[bucket] = [e for e in data[bucket] if e["session"] in keep]


def parse_iso(value: str) -> int:
    value = value.replace("Z", "+00:00")
    try:
        return int(dt.datetime.fromisoformat(value).timestamp() * 1000)
    except ValueError:
        sys.exit(f"ERROR: --since wants an ISO 8601 instant, got {value!r}")


def mined_session_ids() -> set:
    """Sessions already recorded in a history file. The history is the ledger, so
    there is no separate state file to keep in step with it."""
    seen = set()
    if not os.path.isdir(HISTORY_DIR):
        return seen
    for name in os.listdir(HISTORY_DIR):
        if not name.endswith(".md"):
            continue
        try:
            with open(os.path.join(HISTORY_DIR, name), encoding="utf-8") as fh:
                seen.update(re.findall(r"\bses_[A-Za-z0-9]+", fh.read()))
        except OSError:
            continue
    return seen


# --- analyses ---------------------------------------------------------------

def analyse(data: dict) -> dict:
    out = {}

    # Skill counter. A load is not proof of use, so each skill also gets the
    # tool calls that followed it in the same session — labelled a heuristic,
    # because the session store records no explicit skill scope.
    loads = collections.Counter()
    load_sessions = collections.defaultdict(set)
    load_at = {}
    per_session_last = {}
    attributed = collections.Counter()
    mentioned = collections.Counter()

    for t in sorted(data["tools"], key=lambda x: x["start"] or 0):
        if t["tool"] == "skill":
            # v1 sent the skill id as `name`; v2 sends it as `id`.
            name = (t["input"] or {}).get("name") or (t["input"] or {}).get("id") or "?"
            loads[name] += 1
            load_sessions[name].add(t["session"])
            load_at.setdefault(name, t["at"])
            per_session_last[t["session"]] = name
        elif t["session"] in per_session_last:
            attributed[per_session_last[t["session"]]] += 1

    # `@mention` invocations, which never produce a `skill` tool call. Counted
    # as loads so a skill invoked the obvious way is not invisible to the
    # counter. `mentioned` records how many came from `@` rather than the tool.
    for s in data.get("user_skills", []):
        loads[s["id"]] += 1
        load_sessions[s["id"]].add(s["session"])
        load_at.setdefault(s["id"], s["at"])
        mentioned[s["id"]] += 1

    out["skills"] = sorted(
        ({"name": n, "loads": c, "sessions": sorted(load_sessions[n]),
          "last": load_at.get(n, "unknown"), "mentioned": mentioned.get(n, 0)}
         for n, c in loads.items()),
        key=lambda r: (-r["loads"], r["name"]),
    )
    out["attributed"] = attributed.most_common()
    out["attributed_total"] = sum(attributed.values())

    failures = [t for t in data["tools"] if t["status"] == "error"]
    groups = collections.defaultdict(list)
    for t in failures:
        groups[(t["tool"], short(t["error"], 120))].append(t)
    out["errors"] = sorted(
        ({"tool": k[0], "error": k[1], "count": len(v),
          "sessions": sorted({x["session"] for x in v}),
          "sample_input": short(json.dumps(v[0]["input"], ensure_ascii=False)),
          "first": min(x["at"] for x in v), "last": max(x["at"] for x in v)}
         for k, v in groups.items()),
        key=lambda r: (-r["count"], r["tool"]),
    )
    out["error_total"] = len(failures)

    # Retries: the identical call twice, and the same command prefix three
    # times — the second is what a re-run after a partial failure looks like.
    canon = collections.defaultdict(list)
    for t in data["tools"]:
        try:
            key = (t["tool"], json.dumps(t["input"], sort_keys=True, ensure_ascii=False))
        except (TypeError, ValueError):
            key = (t["tool"], short(str(t["input"]), 200))
        canon[key].append(t)
    out["repeats"] = sorted(
        ({"tool": k[0], "count": len(v), "sessions": sorted({x["session"] for x in v}),
          "input": short(k[1]), "statuses": sorted({x["status"] for x in v})}
         for k, v in canon.items() if len(v) > 1),
        key=lambda r: (-r["count"], r["tool"]),
    )

    prefix = collections.defaultdict(list)
    for t in data["tools"]:
        if not isinstance(t["input"], dict):
            continue
        for key, value in t["input"].items():
            if isinstance(value, str) and len(value) > 20:
                prefix[(t["tool"], key, value[:100])].append(t)
                break
    out["near_repeats"] = sorted(
        ({"tool": k[0], "field": k[1], "count": len(v),
          "sessions": sorted({x["session"] for x in v}), "prefix": short(k[2], 100)}
         for k, v in prefix.items() if len(v) >= 3),
        key=lambda r: -r["count"],
    )

    rollup = []
    for sid, s in data["sessions"].items():
        calls = [t for t in data["tools"] if t["session"] == sid]
        rollup.append({
            "session": sid, "title": s["title"], "agent": s["agent"],
            "created": s["created_iso"], "tools": len(calls),
            "errors": sum(1 for t in calls if t["status"] == "error"),
            "tokens_in": s["tokens_in"], "tokens_out": s["tokens_out"], "cost": s["cost"],
        })
    out["sessions"] = sorted(rollup, key=lambda r: r["created"], reverse=True)

    dur = collections.defaultdict(lambda: [0, 0])
    for t in data["tools"]:
        if t["duration_ms"]:
            dur[t["tool"]][0] += t["duration_ms"]
            dur[t["tool"]][1] += 1
    out["latency"] = sorted(
        ({"tool": k, "total_ms": v[0], "calls": v[1], "mean_ms": v[0] // v[1] if v[1] else 0}
         for k, v in dur.items()),
        key=lambda r: -r["total_ms"],
    )

    # A subagent session's user-role message is the parent agent's task prompt,
    # not something a user said. It matches a correction marker constantly —
    # "Do not edit files", "stop", "don't" — because that is how instructions
    # are phrased. Measured on this repository: 8 of the 12 marker matches were
    # subagent prompts, leaving 2 usable candidates. The signal was two-thirds
    # noise, and noise here crowds out the real thing.
    child_sessions = {s for s, v in data["sessions"].items() if v.get("parent")}

    # One ordered stream per session, so a user turn can be matched against the
    # assertion it is answering. Timestamps are not enough: two turns can share
    # a millisecond (observed: seq 560 and 561), and iso() drops sub-second
    # precision. `ord` is assigned during load, in the order the loader read the
    # rows, which is seq order in v2 and time_created order in v1.
    #
    # The earlier version of this kept only the *last* cause per session and
    # compared every user turn against it, so an early correction was measured
    # against a cause asserted much later and was silently dropped.
    stream = []
    for e in data["assistant_text"]:
        stream.append((e["session"], e["ord"], "assistant", e))
    for e in data["user_text"]:
        stream.append((e["session"], e["ord"], "user", e))
    stream.sort(key=lambda t: (t[0], t[1]))

    corrections = []
    after_cause = []
    paste_excluded = 0
    task_excluded = 0
    nudge_excluded = 0
    cause_seen = {}
    for sid, _ord, role, e in stream:
        if sid in child_sessions:
            continue
        if role == "assistant":
            if asserts_a_cause(e["text"]):
                cause_seen[sid] = True
            continue
        if looks_like_paste(e["text"]):
            # Counted only when it would otherwise have been a candidate; a
            # pasted transcript that matches nothing was never noise.
            if any(m in e["text"].lower() for m in CORRECTION_MARKERS):
                paste_excluded += 1
            continue
        low = e["text"].lower()
        fired = [m for m in CORRECTION_MARKERS if m in low]
        row = {"session": sid, "at": e["at"], "text": short(e["text"], 300),
               "markers": fired[:4]}
        if fired:
            corrections.append(row)
        elif cause_seen.get(sid):
            # No marker, but it follows an assertion of a cause and is not a
            # paste. This is the shape the highest-value correction took:
            # "btw. did you check open github issues?"
            if starts_a_new_task(e["text"]):
                task_excluded += 1
                continue
            if nudges_for_progress(e["text"]):
                nudge_excluded += 1
                continue
            after_cause.append(row)
    out["corrections"] = corrections
    out["corrections_after_cause"] = after_cause
    out["corrections_paste_excluded"] = paste_excluded
    out["corrections_task_excluded"] = task_excluded
    out["corrections_nudge_excluded"] = nudge_excluded
    out["corrections_skipped_subagent"] = sum(
        1 for u in data["user_text"]
        if u["session"] in child_sessions
        and any(m in u["text"].lower() for m in CORRECTION_MARKERS)
    )

    files = collections.Counter(p["file"] for p in data["patches"])
    out["hotspots"] = files.most_common()

    return out


# --- rendering --------------------------------------------------------------

def cap(rows, limit):
    return rows if not limit else rows[:limit]


def render(command: str, data: dict, res: dict, limit: int) -> str:
    L = []
    add = L.append

    if command in ("counter", "report"):
        add("## Skill counter")
        add("")
        if not res["skills"]:
            add("No skill loads recorded.")
        else:
            add("| Skill | Loads | Sessions | Last loaded | Calls after load (heuristic) |")
            add("|---|---|---|---|---|")
            attributed = dict(res["attributed"])
            for r in res["skills"]:
                add(f"| {r['name']} | {r['loads']} | {len(r['sessions'])} | {r['last']} | "
                    f"{attributed.get(r['name'], 0)} |")
        add("")

    if command in ("errors", "report"):
        add(f"## Errors ({res['error_total']} failed calls)")
        add("")
        if not res["errors"]:
            add("None.")
        else:
            add("| Count | Tool | Error | Sessions | Sample input |")
            add("|---|---|---|---|---|")
            for r in cap(res["errors"], limit):
                add(f"| {r['count']} | `{r['tool']}` | {r['error']} | {len(r['sessions'])} | `{r['sample_input']}` |")
        add("")

    if command in ("retries", "report"):
        add("## Repeated calls")
        add("")
        if not res["repeats"] and not res["near_repeats"]:
            add("None.")
        else:
            for r in cap(res["repeats"], limit):
                add(f"- **{r['count']}×** `{r['tool']}` in {len(r['sessions'])} session(s) — "
                    f"statuses {', '.join(r['statuses'])} — `{r['input']}`")
            for r in cap(res["near_repeats"], limit):
                add(f"- **{r['count']}×** `{r['tool']}` sharing the same `{r['field']}` prefix in "
                    f"{len(r['sessions'])} session(s) — `{r['prefix']}`")
        add("")

    if command in ("sessions", "report"):
        add("## Sessions")
        add("")
        add("| Session | Title | Agent | Tools | Errors | Tokens in/out |")
        add("|---|---|---|---|---|---|")
        for r in cap(res["sessions"], limit):
            add(f"| `{r['session'][:12]}…` | {short(r['title'], 48)} | {r['agent']} | "
                f"{r['tools']} | {r['errors']} | {r['tokens_in']}/{r['tokens_out']} |")
        add("")

    if command in ("latency", "report"):
        add("## Tool latency")
        add("")
        add("| Tool | Calls | Total ms | Mean ms |")
        add("|---|---|---|---|")
        for r in cap(res["latency"], limit):
            add(f"| `{r['tool']}` | {r['calls']} | {r['total_ms']} | {r['mean_ms']} |")
        add("")

    if command in ("corrections", "report"):
        add("## Correction candidates")
        add("")
        add("Candidates for the model to read, not verdicts — \"no\" opens a")
        add("follow-up as often as it reopens a decision. Pasted command output is")
        add("excluded: a transcript contains \"stop\", \"no,\" and \"do not\" as")
        add("ordinary text, and in the session that prompted this, every marker")
        add("match was a paste while the one real correction matched no marker.")
        skipped = res.get("corrections_skipped_subagent", 0)
        pastes = res.get("corrections_paste_excluded", 0)
        if skipped:
            add("")
            add(f"Excluded {skipped} marker match(es) from subagent sessions: that text")
            add("is a parent agent's task prompt, not something a user said.")
        if pastes:
            add("")
            add(f"Excluded {pastes} marker match(es) that look like pasted terminal")
            add("output or a structured dump.")
        tasks = res.get("corrections_task_excluded", 0)
        if tasks:
            add("")
            add(f"Excluded {tasks} turn(s) that open a new task rather than answer")
            add("the diagnosis.")
        nudges = res.get("corrections_nudge_excluded", 0)
        if nudges:
            add("")
            add(f"Excluded {nudges} turn(s) that only nudge for progress. The count")
            add("is itself a signal: a run of \"status?\" means the agent went quiet.")
        add("")
        add("### Marker matches")
        add("")
        if not res["corrections"]:
            add("None.")
        for r in cap(res["corrections"], limit):
            marks = ", ".join(f"`{m}`" for m in r.get("markers", []))
            add(f"- `{r['session'][:12]}…` {r['at']} — {r['text']}")
            if marks:
                add(f"  - matched: {marks}")
        add("")
        add("### After an asserted cause, no marker")
        add("")
        add("A user turn that follows an assistant turn asserting a root cause and")
        add("is not a paste. These are where a correction lands when the user is")
        add("answering the diagnosis rather than quoting it.")
        add("")
        after = res.get("corrections_after_cause", [])
        if not after:
            add("None.")
        for r in cap(after, limit):
            add(f"- `{r['session'][:12]}…` {r['at']} — {r['text']}")
        add("")

    if command in ("hotspots", "report"):
        add("## Edit hotspots")
        add("")
        if not res["hotspots"]:
            add("None.")
        for path, count in cap(res["hotspots"], limit):
            add(f"- {count:>3}× `{path}`")
        add("")

    return "\n".join(L).rstrip() + "\n"


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("command", choices=[
        "counter", "errors", "retries", "sessions", "latency",
        "corrections", "hotspots", "report",
    ])
    p.add_argument("--db", default=DEFAULT_DB)
    p.add_argument("--session")
    p.add_argument("--since")
    p.add_argument("--unmined", action="store_true",
                   help="only sessions not yet named in auto-skill/history/")
    p.add_argument("--limit", type=int, default=20, help="0 for no cap")
    p.add_argument("--json", action="store_true")
    args = p.parse_args()

    con, copied = open_db(args.db)
    try:
        data = load(con)
        filter_sessions(data, args)
        res = analyse(data)
    finally:
        con.close()
        if copied:
            shutil.rmtree(os.path.dirname(con.execute("PRAGMA database_list").fetchone()[2]), ignore_errors=True)

    if args.json:
        print(json.dumps({"schema": data["schema"], "sessions": data["sessions"], **res}, indent=2, default=str))
        return 0

    header = [f"# Mined sessions — {args.command}",
              "",
              f"Schema: {data['schema']} · sessions: {len(data['sessions'])} · "
              f"tool calls: {len(data['tools'])} · database: {args.db}"
              + (" (read from a temp copy: the live WAL blocked a read-only open)" if copied else ""),
              ""]
    print("\n".join(header) + "\n" + render(args.command, data, res, args.limit))
    return 0


if __name__ == "__main__":
    sys.exit(main())
