#!/usr/bin/env python3
"""In-place training session state for the repo you run it in (TRAINING_STATE.json).

  session.py start <kebab-name> [--continue] [--place <Studio place name>]
  session.py milestone <M>     record the milestone and the current framework commit
  session.py end               end the session

Games live in games/<name>/ (each its own repo, made by `make new-game NAME=<name>`): `start`
needs that folder and records it as `gameDir`; the Lead then works there. A framework without
template/ (games built in place, before games/) uses the root as the game folder.

`start` refuses if a session is already active, or if the game folder's docs/design/GDD.md
exists unless --continue is given and the GDD's title matches <kebab-name>
("tiptoe-bandits" matches "# Tiptoe Bandits: Game Design Document"). The lock is the state
file's status, "active" until `end` (tool calls run in short-lived shells, so a process id
can't hold it). Run with `python3 -I`.
"""
import datetime, json, os, re, subprocess, sys

USAGE = "usage: session.py start <name> [--continue] [--place <name>] | milestone <M> | end"


def die(msg):
    print(f"session.py: {msg}", file=sys.stderr)
    sys.exit(1)


def git(root, *args):
    return subprocess.run(["git", "-C", root, *args], capture_output=True, text=True).stdout.strip()


def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds")


def normalize(text):
    return re.sub(r"[^a-z0-9]+", " ", text.lower()).strip()


def gdd_name(gdd):
    """The session name a GDD's title calls for: "# Clockwork Keep: Game…" → clockwork-keep."""
    title = re.sub(r"^#\s*", "", open(gdd).readline().strip())
    title = re.sub(r":\s*Game Design Document\s*$", "", title)
    return normalize(title).replace(" ", "-")


class Session:
    def __init__(self):
        self.root = git(os.getcwd(), "rev-parse", "--show-toplevel") or die("not in a git repo")
        self.path = os.path.join(self.root, "TRAINING_STATE.json")
        self.gdd = os.path.join(self.root, "docs", "design", "GDD.md")
        self.games_layout = os.path.isdir(os.path.join(self.root, "template"))

    def use_game(self, name):
        """In the games/ layout: the game's folder, relative to the root (it must exist)."""
        rel = os.path.join("games", name)
        if not os.path.isdir(os.path.join(self.root, rel)):
            die(f"no {rel}/: create it first (make new-game NAME={name})")
        self.gdd = os.path.join(self.root, rel, "docs", "design", "GDD.md")
        return rel

    def load(self):
        if not os.path.exists(self.path):
            die(f"no session ({self.path} missing)")
        return json.load(open(self.path))

    def save(self, state):
        json.dump(state, open(self.path, "w"), indent=2)

    def active(self):
        if not os.path.exists(self.path):
            return False
        try:
            return json.load(open(self.path)).get("status") == "active"
        except ValueError:
            return True  # unreadable state: treat as held rather than overwrite it

    def start(self, args):
        name, mode, place = None, "new", None
        while args:
            arg = args.pop(0)
            if arg == "--continue":
                mode = "continue"
            elif arg == "--place":
                place = args.pop(0) if args else die("--place needs a name")
            elif arg.startswith("--"):
                die(f"unknown option '{arg}'")
            elif name:
                die(f"unexpected argument '{arg}'")
            else:
                name = arg
        if not name:
            die(USAGE)
        if self.active():
            die(f"a training session is already active (see {self.path}); run session.py end if it is over")
        game_dir = self.use_game(name) if self.games_layout else None
        if os.path.exists(self.gdd):
            if mode != "continue":
                die(f"a game already occupies this tree ({self.gdd}); use --continue to adopt it")
            expected = gdd_name(self.gdd)
            if normalize(name) != normalize(expected):
                die(f"the GDD's title calls for the session name '{expected}', not '{name}'")
        elif mode == "continue":
            die(f"--continue needs an existing {self.gdd}")
        stamp = now()
        self.save({"game": name, "gameDir": game_dir, "mode": mode, "place": place,
                   "frameworkCommit": git(self.root, "rev-parse", "HEAD"),
                   "status": "active", "leadSessionId": None, "milestone": None, "history": [],
                   "startedAt": stamp, "updatedAt": stamp})
        print(f"Training session started for '{name}' (framework {git(self.root, 'rev-parse', '--short', 'HEAD')}).")

    def milestone(self, args):
        if not args:
            die("usage: session.py milestone <M>")
        state = self.load()
        state["milestone"] = args[0]
        state.setdefault("history", []).append({"milestone": args[0], "frameworkCommit": git(self.root, "rev-parse", "HEAD")})
        state["updatedAt"] = now()
        self.save(state)
        print(f"Recorded milestone {args[0]}.")

    def end(self, _args):
        state = self.load()
        state["status"] = "ended"
        state["updatedAt"] = now()
        self.save(state)
        print("Training session ended.")


def main(argv):
    commands = {"start": "start", "milestone": "milestone", "end": "end"}
    if len(argv) < 2 or argv[1] not in commands:
        die(USAGE)
    getattr(Session(), commands[argv[1]])(list(argv[2:]))


if __name__ == "__main__":
    main(sys.argv)
