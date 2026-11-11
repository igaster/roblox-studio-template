#!/usr/bin/env python3
"""Read the headless Lead's transcript without loading it whole.

  transcript.py digest  [--since ISO] [jsonl]     one line per tool call, skill load, error, Lead text
                                                  (--since 2026-11-08T06:00: only from then on)
  transcript.py metrics [jsonl]                   per-turn and total numbers for the run record

With no jsonl, uses `leadSessionId` from TRAINING_STATE.json and finds the file under
$CLAUDE_CONFIG_DIR/projects or ~/.claude*/projects. Run with `python3 -I`.
"""
import glob, json, os, re, subprocess, sys
from datetime import datetime

# Permission refusals, as Claude Code words them ("needs approval" and "Parser skipped" seen
# in run 002 M4a; they were miscounted as errors before).
DENIAL = re.compile(r"requires approval|requires permission|needs approval|was denied|obfuscation|"
                    r"Parser aborted|Parser skipped|denied by your permission settings|"
                    r"can't be checked before it runs", re.I)
LIMIT = re.compile(r"hit your .{0,20}limit", re.I)


def find_transcript():
    root = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True).stdout.strip()
    state = json.load(open(os.path.join(root, "TRAINING_STATE.json")))
    sid = state.get("leadSessionId") or sys.exit("transcript.py: no leadSessionId in TRAINING_STATE.json")
    project = root.replace("/", "-")
    bases = [os.environ["CLAUDE_CONFIG_DIR"]] if os.environ.get("CLAUDE_CONFIG_DIR") else glob.glob(os.path.expanduser("~/.claude*"))
    for base in bases:
        path = os.path.join(base, "projects", project, sid + ".jsonl")
        if os.path.exists(path):
            return path
    sys.exit(f"transcript.py: {sid}.jsonl not found under {bases}")


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


def events(path):
    """Yields (time, kind, detail): prompt, tool, skill, agent, error, denial, text, limit."""
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


def digest(path, since=None):
    for ts, kind, detail in events(path):
        if since and ts < since:
            continue
        width = 200 if kind in ("text", "prompt") else 150
        print(ts[11:19], kind.upper(), short(detail, width))


def parse(ts):
    return datetime.fromisoformat(ts.replace("Z", "+00:00"))


def metrics(path):
    turns, cur = [], None
    for ts, kind, detail in events(path):
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
    path = rest[0] if rest else find_transcript()
    digest(path, since) if cmd == "digest" else metrics(path)


if __name__ == "__main__":
    main(sys.argv[1:])
