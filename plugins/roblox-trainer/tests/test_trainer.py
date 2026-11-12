#!/usr/bin/env python3
"""Tests for the trainer's scripts, run against throwaway git repos (cleaned up afterwards).

  python3 -I plugins/roblox-trainer/tests/test_trainer.py [-v]

The scripts are driven as subprocesses, the way the trainer runs them.
"""
import json, os, signal, stat, subprocess, sys, tempfile, textwrap, time, unittest

PLUGIN = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPTS = os.path.join(PLUGIN, "scripts")


def py(script):
    return [sys.executable, "-I", os.path.join(SCRIPTS, script)]


def run(cmd, cwd, env=None, stdin=None):
    full_env = dict(os.environ, **(env or {}))
    return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, env=full_env, input=stdin)


def slurp(path):
    with open(path) as f:
        return f.read()


def git(cwd, *args):
    return run(["git", *args], cwd).stdout.strip()


def write(root, rel, text):
    path = os.path.join(root, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(text)


def make_repo(tmp, files):
    root = tempfile.mkdtemp(dir=tmp)
    git(root, "init", "-q")
    git(root, "config", "user.email", "t@t")
    git(root, "config", "user.name", "t")
    for rel, text in files.items():
        write(root, rel, text)
    git(root, "add", "-A")
    git(root, "commit", "-q", "-m", "init")
    return root


def stub(tmp, body):
    """A fake `claude` binary: reads the prompt from stdin, then runs body (bash)."""
    path = os.path.join(tempfile.mkdtemp(dir=tmp), "claude")
    write(os.path.dirname(path), "claude", "#!/usr/bin/env bash\n" + body)
    os.chmod(path, os.stat(path).st_mode | stat.S_IEXEC)
    return path


def state(root):
    return json.loads(slurp(os.path.join(root, "TRAINING_STATE.json")))


class TempCase(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = self._tmp.name

    def tearDown(self):
        self._tmp.cleanup()


# ---- session.py --------------------------------------------------------------------------
class SessionTest(TempCase):
    def setUp(self):
        super().setUp()
        self.r = make_repo(self.tmp, {"CLAUDE.md": "# framework\n", "src/game/Foo.lua": "x\n"})

    def session(self, *args):
        return run(py("session.py") + list(args), self.r)

    def test_start_lock_continue_milestone_end(self):
        self.session("start", "alpha")
        self.assertEqual(state(self.r)["frameworkCommit"], git(self.r, "rev-parse", "HEAD"))
        self.assertEqual(state(self.r)["game"], "alpha")
        self.assertNotEqual(self.session("start", "beta").returncode, 0, "second start while locked")
        self.assertEqual(state(self.r)["game"], "alpha")
        self.session("end")
        write(self.r, "docs/design/GDD.md", "# Beta Run: Game Design Document\n")
        self.assertNotEqual(self.session("start", "gamma").returncode, 0, "another game's GDD")
        bad = self.session("start", "gamma", "--continue")
        self.assertNotEqual(bad.returncode, 0, "--continue with a title mismatch")
        self.assertIn("'beta-run'", bad.stderr, "the mismatch names the expected session (L-034)")
        self.assertEqual(self.session("start", "beta-run", "--continue").returncode, 0)
        self.assertEqual(state(self.r)["game"], "beta-run")
        self.session("milestone", "M2")
        self.assertEqual(state(self.r)["milestone"], "M2")
        self.session("end")
        self.assertEqual(state(self.r)["status"], "ended")

    def test_place(self):
        self.session("start", "alpha", "--place", "Alpha Place")
        self.assertEqual(state(self.r)["place"], "Alpha Place")


# ---- commit-framework.sh -----------------------------------------------------------------
class CommitFrameworkTest(TempCase):
    def setUp(self):
        super().setUp()
        self.r = make_repo(self.tmp, {"CLAUDE.md": "# framework\n", "src/game/Foo.lua": "x\n"})

    def commit(self, *args):
        return run(["bash", os.path.join(SCRIPTS, "commit-framework.sh"), *args], self.r)

    def last_commit_files(self):
        return git(self.r, "show", "--name-only", "--format=", "HEAD")

    def test_game_files_never_committed(self):
        write(self.r, "src/game/Foo.lua", "y\n")
        self.assertNotEqual(self.commit("msg").returncode, 0, "only a game file changed")
        self.assertEqual(git(self.r, "rev-list", "--count", "HEAD"), "1")
        write(self.r, "CLAUDE.md", "more\n")
        self.commit("framework fix")
        self.assertEqual(self.last_commit_files(), "CLAUDE.md")
        self.assertIn("src/game/Foo.lua", git(self.r, "status", "--porcelain"))
        write(self.r, "CLAUDE.md", "z\n")
        git(self.r, "add", "src/game/Foo.lua")
        self.assertNotEqual(self.commit("msg").returncode, 0, "a pre-staged game file")
        self.assertEqual(git(self.r, "rev-list", "--count", "HEAD"), "2")

    def test_untracked_files_in_framework_dirs(self):
        write(self.r, "docs/superpowers/plans/2026-11-08-m2-game-plan.md", "plan\n")
        write(self.r, "src/shared/GameMath.lua", "return {}\n")
        write(self.r, "CLAUDE.md", "fix\n")
        self.commit("fix")
        self.assertEqual(self.last_commit_files(), "CLAUDE.md")
        write(self.r, "plugins/x/new.md", "new\n")
        self.commit("add new", "plugins/x/new.md")
        self.assertEqual(self.last_commit_files(), "plugins/x/new.md")
        self.assertNotEqual(self.commit("bad", "src/game/Foo.lua").returncode, 0)
        self.assertIn("src/game/ServerScriptService/FrameworkSmokeTest.lua", self.commit("--list").stdout.split("\n"))


# ---- lead.py -----------------------------------------------------------------------------
class LeadTest(TempCase):
    def setUp(self):
        super().setUp()
        self.r = make_repo(self.tmp, {"CLAUDE.md": "# framework\n"})
        run(py("session.py") + ["start", "alpha"], self.r)

    def lead(self, *args, claude=None):
        return run(py("lead.py") + list(args), self.r, env={"CLAUDE_BIN": claude} if claude else None)

    def message(self, text, name="msg.txt"):
        write(self.tmp, name, text)
        return os.path.join(self.tmp, name)

    def test_start_say_and_session_id(self):
        result = stub(self.tmp, 'cat >/dev/null\necho \'{"type":"result","session_id":"stub-123","result":"ok"}\'\n')
        self.assertNotEqual(self.lead("say", self.message("hi")).returncode, 0, "say without a session")
        self.lead("start", self.message("brief"), claude=result)
        self.assertEqual(state(self.r)["leadSessionId"], "stub-123")
        self.assertEqual(self.lead("say", self.message("next"), claude=result).returncode, 0)

    def test_fresh_retires_the_conversation_and_starts_from_the_repo(self):
        first = stub(self.tmp, 'cat >/dev/null\necho \'{"type":"result","session_id":"old-1","result":"ok"}\'\n')
        self.lead("start", self.message("brief"), claude=first)
        cap, args = os.path.join(self.tmp, "cap.txt"), os.path.join(self.tmp, "args.txt")
        limited = stub(self.tmp, f'cat > {cap}\necho "$@" > {args}\necho \'{{"type":"result","result":"limit"}}\'\n')
        self.lead("fresh", claude=limited)
        self.assertEqual(state(self.r)["leadSessionId"], "old-1", "no new id: the old one still works")
        fresh = stub(self.tmp, f'cat > {cap}\necho "$@" > {args}\n'
                               'echo \'{"type":"result","session_id":"new-2","result":"ok"}\'\n')
        out = self.lead("fresh", self.message("go to CP24"), claude=fresh)
        self.assertEqual(out.returncode, 0)
        self.assertNotIn("--resume", slurp(args), "a fresh call starts a new conversation")
        self.assertIn("docs/STATUS.md", slurp(cap))
        self.assertIn("go to CP24", slurp(cap))
        s = state(self.r)
        self.assertEqual(s["leadSessionId"], "new-2")
        self.assertEqual([r["id"] for r in s["retiredLeadSessions"]], ["old-1"], "retired once")

    def test_budget_guard_asks_the_lead_to_pause_at_the_threshold(self):
        def at(u):
            ev = {"type": "rate_limit_event", "rate_limit_info": {"unifiedWindows": {
                "five_hour": {"utilization": u, "resetsAt": 1}}}}
            return stub(self.tmp, f"cat >/dev/null\necho '{json.dumps(ev)}'\n"
                                  "echo '{\"type\":\"result\",\"session_id\":\"s\",\"result\":\"ok\"}'\n")
        flag = os.path.join(self.r, ".training", "pause-requested")
        hook = lambda: run(py("lead.py") + ["pause-hook"], self.r, stdin="{}").stdout
        out = self.lead("start", self.message("go"), claude=at(0.5)).stdout
        self.assertIn("5-hour window at 50%", out)
        self.assertFalse(os.path.exists(flag))
        self.assertEqual(hook().strip(), "", "the hook is silent below the threshold")
        out = self.lead("say", self.message("more"), claude=at(0.93)).stdout
        self.assertTrue(os.path.exists(flag))
        self.assertIn("asked to pause", out)
        self.assertIn("pause at the next safe point", hook())
        self.lead("say", self.message("after reset"), claude=at(0.1))
        self.assertFalse(os.path.exists(flag), "a new call clears the request")

    def test_budget_guard_watches_the_weekly_window(self):
        ev = {"type": "rate_limit_event", "rate_limit_info": {"unifiedWindows": {
            "five_hour": {"utilization": 0.2}, "seven_day": {"utilization": 0.76}}}}
        claude = stub(self.tmp, f"cat >/dev/null\necho '{json.dumps(ev)}'\n"
                                "echo '{\"type\":\"result\",\"session_id\":\"s\",\"result\":\"ok\"}'\n")
        flag = os.path.join(self.r, ".training", "pause-requested")
        out = self.lead("start", self.message("go"), claude=claude).stdout
        self.assertIn("5-hour window at 20%, weekly window at 76%", out)
        self.assertFalse(os.path.exists(flag), "default weekly threshold 90%")
        out = run(py("lead.py") + ["say", self.message("more")], self.r,
                  env={"CLAUDE_BIN": claude, "LEAD_WEEKLY_PAUSE_AT": "0.75"}).stdout
        self.assertTrue(os.path.exists(flag))
        self.assertIn("asked to pause (weekly 0.76)", out)

    def test_leading_dash_goes_via_stdin(self):
        cap = os.path.join(self.tmp, "cap.txt")
        claude = stub(self.tmp, f'cat > {cap}\nfor a in "$@"; do [ "$a" = "- leading dash" ] && exit 9; done\n'
                                'echo \'{"type":"result","session_id":"s","result":"ok"}\'\n')
        out = self.lead("start", self.message("- leading dash"), claude=claude)
        self.assertEqual(out.returncode, 0)
        self.assertIn("- leading dash", slurp(cap))

    def test_every_turn_reply_is_printed(self):
        claude = stub(self.tmp, textwrap.dedent("""\
            cat >/dev/null
            echo '{"type":"assistant","message":{"content":[{"type":"text","text":"M3 REPORT"}]}}'
            echo '{"type":"user","message":{"content":"Continue: reminder"}}'
            echo '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash"}]}}'
            echo '{"type":"user","message":{"content":[{"type":"tool_result","content":"x"}]}}'
            echo '{"type":"assistant","message":{"content":[{"type":"text","text":"late reminder"}]}}'
            echo '{"type":"result","session_id":"stub-456","result":"late reminder"}'
            """))
        out = self.lead("start", self.message("go"), claude=claude).stdout
        self.assertIn("M3 REPORT", out, "an earlier turn's reply (run 002 M3)")
        self.assertIn("late reminder", out)
        self.assertEqual(state(self.r)["leadSessionId"], "stub-456")

    def test_a_wakeup_turn_with_its_own_result_keeps_the_report(self):
        # Run 002 M4c: a scheduled wakeup started a second turn (its own init and result)
        # inside one call; only the late reply was printed and the report was lost.
        claude = stub(self.tmp, textwrap.dedent("""\
            cat >/dev/null
            echo '{"type":"system","subtype":"init"}'
            echo '{"type":"assistant","message":{"content":[{"type":"text","text":"M4c REPORT"}]}}'
            echo '{"type":"result","session_id":"s1","result":"M4c REPORT"}'
            echo '{"type":"command_lifecycle","wakeup_source":"loop_wakeup"}'
            echo '{"type":"system","subtype":"init"}'
            echo '{"type":"assistant","message":{"content":[{"type":"text","text":"reminder fired late"}]}}'
            echo '{"type":"result","session_id":"s1","result":"reminder fired late"}'
            """))
        out = self.lead("start", self.message("go"), claude=claude).stdout
        self.assertIn("M4c REPORT", out)
        self.assertIn("[earlier Lead reply 1 of 1 in this call]", out)
        self.assertTrue(out.rstrip().endswith("reminder fired late"))
        self.assertEqual(out.count("M4c REPORT"), 1, "no duplicates")

    def test_profile_keeps_the_lead_out_of_training_files_and_wakeups(self):
        profile = json.loads(slurp(os.path.join(PLUGIN, "permissions", "lead-profile.json")))
        for rule in ("Read(./.training/**)", "Bash(*.training*)", "Read(./.ledger/**)",
                     "Bash(*.ledger*)", "ScheduleWakeup"):
            self.assertIn(rule, profile["disallowedTools"])

    def test_messages_and_live_log(self):
        claude = stub(self.tmp, textwrap.dedent("""\
            cat >/dev/null
            echo '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"TodoWrite","input":{"todos":[{"content":"Task 7: Keeper panel","status":"in_progress"}]}}]}}'
            echo '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"make test"}}]}}'
            echo '{"type":"result","session_id":"x","result":"ok"}'
            """))
        self.lead("start", self.message("hello lead"), claude=claude)
        logged = os.listdir(os.path.join(self.r, ".training", "messages", "alpha"))
        self.assertEqual(len(logged), 1)
        self.assertIn("hello lead", slurp(os.path.join(self.r, ".training", "messages", "alpha", logged[0])))
        live = slurp(os.path.join(self.r, ".training", "live", "alpha.jsonl")).strip().split("\n")
        self.assertEqual(len(live), 3)
        self.assertFalse(os.path.exists(os.path.join(self.r, ".training", "lead.pid")), "mark cleared")
        status = run(py("status.py"), self.r).stdout
        self.assertIn("task: Task 7: Keeper panel", status)
        self.assertIn("last tool: Bash make test", status)

    def test_running_refuse_stop(self):
        claude = stub(self.tmp, "cat >/dev/null\nsleep 30\n")
        write(self.r, "msg.txt", "work")
        env = dict(os.environ, CLAUDE_BIN=claude)
        proc = subprocess.Popen(py("lead.py") + ["start", "msg.txt"], cwd=self.r, env=env,
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        pid_file = os.path.join(self.r, ".training", "lead.pid")
        for _ in range(50):
            if os.path.exists(pid_file) and len(slurp(pid_file).split()) == 2:
                break
            time.sleep(0.1)
        self.assertIn(f"pid {proc.pid}", self.lead("running").stdout)
        self.assertNotEqual(self.lead("start", self.message("again"), claude=claude).returncode, 0,
                            "a second call while one runs")
        group = int(slurp(pid_file).split()[1])
        self.lead("stop")
        proc.wait(timeout=5)
        time.sleep(0.2)
        with self.assertRaises(OSError):
            os.killpg(group, 0)  # the claude stub's whole process group is gone
        self.assertFalse(os.path.exists(pid_file))
        self.assertEqual(self.lead("running").returncode, 1)


# ---- learnings.py ------------------------------------------------------------------------
def card(folder, name, cid, kind, scope, impact, seen, status, extra=""):
    write(folder, name, f"---\nid: {cid}\ntitle: card {cid}\nkind: {kind}\nscope: {scope}\narea: CLAUDE.md\n"
                        f"impact: {impact}\nseen: {seen}\nstatus: {status}\n{extra}---\n")


class LearningsTest(TempCase):
    def learn(self, *args):
        return run(py("learnings.py") + list(args), self.tmp, env={"LEARNINGS_DIR": self.dir})

    def setUp(self):
        super().setUp()
        self.dir = tempfile.mkdtemp(dir=self.tmp)

    def test_rank_next_id_check(self):
        card(self.dir, "L-001-a.md", "L-001", "gap", "universal", 2, "001, 002", "open")
        card(self.dir, "L-002-b.md", "L-002", "engine-fact", "universal", 3, "002", "open")
        card(self.dir, "L-003-c.md", "L-003", "gap", "game", 3, "001, 002", "open")
        card(self.dir, "L-004-d.md", "L-004", "working", "universal", 2, "001, 002", "open")
        card(self.dir, "L-009-e.md", "L-009", "gap", "universal", 1, "001", "adopted 1c33f0c")
        rows = self.learn("rank").stdout.strip().split("\n")
        self.assertEqual([r.split("\t")[1] for r in rows[1:3]], ["L-001", "L-002"])
        self.assertIn("0\tL-003", "\n".join(rows), "game-scope cards score 0")
        self.assertNotIn("L-009", "\n".join(rows))
        self.assertNotIn("L-004", "\n".join(rows))
        every = self.learn("rank", "--all").stdout
        self.assertIn("L-009", every)
        self.assertIn("L-004", every)
        self.assertEqual(self.learn("next-id").stdout.strip(), "L-010")
        self.assertEqual(self.learn("check").returncode, 0)
        card(self.dir, "L-005-f.md", "L-006", "gap", "universal", 5, "003", "maybe")
        bad = self.learn("check")
        self.assertNotEqual(bad.returncode, 0)
        for problem in ("impact must be", "unknown status", "doesn't match"):
            self.assertIn(problem, bad.stdout)

    def test_ready_and_due(self):
        for i in range(1, 5):
            card(self.dir, f"L-00{i}-a.md", f"L-00{i}", "gap", "universal", 2, "001, 002", "open")
        card(self.dir, "L-005-b.md", "L-005", "gap", "universal", 3, "002", "open")
        card(self.dir, "L-006-c.md", "L-006", "gap", "universal", 2, "002", "open")
        card(self.dir, "L-007-d.md", "L-007", "working", "universal", 3, "001, 002", "open")
        ready = self.learn("ready").stdout
        self.assertIn("L-005", ready, "impact 3 is ready after one run")
        self.assertNotIn("L-006", ready, "one run, impact 2: not yet")
        self.assertNotIn("L-007", ready, "working cards protect a rule, never harvested")
        self.assertTrue(self.learn("due").stdout.startswith("DUE\t5 ready cards"))
        os.remove(os.path.join(self.dir, "L-001-a.md"))
        os.makedirs(os.path.join(self.dir, "harvests"))
        write(os.path.join(self.dir, "harvests"), "001.md", "# Harvest 001 (2026-01-02)\n")
        rows = "".join(f"| 2026-01-0{d} | 002 | g | M{d} |\n" for d in (1, 2, 3, 3))
        write(os.path.dirname(self.dir), "scorecard.md", rows)
        out = self.learn("due").stdout
        self.assertTrue(out.startswith("NOT DUE\t4 ready cards, 2 milestones since harvest 001"), out)
        write(os.path.join(self.dir, "harvests"), "002.md",
              "# Harvest 002 (2026-01-03)\n- **Milestones at harvest:** 1\n")
        self.assertIn("DUE\t3 milestones since harvest 002", self.learn("due").stdout)
        write(self.dir, "pending-decisions.md", "## L-001\n- **Status:** pending\n## L-002\n- **Status:** pending\n")
        self.assertIn("pending decisions: 2", self.learn("due").stdout)

    def test_watch(self):
        card(self.dir, "L-001-a.md", "L-001", "gap", "universal", 2, "001", "watching", "watch: sed -i\n")
        card(self.dir, "L-002-b.md", "L-002", "gap", "universal", 2, "001", "watching", "watch: !SKILL roblox-test$\n")
        card(self.dir, "L-003-c.md", "L-003", "gap", "universal", 2, "001", "watching")
        card(self.dir, "L-004-d.md", "L-004", "gap", "universal", 2, "001", "open", "watch: anything\n")
        digest = os.path.join(self.tmp, "digest.txt")
        write(self.tmp, "digest.txt", "10:00:00 TOOL Bash sed -i s/a/b/ f\n10:00:01 SKILL roblox-lead\n")
        out = self.learn("watch", digest).stdout
        self.assertIn("RECURRED\tL-001", out)
        self.assertIn("RECURRED\tL-002", out, "a !regex that is absent")
        self.assertIn("MANUAL\tL-003", out)
        self.assertNotIn("L-004", out, "only watching cards")
        write(self.tmp, "digest.txt", "10:00:02 SKILL roblox-test\n")
        out = self.learn("watch", digest).stdout
        self.assertIn("CLEAR\tL-001", out)
        self.assertIn("CLEAR\tL-002", out, "a !regex that is present")


# ---- transcript.py and context-budget.sh -------------------------------------------------
TRANSCRIPT = """\
{"type":"user","timestamp":"2026-01-01T10:00:00Z","message":{"content":"Build the game"}}
{"type":"assistant","timestamp":"2026-01-01T10:01:00Z","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"roblox-lead"}}]}}
{"type":"assistant","timestamp":"2026-01-01T10:02:00Z","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"sed -i x f"}}]}}
{"type":"user","timestamp":"2026-01-01T10:02:01Z","message":{"content":[{"type":"tool_result","is_error":true,"content":"This command requires approval"}]}}
{"type":"assistant","timestamp":"2026-01-01T10:03:00Z","message":{"content":[{"type":"tool_use","name":"mcp__Roblox_Studio__execute_luau","input":{"datamodel_type":"Edit","code":"return 1"}}]}}
{"type":"user","timestamp":"2026-01-01T10:03:01Z","message":{"content":[{"type":"tool_result","is_error":true,"content":"boom"}]}}
{"type":"user","timestamp":"2026-01-01T10:03:02Z","message":{"content":[{"type":"tool_result","is_error":true,"content":"rm in '/tmp/x.py' needs approval"}]}}
{"type":"user","timestamp":"2026-01-01T11:00:00Z","message":{"content":"Continue"}}
{"type":"assistant","timestamp":"2026-01-01T11:05:00Z","message":{"content":[{"type":"text","text":"You've hit your 5-hour limit"}]}}
not json
"""


class TranscriptBudgetTest(TempCase):
    def test_digest_and_metrics(self):
        write(self.tmp, "t.jsonl", TRANSCRIPT)
        path = os.path.join(self.tmp, "t.jsonl")
        digest = run(py("transcript.py") + ["digest", path], self.tmp).stdout
        for part in ("SKILL roblox-lead", "DENIAL", "ERROR boom", "execute_luau [Edit]"):
            self.assertIn(part, digest)
        since = run(py("transcript.py") + ["digest", "--since", "2026-01-01T10:30", path], self.tmp).stdout
        self.assertNotIn("roblox-lead", since)
        metrics = run(py("transcript.py") + ["metrics", path], self.tmp).stdout
        # 2 denials: "requires approval" and "needs approval" (the latter was missed before M4a)
        self.assertIn("| 1 | 10:00 | 3 | 2 | 1 | 2 | 1 | 0 | roblox-lead@10:01 |", metrics)
        turn2 = [l for l in metrics.split("\n") if l.startswith("| 2 ")][0]
        self.assertIn("| 2 | 11:00 | 5 |", turn2)
        self.assertIn("USAGE LIMIT", turn2)

    def test_all_conversations_and_subagents(self):
        repo = make_repo(self.tmp, {"CLAUDE.md": "# framework\n"})
        root = git(repo, "rev-parse", "--show-toplevel")
        write(root, "TRAINING_STATE.json", json.dumps({
            "game": "g", "leadSessionId": "s3", "retiredLeadSessions": [{"id": "s2"}]}))
        write(os.path.join(root, ".training", "live"), "g.jsonl",
              '{"ts": "x", "event": {"session_id": "s1"}}\n{"ts": "x", "event": {"session_id": "s2"}}\n')
        config = os.path.join(self.tmp, "config")
        project = os.path.join(config, "projects", root.replace("/", "-"))

        def line(ts, kind, content):
            return json.dumps({"type": kind, "timestamp": ts, "message": {"content": content}}) + "\n"
        tool = lambda i, cmd: [{"type": "tool_use", "id": i, "name": "Bash", "input": {"command": cmd}}]
        denied = lambda i: [{"type": "tool_result", "tool_use_id": i, "is_error": True,
                             "content": "Brace expansion: requires approval"}]
        write(project, "s1.jsonl", line("2026-01-01T09:00:00Z", "user", "old milestone")
              + line("2026-01-01T09:01:00Z", "assistant", tool("a", "echo s1")))
        write(project, "s3.jsonl", line("2026-01-01T11:00:00Z", "user", "task 13")
              + line("2026-01-01T11:01:00Z", "assistant", tool("b", "echo s3"))
              + line("2026-01-01T11:09:00Z", "assistant", tool("c", "echo done")))
        # s2 is missing (another config dir, deleted): skipped with a warning.
        sub = line("2026-01-01T11:02:00Z", "user", "review the code") \
            + line("2026-01-01T11:03:00Z", "assistant", tool("r1", "wc -l {a,b}.lua")) \
            + line("2026-01-01T11:03:01Z", "user", denied("r1"))
        write(os.path.join(project, "s3", "subagents"), "agent-x.jsonl", sub + sub)  # records repeat
        env = {"CLAUDE_CONFIG_DIR": config}
        out = run(py("transcript.py") + ["digest"], root, env=env)
        self.assertIn("s2.jsonl not found", out.stderr)
        lines = out.stdout.split("\n")
        self.assertEqual([l.split()[0] for l in lines if l][:3], ["09:00:00", "09:01:00", "11:00:00"],
                         "oldest conversation first")
        self.assertEqual(sum("SUB-TOOL Bash wc -l" in l for l in lines), 1, "repeated records counted once")
        self.assertEqual(sum("SUB-DENIAL" in l for l in lines), 1)
        self.assertNotIn("review the code", out.stdout, "a subagent's prompt is not a Lead turn")
        self.assertLess(out.stdout.index("SUB-TOOL"), out.stdout.index("echo done"), "merged by time")
        metrics = run(py("transcript.py") + ["metrics", "--since", "2026-01-01T10:00"], root, env=env).stdout
        # one turn: 2 Lead tools (the subagent's call doesn't count), 1 denial from the subagent
        self.assertIn("| 1 | 11:00 | 9 | 2 | 0 | 1 | 0 | 0 |", metrics)
        self.assertNotIn("\n| 2 |", metrics, "the subagent's prompt starts no turn")

    def test_context_budget(self):
        write(self.tmp, "CLAUDE.md", "line one\nline two\n")
        write(self.tmp, ".claude/skills/one/SKILL.md", "---\nname: one\ndescription: eight ch\n---\nbody\n")
        budget = os.path.join(SCRIPTS, "context-budget.sh")
        table = run(["bash", budget], self.tmp, env={"BUDGET_ROOT": self.tmp}).stdout
        self.assertIn("| CLAUDE.md | 2 | 4 |", table)
        self.assertIn("| one | 5 |", table)
        total = run(["bash", budget, "--total"], self.tmp, env={"BUDGET_ROOT": self.tmp}).stdout
        self.assertIn("always-loaded ~6 tokens", total)


# ---- game.py, human_checks.py, status.py -------------------------------------------------
TEMPLATE = {
    "CLAUDE.md": "# framework\n",
    "tests/run.lua": "return nil\n",
    "src/game/ReplicatedStorage/GameConfig.lua": "return {} -- template\n",
    "src/game/ReplicatedStorage/Modules/ExampleMath.lua": "return {}\n",
    ".gitignore": "/.training/\n/TRAINING_STATE.json\n/FRAMEWORK_FEEDBACK.md\n*.rbxl\n*.rbxl.lock\n",
}


def add_game(root, name):
    write(root, "docs/design/GDD.md", f"# {name}: Game Design Document\n")
    write(root, "src/game/ReplicatedStorage/Classes/Tower.lua", f"-- {name} tower\n")
    write(root, "src/game/ReplicatedStorage/GameConfig.lua", f"return {{ Game = '{name}' }}\n")
    os.remove(os.path.join(root, "src/game/ReplicatedStorage/Modules/ExampleMath.lua"))
    write(root, "FRAMEWORK_FEEDBACK.md", f"{name} friction\n")
    write(root, f"{name}.rbxl", f"place-{name}\n")


def read(root, rel):
    return slurp(os.path.join(root, rel))


def exists(root, rel):
    return os.path.exists(os.path.join(root, rel))


class GameTest(TempCase):
    def setUp(self):
        super().setUp()
        self.r = make_repo(self.tmp, TEMPLATE)

    def game(self, *args, root=None):
        return run(py("game.py") + list(args), root or self.r)

    def assert_template_tree(self):
        self.assertEqual(git(self.r, "status", "--porcelain"), "")
        self.assertFalse(exists(self.r, "FRAMEWORK_FEEDBACK.md"))

    def test_park_and_load(self):
        add_game(self.r, "Alpha")
        self.assertEqual(self.game("park", "001-alpha").returncode, 0)
        self.assert_template_tree()
        self.assertFalse(exists(self.r, "Alpha.rbxl"))
        self.assertIn("template", read(self.r, "src/game/ReplicatedStorage/GameConfig.lua"))
        self.assertTrue(exists(self.r, "src/game/ReplicatedStorage/Modules/ExampleMath.lua"))
        self.assertIn("ExampleMath", read(self.r, ".training/archive/001-alpha/game.json"))
        self.assertEqual(read(self.r, "CLAUDE.md"), "# framework\n", "the framework is untouched")
        self.assertNotEqual(self.game("park", "002-empty").returncode, 0, "nothing to park")
        self.assertEqual(self.game("load", "001-alpha").returncode, 0)
        self.assertIn("Alpha", read(self.r, "src/game/ReplicatedStorage/GameConfig.lua"))
        for rel in ("src/game/ReplicatedStorage/Classes/Tower.lua", "Alpha.rbxl", "FRAMEWORK_FEEDBACK.md"):
            self.assertTrue(exists(self.r, rel), rel)
        self.assertFalse(exists(self.r, "src/game/ReplicatedStorage/Modules/ExampleMath.lua"), "deletion re-applied")
        self.assertFalse(exists(self.r, ".training/archive/001-alpha"), "one copy only")

    def test_switch_and_guards(self):
        add_game(self.r, "Alpha")
        self.game("park", "001-alpha")
        add_game(self.r, "Beta")
        self.assertNotEqual(self.game("load", "001-alpha").returncode, 0, "the tree is occupied")
        self.assertEqual(self.game("switch", "002-beta", "001-alpha").returncode, 0)
        self.assertIn("Alpha", read(self.r, "docs/design/GDD.md"))
        self.game("switch", "001-alpha", "002-beta")
        self.assertIn("Beta", read(self.r, "src/game/ReplicatedStorage/GameConfig.lua"))
        self.assertTrue(exists(self.r, ".training/archive/001-alpha/tree/Alpha.rbxl"))
        write(self.r, "Beta.rbxl.lock", "")
        self.assertNotEqual(self.game("park", "002-beta").returncode, 0, "Studio holds the place")
        self.assertTrue(exists(self.r, "docs/design/GDD.md"))
        os.remove(os.path.join(self.r, "Beta.rbxl.lock"))
        write(self.r, "TRAINING_STATE.json", '{"status": "active"}')
        self.assertNotEqual(self.game("park", "002-beta").returncode, 0, "a session is active")
        os.remove(os.path.join(self.r, "TRAINING_STATE.json"))
        write(self.r, "src/shared/NewThing.lua", "-- unsure\n")
        self.assertNotEqual(self.game("park", "002-beta").returncode, 0, "untracked under framework paths")

    def test_legacy_archive(self):
        legacy = make_repo(self.tmp, TEMPLATE)
        add_game(legacy, "Legacy")
        os.makedirs(os.path.join(self.r, ".training", "archive"))
        os.rename(legacy, os.path.join(self.r, ".training", "archive", "000-legacy"))
        self.assertEqual(self.game("load", "000-legacy").returncode, 0)
        self.assertIn("Legacy", read(self.r, "docs/design/GDD.md"))
        self.assertFalse(exists(self.r, ".training/archive/000-legacy"))

    def test_human_checks_and_status(self):
        write(self.r, "docs/design/milestones/M1-Core.md",
              "- **Still needs a human:**\n  - Does it feel good?\n  - Two players.\n- **Changes:** none\n")
        write(self.r, "docs/design/milestones/M1-Core-plan.md", "- **Still needs a human:** plan only\n")
        write(self.r, "docs/TESTING.md",
              "## M1 — <milestone name>\n- [ ] `[playtest]` ...\n## M1 — Core\n- [x] done\n- [ ] Phone layout\n")
        self.assertEqual(run(py("human_checks.py") + ["--count"], self.r).stdout.strip(), "3")
        add_game(self.r, "Beta")
        self.assertRegex(run(py("status.py"), self.r).stdout, r"Game in tree: +Beta")


if __name__ == "__main__":
    unittest.main()
