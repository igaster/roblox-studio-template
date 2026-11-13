#!/usr/bin/env python3
"""Read the headless Lead's transcript without loading it whole.

  transcript.py digest  [--since ISO] [jsonl]     one line per tool call, skill load, error, Lead text
                                                  (--since 2026-11-08T06:00: only from then on)
  transcript.py metrics [--since ISO] [jsonl]     per-turn and total numbers for the run record

With no jsonl, reads every Lead conversation of the session, oldest first: the session ids in
the live log (.training/live/<game>.jsonl), the retired ones and `leadSessionId` from
TRAINING_STATE.json. `lead.py fresh` splits a milestone across many conversations, and an
account switch puts them in different config dirs, so each is looked up under
$CLAUDE_CONFIG_DIR/projects or every ~/.claude*/projects. Each conversation's subagents
(`<session>/subagents/*.jsonl`) are merged in by time as SUB-* events: their denials and
errors count in the metrics, their tool calls don't. Use --since for one milestone.
Run with `python3 -I`.
"""
import glob, json, os, re, subprocess, sys
from datetime import datetime

# Permission refusals, as Claude Code words them ("needs approval" and "Parser skipped" seen
# in run 002 M4a; they were miscounted as errors before).
DENIAL = re.compile(r"requires approval|requires permission|needs approval|was denied|obfuscation|"
                    r"Parser aborted|Parser skipped|denied by your permission settings|"
                    r"can't be checked before it runs|^Brace expansion", re.I)
LIMIT = re.compile(r"hit your .{0,20}limit", re.I)


def session_ids(root, state):
    """Every Lead conversation of the session, in the order it first appears."""
    ids = []
    live = os.path.join(root, ".training", "live", f"{state.get('game') or 'unknown'}.jsonl")
    if os.path.exists(live):
        for e in entries(live):
            sid = (e.get("event") or {}).get("session_id")
            if sid and sid not in ids:
                ids.append(sid)
    for sid in [r.get("id") for r in state.get("retiredLeadSessions", [])] + [state.get("leadSessionId")]:
        if sid and sid not in ids:
            ids.append(sid)
    return ids


def find_transcripts():
    """[(path, is_subagent)] for every Lead conversation and its subagents."""
    root = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True).stdout.strip()
    state = json.load(open(os.path.join(root, "TRAINING_STATE.json")))
    ids = session_ids(root, state) or sys.exit("transcript.py: no Lead session in TRAINING_STATE.json")
    # Every config dir (an account switch splits a milestone across them, and $CLAUDE_CONFIG_DIR
    # names only the current one) and every project folder (a Lead in games/<name> is a
    # different project from the framework root). Session ids are unique, so this is safe.
    bases = sorted(set(([os.environ["CLAUDE_CONFIG_DIR"]] if os.environ.get("CLAUDE_CONFIG_DIR") else [])
                       + glob.glob(os.path.expanduser("~/.claude*"))))
    files = []
    for sid in ids:
        found = [p for b in bases for p in glob.glob(os.path.join(b, "projects", "*", sid + ".jsonl"))]
        if not found:
            print(f"transcript.py: {sid}.jsonl not found under {bases}; skipped", file=sys.stderr)
            continue
        files.append((found[0], False))
        subs = glob.glob(os.path.join(found[0][:-len(".jsonl")], "subagents", "*.jsonl"))
        files += [(p, True) for p in sorted(subs)]
    return files or sys.exit("transcript.py: no Lead transcript found")


def all_events(files):
    """events() of every file, merged by time (stable: same-time events keep file order)."""
    merged = []
    for path, sub in files:
        last = ""
        for ts, kind, detail in events(path, sub):
            last = ts or last
            merged.append((last, kind, detail))
    merged.sort(key=lambda ev: ev[0])
    return merged


def entries(path):
    for line in open(path):
        try:
            yield json.loads(line)
        except ValueError:
            continue


def text_of(body):
    if isinstance(body, list):
        return " ".join(x.get("text", "") for x in body if isinstance(x, dict))
    return str(body or "")


def events(path, sub=False):
    """Yields (time, kind, detail): prompt, tool, skill, agent, error, denial, text, limit.
    For a subagent's file (sub): only its calls, errors and denials, as sub-<kind>."""
    for ts, kind, detail in lead_events(path):
        if not sub:
            yield ts, kind, detail
        elif kind not in ("prompt", "text", "limit"):
            yield ts, "sub-" + kind, detail


