#!/usr/bin/env python3
"""Drive the headless Lead for the current in-place training session.

  lead.py start <brief-file>     start the Lead with the scenario brief; stores its session id
  lead.py say <message-file>     send an owner message to the Lead (resumes its session)
  lead.py stop                   stop a Lead call that is running (e.g. before a laptop sleeps)
  lead.py resume                 after a stop: tell the Lead to check where it left off, carry on
  lead.py fresh [message-file]   retire the Lead's conversation and start a new one, told to
                                 continue from the repo (docs/STATUS.md), plus the message
  lead.py running                exit 0 and print the pids if a Lead call is running

Why `fresh`: every step of a conversation re-sends its whole history, so one kept across
milestones gets dearer per step and burns usage limits (run 002 M4k: 207 steps at 317k-505k
tokens used a 5-hour window in 21 minutes). Use it at a milestone's end, never to answer a
question the Lead just asked. The retired session ids stay in TRAINING_STATE.json.

Prints the Lead's reply. Uses permissions/lead-profile.json and the project's .mcp.json. The
Lead gets no training instructions: it only sees the brief and messages, like any owner's.
Local records, all under .training/ (gitignored; the Lead is denied reading it):
  - messages/<game>/   every brief and message sent (the owner-proxy audit reads them);
  - live/<game>.jsonl  the Lead's events, timestamped, as it works (status.py shows the latest);
  - lead.pid           marks a running call: "<lead.py pid> <claude process group>".
Run with `python3 -I`. CLAUDE_BIN overrides the claude binary (the tests use a stub).
"""
import datetime, json, os, signal, subprocess, sys

PLUGIN = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROFILE = os.path.join(PLUGIN, "permissions", "lead-profile.json")
RESUME_TEXT = ("Sorry, I had to stop you partway through. Check where you left off (the tree, "
               "tests and Studio sync) and carry on from there.\n")
FRESH_TEXT = ("We're continuing the game in this repo. You're picking it up from a new chat, so "
              "the repo is all you have: start from docs/STATUS.md.\n")


def die(msg, code=1):
    print(f"lead.py: {msg}", file=sys.stderr)
    sys.exit(code)


def now():
    return datetime.datetime.now(datetime.timezone.utc)


class Session:
    def __init__(self):
        out = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True)
        if out.returncode:
            die("not in a git repo")
        self.root = out.stdout.strip()
        self.state_path = os.path.join(self.root, "TRAINING_STATE.json")
        self.training = os.path.join(self.root, ".training")
        self.pid_path = os.path.join(self.training, "lead.pid")

    def state(self):
        if not os.path.exists(self.state_path):
            die(f"no training session ({self.state_path} missing); run session.py start first")
        return json.load(open(self.state_path))

    def save_session_id(self, sid):
        state = self.state()
        state["leadSessionId"] = sid
        json.dump(state, open(self.state_path, "w"), indent=2)

    def retire_session_id(self):
        """Records the current Lead conversation as retired. leadSessionId stays until the new
        call returns its id, so a failed fresh start (a usage limit) leaves say/resume working."""
        state = self.state()
        sid = state.get("leadSessionId")
        if sid and sid not in [r["id"] for r in state.get("retiredLeadSessions", [])]:
            state.setdefault("retiredLeadSessions", []).append(
                {"id": sid, "retired": now().isoformat(timespec="seconds")})
            json.dump(state, open(self.state_path, "w"), indent=2)
        return sid

    # ---- running mark -------------------------------------------------------
    def running(self):
        """(lead pid, claude process group or None) if a call is running, else None."""
        try:
            parts = open(self.pid_path).read().split()
            pid = int(parts[0])
            os.kill(pid, 0)
        except (OSError, ValueError, IndexError):
            return None
        return pid, (int(parts[1]) if len(parts) > 1 else None)

    def mark(self, child=None):
        os.makedirs(self.training, exist_ok=True)
        open(self.pid_path, "w").write(f"{os.getpid()}" + (f" {child}" if child else "") + "\n")

    def unmark(self):
        try:
            if int(open(self.pid_path).read().split()[0]) == os.getpid():
                os.remove(self.pid_path)
        except (OSError, ValueError, IndexError):
            pass

    # ---- records -------------------------------------------------------------
    def log_message(self, kind, text):
        folder = os.path.join(self.training, "messages", self.state().get("game") or "unknown")
        os.makedirs(folder, exist_ok=True)
        path = os.path.join(folder, f"{now():%Y%m%dT%H%M%SZ}-{os.getpid()}-{kind}.md")
        open(path, "w").write(text)
        return path

    def live_path(self):
        folder = os.path.join(self.training, "live")
        os.makedirs(folder, exist_ok=True)
        return os.path.join(folder, f"{self.state().get('game') or 'unknown'}.jsonl")


def profile():
    return json.load(open(PROFILE))


def claude_args(extra):
    p = profile()
    return ([os.environ.get("CLAUDE_BIN", "claude"), "-p", *extra,
             "--output-format", "stream-json", "--verbose",
             "--mcp-config", ".mcp.json", "--strict-mcp-config",
             "--permission-mode", p["permissionMode"],
             "--allowedTools", *p["allowedTools"], "--disallowedTools", *p["disallowedTools"]])


