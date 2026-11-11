#!/usr/bin/env python3
"""Switch the game in the working tree. The framework is never touched: it stays shared and
always the latest; only the game's own files move.

  game.py list                     games in .training/archive/
  game.py park <NNN-name>          move the current game into .training/archive/<NNN-name>/
                                   and put the template back (tree = framework only)
  game.py load <NNN-name>          move an archived game into the clean tree
  game.py switch <park-as> <load>  park, then load

A game's state is computed from git, never from a hand-kept list:
  - untracked files that aren't ignored;
  - tracked files outside the framework paths that differ from HEAD (starter files the game
    changed, or deleted, e.g. ExampleMath.lua);
  - its ignored per-game files: FRAMEWORK_FEEDBACK.md, TRAINING_STATE.json and the Studio
    place file (*.rbxl at the root).
Scenarios stay in .training/scenarios/. An archive made before this script (a full clone of
the repo, with its own .git) loads the same way: its state is computed from its own git.

Run with `python3 -I`. Guards: no active session, no running Lead, Studio not holding the place
file open, no untracked files under framework paths (ask whether they're game or framework).
"""
import datetime, json, os, shutil, subprocess, sys

PER_GAME = ["FRAMEWORK_FEEDBACK.md", "TRAINING_STATE.json"]


def die(msg):
    sys.exit(f"game.py: {msg}")


def git(root, *args):
    out = subprocess.run(["git", "-C", root, *args], capture_output=True, text=True)
    if out.returncode:
        die(f"git {' '.join(args)} failed: {out.stderr.strip()}")
    return out.stdout


def repo_root():
    return git(os.getcwd(), "rev-parse", "--show-toplevel").strip()


def framework_paths(root):
    script = os.path.join(os.path.dirname(os.path.abspath(__file__)), "commit-framework.sh")
    out = subprocess.run(["bash", script, "--list"], cwd=root, capture_output=True, text=True)
    return [p for p in out.stdout.split("\n") if p]


def under(path, prefixes):
    return any(path == p or path.startswith(p.rstrip("/") + "/") for p in prefixes)


def lines(text):
    return [l for l in text.split("\0") if l]


def game_state(tree, fw):
    """(files to carry, tracked files the game deleted, untracked files under framework paths)."""
    untracked = lines(git(tree, "ls-files", "-z", "--others", "--exclude-standard"))
    changed = lines(git(tree, "diff", "-z", "--name-only", "HEAD"))
    deleted = set(lines(git(tree, "diff", "-z", "--name-only", "--diff-filter=D", "HEAD")))
    suspicious = [f for f in untracked if under(f, fw)]
    carry = [f for f in untracked if not under(f, fw)]
    carry += [f for f in changed if not under(f, fw) and f not in deleted]
    carry += [f for f in PER_GAME if os.path.exists(os.path.join(tree, f))]
    carry += [f for f in os.listdir(tree) if f.endswith(".rbxl") or f.endswith(".rbxlx")]
    return sorted(set(carry)), sorted(f for f in deleted if not under(f, fw)), suspicious


def archive_dir(root, name):
    return os.path.join(root, ".training", "archive", name)


def check_idle(root):
    state = os.path.join(root, "TRAINING_STATE.json")
    if os.path.exists(state) and json.load(open(state)).get("status") == "active":
        die("a training session is active; run session.py end first")
    pid_file = os.path.join(root, ".training", "lead.pid")
    if os.path.exists(pid_file):
        try:
            os.kill(int(open(pid_file).read().split()[0]), 0)
            die("the Lead is running; wait for it or run lead.py stop")
        except (ProcessLookupError, ValueError, IndexError):
            pass
    locks = [f for f in os.listdir(root) if f.endswith(".rbxl.lock") or f.endswith(".rbxlx.lock")]
    if locks:
        die(f"Studio has the place open ({', '.join(locks)}); close the place in Studio first")


def copy(src_root, dst_root, rel):
    src, dst = os.path.join(src_root, rel), os.path.join(dst_root, rel)
    os.makedirs(os.path.dirname(dst) or dst_root, exist_ok=True)
    shutil.copy2(src, dst)


def prune_empty_dirs(root, rels):
    for rel in rels:
        d = os.path.dirname(os.path.join(root, rel))
        while d.startswith(root + os.sep) and d != root:
            if os.listdir(d):
                break
            os.rmdir(d)
            d = os.path.dirname(d)