def lead_events(path):
    seen = set()  # a subagent's file repeats each tool call and result; keep the first
    for e in entries(path):
        ts, content = e.get("timestamp") or "", (e.get("message") or {}).get("content")
        if e.get("type") == "user" and isinstance(content, str):
            yield ts, "prompt", content
            continue
        if not isinstance(content, list):
            continue
        for c in content:
            if not isinstance(c, dict):
                continue
            kind = c.get("type")
            key = c.get("id") or c.get("tool_use_id")
            if kind in ("tool_use", "tool_result") and key:
                if (kind, key) in seen:
                    continue
                seen.add((kind, key))
            if e.get("type") == "assistant" and kind == "tool_use":
                name, inp = c["name"], c.get("input", {})
                if name == "Skill":
                    yield ts, "skill", str(inp.get("skill"))
                elif name == "Agent":
                    yield ts, "agent", f"{inp.get('subagent_type')} {inp.get('description', '')}"
                else:
                    yield ts, "tool", f"{name} {describe(name, inp)}"
            elif e.get("type") == "user" and kind == "tool_result" and c.get("is_error"):
                body = text_of(c.get("content"))
                yield ts, "denial" if DENIAL.search(body) else "error", body
            elif e.get("type") == "assistant" and kind == "text":
                yield ts, "limit" if LIMIT.search(c.get("text", "")) else "text", c.get("text", "")


def describe(name, inp):
    if name == "Bash":
        return inp.get("command", "")
    if name in ("Read", "Write", "Edit"):
        return inp.get("file_path", "")
    if "execute_luau" in name:
        return f"[{inp.get('datamodel_type')}] {inp.get('code', '')}"
    return json.dumps(inp)


def short(s, n):
    return s.replace("\n", " ")[:n]


def digest(files, since=None):
    for ts, kind, detail in all_events(files):
        if since and ts < since:
            continue
        width = 200 if kind in ("text", "prompt") else 150
        print(ts[11:19], kind.upper(), short(detail, width))


def parse(ts):
    return datetime.fromisoformat(ts.replace("Z", "+00:00"))


def metrics(files, since=None):
    turns, cur = [], None
    for ts, kind, detail in all_events(files):
        if since and ts < since:
            continue
        if kind.startswith("sub-"):
            kind = kind[4:] if kind in ("sub-denial", "sub-error") else "sub-tool"
        if kind == "prompt":
            cur = {"start": ts, "end": ts, "prompt": short(detail, 50), "tools": 0, "denials": 0,
                   "errors": 0, "skills": [], "agents": 0, "studio": 0, "limit": False}
            turns.append(cur)
            continue
        if cur is None:
            continue
        cur["end"] = ts or cur["end"]
        if kind == "tool":
            cur["tools"] += 1
            cur["studio"] += detail.startswith("mcp__Roblox_Studio")
        elif kind in ("denial", "error"):
            cur[kind + "s"] += 1
        elif kind == "skill":
            cur["skills"].append(f"{detail}@{ts[11:16]}")
        elif kind == "agent":
            cur["agents"] += 1
        elif kind == "limit":
            cur["limit"] = True
    print("| Turn | Start (UTC) | Minutes | Tools | Studio | Denials | Errors | Subagents | Skills loaded | Note |")
    print("|---|---|---|---|---|---|---|---|---|---|")
    total = {"min": 0.0, "tools": 0, "studio": 0, "denials": 0, "errors": 0, "agents": 0}
    for i, t in enumerate(turns, 1):
        minutes = (parse(t["end"]) - parse(t["start"])).total_seconds() / 60
        for k, v in (("min", minutes), ("tools", t["tools"]), ("studio", t["studio"]), ("denials", t["denials"]),
                     ("errors", t["errors"]), ("agents", t["agents"])):
            total[k] += v
        note = "USAGE LIMIT" if t["limit"] else ""
        print(f"| {i} | {t['start'][11:16]} | {minutes:.0f} | {t['tools']} | {t['studio']} | {t['denials']} | "
              f"{t['errors']} | {t['agents']} | {', '.join(t['skills']) or '-'} | {note} |")
    print(f"| **total** | | {total['min']:.0f} | {total['tools']} | {total['studio']} | {total['denials']} | "
          f"{total['errors']} | {total['agents']} | | |")


def main(argv):
    if not argv or argv[0] not in ("digest", "metrics"):
        sys.exit(__doc__)
    cmd, rest = argv[0], argv[1:]
    since = None
    if rest[:1] == ["--since"]:
        since, rest = rest[1], rest[2:]
    files = [(rest[0], False)] if rest else find_transcripts()
    digest(files, since) if cmd == "digest" else metrics(files, since)


if __name__ == "__main__":
    main(sys.argv[1:])
