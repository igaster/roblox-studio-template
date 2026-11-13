#!/usr/bin/env python3
"""Collect every check that still needs a human for the game in the tree.

  human_checks.py            print the checklist (markdown)
  human_checks.py --write    also save it to .training/human-checks-<game>.md
  human_checks.py --count    print only the number of open checks

Sources:
  - each milestone file's "Still needs a human" item (docs/design/milestones/M*.md, not plans);
  - unchecked items in docs/TESTING.md, by section (template placeholder sections skipped).
Run with `python3 -I`.
"""
import glob, json, os, re, subprocess, sys


def root():
    return subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True,
                          text=True).stdout.strip()


def milestone_items(path):
    """Bullets under '**Still needs a human:**' (inline text or the nested list after it)."""
    items, collecting, indent = [], False, None
    for line in open(path):
        m = re.match(r"^(\s*)- \*\*Still needs a human:\*\*\s*(.*)$", line)
        if m:
            collecting, indent = True, len(m.group(1))
            if m.group(2).strip():
                items.append(m.group(2).strip())
            continue
        if collecting:
            sub = re.match(r"^(\s*)- (.*)$", line)
            if sub and len(sub.group(1)) > indent:
                items.append(sub.group(2).strip())
            elif line.strip():
                collecting = False
    return items


def testing_items(path):
    sections, current = {}, None
    for line in open(path):
        h = re.match(r"^#{2,4} (.*)$", line)
        if h:
            current = h.group(1).strip()
            continue
        u = re.match(r"^\s*- \[ \] (.*)$", line)
        if u and current and "<" not in current and u.group(1).strip() != "`[playtest]` ...":
            sections.setdefault(current, []).append(u.group(1).strip())
    return sections


def collect(base):
    out = []
    for path in sorted(glob.glob(os.path.join(base, "docs/design/milestones/M*.md"))):
        if path.endswith("-plan.md"):
            continue
        items = milestone_items(path)
        if items:
            out.append((f"{os.path.basename(path)[:-3]}: still needs a human", items))
    testing = os.path.join(base, "docs/TESTING.md")
    if os.path.exists(testing):
        for section, items in testing_items(testing).items():
            out.append((f"TESTING.md: {section}", items))
    return out


def game_base(root):
    """The game's folder: the session's `gameDir` (games/<name>) when it names one, else the
    framework root (games built in place, before games/). scorecard.py and status.py use it."""
    state = os.path.join(root, "TRAINING_STATE.json")
    try:
        rel = json.load(open(state)).get("gameDir") if os.path.exists(state) else None
    except ValueError:
        rel = None
    return os.path.join(root, rel) if rel else root


def game_name(base):
    gdd = os.path.join(base, "docs/design/GDD.md")
    if not os.path.exists(gdd):
        return None
    title = open(gdd).readline().strip("# \n").split(":")[0]
    return re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")


def main(argv):
    base = root()
    game = game_base(base)
    groups = collect(game)
    count = sum(len(items) for _, items in groups)
    if "--count" in argv:
        print(count)
        return
    name = game_name(game) or "no-game"
    text = [f"# Human checks: {name} ({count} open)", ""]
    for title, items in groups:
        text += [f"## {title}", ""] + [f"- [ ] {i}" for i in items] + [""]
    doc = "\n".join(text)
    print(doc)
    if "--write" in argv:
        os.makedirs(os.path.join(base, ".training"), exist_ok=True)
        path = os.path.join(base, ".training", f"human-checks-{name}.md")
        open(path, "w").write(doc)
        print(f"(saved to {os.path.relpath(path, base)})")


if __name__ == "__main__":
    main(sys.argv)