def park(root, name):
    check_idle(root)
    dest = archive_dir(root, name)
    if os.path.exists(dest):
        die(f"{dest} already exists")
    fw = framework_paths(root)
    carry, deleted, suspicious = game_state(root, fw)
    if suspicious:
        die("untracked files under framework paths (commit them, or move them if they're the game's):\n  "
            + "\n  ".join(suspicious))
    if not carry and not deleted:
        die("no game in the tree")
    tree = os.path.join(dest, "tree")
    for rel in carry:
        copy(root, tree, rel)
    gdd = os.path.join(root, "docs/design/GDD.md")
    manifest = {
        "name": name,
        "title": open(gdd).readline().strip("# \n") if os.path.exists(gdd) else None,
        "parkedAt": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
        "frameworkCommit": git(root, "rev-parse", "HEAD").strip(),
        "files": carry,
        "deleted": deleted,
    }
    json.dump(manifest, open(os.path.join(dest, "game.json"), "w"), indent=2)
    tracked = set(lines(git(root, "ls-files", "-z")))
    for rel in carry:
        if rel in tracked:
            git(root, "checkout", "HEAD", "--", rel)
        else:
            os.remove(os.path.join(root, rel))
    for rel in deleted:
        git(root, "checkout", "HEAD", "--", rel)
    prune_empty_dirs(root, carry)
    print(f"Parked {len(carry)} files and {len(deleted)} deletions in .training/archive/{name}/.")
    print("The tree is now the template. The framework was not touched.")


def load(root, name):
    check_idle(root)
    src = archive_dir(root, name)
    if not os.path.isdir(src):
        die(f"no archive {src}")
    fw = framework_paths(root)
    carry, deleted, _ = game_state(root, fw)
    if carry or deleted:
        die("a game is already in the tree; park it first (game.py park <NNN-name>)")
    if os.path.exists(os.path.join(src, "game.json")):
        manifest = json.load(open(os.path.join(src, "game.json")))
        tree, files, gone = os.path.join(src, "tree"), manifest["files"], manifest["deleted"]
        since = manifest["frameworkCommit"]
    elif os.path.isdir(os.path.join(src, ".git")):  # legacy archive: a full clone
        tree = src
        files, gone, _ = game_state(src, fw)
        since = git(src, "rev-parse", "HEAD").strip()
    else:
        die(f"{src} has neither game.json nor .git")
    for rel in files:
        copy(tree, root, rel)
    for rel in gone:
        path = os.path.join(root, rel)
        if os.path.exists(path):
            os.remove(path)
    shutil.rmtree(src)
    places = [f for f in files if f.endswith(".rbxl") or f.endswith(".rbxlx")]
    print(f"Loaded {len(files)} files and {len(gone)} deletions from .training/archive/{name}/ "
          "(archive removed).")
    print(f"Framework then: {since[:7]}, now: {git(root, 'rev-parse', '--short', 'HEAD').strip()}.")
    print("Next:")
    print("  1. make test: the game against the current framework (a failure is migration evidence:")
    print("     log it in the ledger).")
    print(f"  2. Human: open {places[0] if places else 'the game place'} in Studio, connect Rojo, "
          "click Accept.")
    print("  3. session.py start <name> --continue --place <place>, then make verify.")


def list_games(root):
    base = os.path.join(root, ".training", "archive")
    for name in sorted(os.listdir(base)) if os.path.isdir(base) else []:
        m = os.path.join(base, name, "game.json")
        kind = (json.load(open(m)).get("title") or "") if os.path.exists(m) else "(legacy full clone)"
        print(f"{name}\t{kind}")


def main(argv):
    root = repo_root()
    cmd = argv[1] if len(argv) > 1 else ""
    if cmd == "list" and len(argv) == 2:
        list_games(root)
    elif cmd == "park" and len(argv) == 3:
        park(root, argv[2])
    elif cmd == "load" and len(argv) == 3:
        load(root, argv[2])
    elif cmd == "switch" and len(argv) == 4:
        park(root, argv[2])
        load(root, argv[3])
    else:
        die(__doc__.strip().split("\n\n")[1])


if __name__ == "__main__":
    main(sys.argv)