class Turns:
    """Follows the event stream. One call can hold several Lead turns, and only the last
    turn's "result" is the call's answer, so the final reply of every earlier turn is kept too,
    or it would be lost. A new turn shows up two ways: a reminder or task notification arriving
    as a new user prompt, or a scheduled wakeup that starts a whole new turn with its own
    `system init` and its own `result` event (run 002 M4c)."""

    def __init__(self):
        self.replies, self.last, self.result, self.results = [], None, {}, []

    def feed(self, ev):
        kind = ev.get("type")
        if kind == "assistant":
            texts = [b.get("text", "") for b in ev.get("message", {}).get("content", [])
                     if b.get("type") == "text"]
            if any(t.strip() for t in texts):
                self.last = "\n".join(texts)
        elif kind == "user":
            content = ev.get("message", {}).get("content", [])
            new_prompt = isinstance(content, str) or any(b.get("type") != "tool_result" for b in content)
            if new_prompt and self.last:
                self.replies.append(self.last)
                self.last = None
        elif kind == "result" or "result" in ev:
            self.result = ev
            self.results.append(str(ev.get("result", "")))
            self.last = None

    def earlier(self):
        """Every earlier turn's final reply, in order, without repeats or the final answer."""
        final = str(self.result.get("result", ""))
        out = []
        for text in self.replies + self.results[:-1]:
            if text.strip() and text != final and text not in out:
                out.append(text)
        return out

    def report(self):
        lines = []
        earlier = self.earlier()
        for i, text in enumerate(earlier, 1):
            lines.append(f"[earlier Lead reply {i} of {len(earlier)} in this call]\n{text}\n")
        if earlier:
            lines.append("[final Lead reply]")
        lines.append(str(self.result.get("result", "")))
        if self.result.get("permission_denials"):
            lines.append("\n[permission denials] " + json.dumps(self.result["permission_denials"]))
        return "\n".join(lines)


def call(session, kind, text, resume=None):
    """Sends text to the Lead and prints its reply. The prompt goes on stdin (a message
    starting with "-" would otherwise be read as a flag)."""
    busy = session.running()
    if busy:
        die(f"a Lead call is already running (pid {busy[0]}); wait, or lead.py stop")
    session.mark()
    try:
        prompt = session.log_message(kind, text)
        extra = ["--resume", resume] if resume else []
        turns = Turns()
        with open(prompt) as stdin, open(session.live_path(), "a", buffering=1) as live:
            proc = subprocess.Popen(claude_args(extra), cwd=session.root, stdin=stdin,
                                    stdout=subprocess.PIPE, text=True, start_new_session=True)
            session.mark(child=proc.pid)
            for line in proc.stdout:
                try:
                    ev = json.loads(line)
                except ValueError:
                    continue
                live.write(json.dumps({"ts": now().isoformat(timespec="seconds"), "event": ev}) + "\n")
                turns.feed(ev)
            code = proc.wait()
        if turns.result.get("session_id"):
            session.save_session_id(turns.result["session_id"])
        print(turns.report())
        return code
    finally:
        session.unmark()


def read_arg(argv, usage):
    if len(argv) < 3 or not os.access(argv[2], os.R_OK):
        die(f"usage: lead.py {usage}")
    return open(argv[2]).read()


def stop(session):
    busy = session.running()
    if not busy:
        print("lead.py: no Lead call is running")
        return 0
    pid, group = busy
    if group:
        try:
            os.killpg(group, signal.SIGTERM)
        except OSError:
            pass
    try:
        os.kill(pid, signal.SIGTERM)
    except OSError:
        pass
    try:
        os.remove(session.pid_path)
    except OSError:
        pass
    print(f"Stopped the Lead call (pid {pid}). Resume later with: lead.py resume")
    return 0


def main(argv):
    cmd = argv[1] if len(argv) > 1 else ""
    session = Session()
    # A stop sends SIGTERM to this process too: exit cleanly so the running mark is removed.
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(143))
    if cmd == "running":
        session.state()
        busy = session.running()
        print(f"running (pid {busy[0]})" if busy else "idle")
        return 0 if busy else 1
    if cmd == "stop":
        return stop(session)
    if cmd == "start":
        text = read_arg(argv, "start <brief-file>")
        session.state()
        return call(session, "start", text)
    if cmd == "fresh":
        extra = read_arg(argv, "fresh [message-file]") if len(argv) > 2 else ""
        busy = session.running()
        if busy:
            die(f"a Lead call is already running (pid {busy[0]}); wait, or lead.py stop")
        old = session.retire_session_id()
        print(f"Retired Lead conversation {old}; starting a fresh one." if old
              else "No Lead conversation yet; starting one.")
        return call(session, "fresh", FRESH_TEXT + ("\n" + extra if extra else ""))
    sid = session.state().get("leadSessionId")
    if cmd == "say":
        text = read_arg(argv, "say <message-file>")
        if not sid:
            die("no Lead session yet; use lead.py start")
        return call(session, "say", text, resume=sid)
    if cmd == "resume":
        if not sid:
            die("no Lead session yet; use lead.py start")
        return call(session, "say", RESUME_TEXT, resume=sid)
    die("usage: lead.py start <brief-file> | say <message-file> | fresh [message-file] | stop | "
        "resume | running")


if __name__ == "__main__":
    sys.exit(main(sys.argv))
