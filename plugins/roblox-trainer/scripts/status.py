#!/usr/bin/env python3
"""One-screen training status, computed from the tree (nothing to keep up to date by hand).

  status.py

Shows: the game in the tree, the session, whether the Lead is running and what it is doing
(from the live log lead.py writes), archived games, uncommitted framework changes, open human
checks and harvest-ready ledger cards. The free-form
handoff note, if any, is .training/STATUS.md. Run with `python3 -I`.
"""
import datetime, json, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))


def run(*args, cwd=None):
    return subprocess.run(list(args), cwd=cwd, capture_output=True, text=True).stdout


def lead_state(root):
    pid_file = os.path.join(root, ".training", "lead.pid")
    if not os.path.exists(pid_file):
        return "idle"
    try:
        pid = int(open(pid_file).read().split()[0])
        os.kill(pid, 0)
    except (ProcessLookupError, ValueError, IndexError):
        return "idle (stale lead.pid)"
    started = datetime.datetime.fromtimestamp(os.path.getmtime(pid_file)).strftime("%H:%M")
    return f"RUNNING (pid {pid}, since {started})"


def live(root, game):
    """Latest activity from .training/live/<game>.jsonl (written by lead.py as the Lead works)."""
    path = os.path.join(root, ".training", "live", f"{game}.jsonl")
    if not game or not os.path.exists(path):
        return []
    tail = open(path).readlines()[-400:]
    last_ts, last_tool, last_text, task = None, None, None, None
    for line in tail:
        try:
            row = json.loads(line)
        except ValueError:
            continue
        last_ts, ev = row.get("ts"), row.get("event", {})
        if ev.get("type") != "assistant":
            continue
        for block in ev.get("message", {}).get("content", []):
            if block.get("type") == "text" and block.get("text", "").strip():
                last_text = block["text"].strip().split("\n")[0][:100]
            elif block.get("type") == "tool_use":
                inp = block.get("input", {})
                hint = inp.get("description") or inp.get("file_path") or inp.get("command") or ""
                last_tool = f"{block.get('name')} {str(hint)[:70]}".strip()
                if block.get("name") == "TodoWrite":
                    doing = [t.get("content") for t in inp.get("todos", []) if t.get("status") == "in_progress"]
                    task = doing[0] if doing else task
    out = []
    if last_ts:
        ago = datetime.datetime.now(datetime.timezone.utc) - datetime.datetime.fromisoformat(last_ts)
        out.append(f"last event {int(ago.total_seconds() // 60)} min ago ({last_ts[11:16]} UTC)")
    if task:
        out.append(f"task: {task}")
    if last_tool:
        out.append(f"last tool: {last_tool}")
    if last_text:
        out.append(f"last said: {last_text}")
    return out


def session(root):
    path = os.path.join(root, "TRAINING_STATE.json")
    if not os.path.exists(path):
        return "none"
    s = json.load(open(path))
    parts = [f"{s.get('game')} ({s.get('status')})", f"last milestone {s.get('milestone') or '-'}",
             f"place {s.get('place') or '?'}"]
    return ", ".join(parts)


def framework_changes(root):
    paths = [p for p in run("bash", os.path.join(HERE, "commit-framework.sh"), "--list", cwd=root).split("\n") if p]
    out = run("git", "status", "--porcelain", "--", *paths, cwd=root)
    return [l for l in out.split("\n") if l]


def harvest_ready(root):
    out = run("python3", "-I", os.path.join(HERE, "learnings.py"), "ready", cwd=root)
    return [" ".join(l.split("\t")[1:]) for l in out.split("\n") if l]


def harvest_due(root):
    return run("python3", "-I", os.path.join(HERE, "learnings.py"), "due", cwd=root).strip()

def main():
    root = run("git", "rev-parse", "--show-toplevel").strip()
    state_path = os.path.join(root, "TRAINING_STATE.json")
    state = json.load(open(state_path)) if os.path.exists(state_path) else {}
    game_dir = os.path.join(root, state["gameDir"]) if state.get("gameDir") else root
    gdd = os.path.join(game_dir, "docs/design/GDD.md")
    game = (open(gdd).readline().strip("# \n").split(": Game Design Document")[0]
            if os.path.exists(gdd) else "(none: template only)")
    if state.get("gameDir"):
        game += f"  ({state['gameDir']})"
    archive = os.path.join(root, ".training", "archive")
    archived = sorted(os.listdir(archive)) if os.path.isdir(archive) else []
    games_dir = os.path.join(root, "games")
    games = sorted(g for g in os.listdir(games_dir)
                   if os.path.isdir(os.path.join(games_dir, g))) if os.path.isdir(games_dir) else []
    changes = framework_changes(root)
    checks = run("python3", "-I", os.path.join(HERE, "human_checks.py"), "--count", cwd=root).strip()
    ready = harvest_ready(root)
    due = harvest_due(root).replace("\t", " · ")
    head = run("git", "log", "--oneline", "-1", cwd=root).strip()

    print(f"Game:             {game}")
    print(f"Session:          {session(root)}")
    print(f"Lead:             {lead_state(root)}")
    for line in live(root, state.get("game")):
        print(f"  {line}")
    print(f"Games (games/):   {', '.join(games) or 'none'}")
    print(f"Archived games:   {', '.join(archived) or 'none'}")
    print(f"Framework HEAD:   {head}")
    print(f"Uncommitted framework changes: {len(changes)}")
    for c in changes:
        print(f"  {c}")
    print(f"Open human checks: {checks or '0'} (human_checks.py)")
    print(f"Harvest:          {due}")
    print(f"Harvest-ready cards: {len(ready)}")
    for r in ready[:5]:
        print(f"  {r}")
    if os.path.exists(os.path.join(root, ".training", "STATUS.md")):
        print("Handoff note:     .training/STATUS.md")


if __name__ == "__main__":
    sys.exit(main())
