#!/usr/bin/env python3
"""The learnings ledger (.ledger/learnings/L-NNN-*.md at the repo root), see its README.md.

  learnings.py rank [--all]    score and list cards, highest first (closed and `working`
                               cards only with --all)
  learnings.py next-id         print the next free card id (L-NNN)
  learnings.py check           lint every card's frontmatter; non-zero exit on problems
  learnings.py ready           list open cards with enough evidence to harvest (2+ runs, or impact 3)
  learnings.py due             is a harvest due? DUE when 5+ cards are ready or 3+ milestones closed
                               since the last harvest (rows in .ledger/scorecard.md); also counts
                               pending decisions waiting for a human (pending-decisions.md)
  learnings.py remind          one line for the trainer's SessionStart hook, only when a harvest is
                               due or decisions are pending; silent otherwise (and outside a repo)
  learnings.py watch <digest>  for each `watching` card, search its `watch:` regex in a run's
                               digest (scripts/transcript.py digest > file): RECURRED / CLEAR /
                               MANUAL (no regex: judge it by reading). `!regex` means the
                               symptom is the regex's absence (e.g. a skill that never loaded).
                               Parts joined by ` && ` are checked separately; any one recurring
                               makes the card RECURRED.

Score = impact x distinct runs x scope weight (universal 2, genre:* 1, game 0).
Closed = adopted / declined / retired / merged. LEARNINGS_DIR overrides the folder (tests).
Run with `python3 -I`.
"""
import glob, os, re, sys

import subprocess

# The ledger is data, not plugin definition: it lives at the repo root in .ledger/learnings/.
DIR = os.environ.get("LEARNINGS_DIR") or os.path.join(
    subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True).stdout.strip(),
    ".ledger", "learnings")
REQUIRED = ("id", "title", "kind", "scope", "area", "impact", "seen", "status")
KINDS = ("friction", "gap", "wrong", "engine-fact", "pattern", "bug-class", "working", "trainer")
CLOSED = re.compile(r"^(adopted|declined|retired|merged)")
STATUS = re.compile(r"^(open|proposed|watching|declined|retired|adopted [0-9a-f]{7,}|merged L-[0-9]{3})$")


def cards():
    for path in sorted(glob.glob(os.path.join(DIR, "L-*.md"))):
        yield path, frontmatter(path)


def frontmatter(path):
    lines = open(path).read().split("\n")
    meta = {}
    if not lines or lines[0] != "---":
        return meta
    for line in lines[1:]:
        if line == "---":
            break
        key, _, value = line.partition(":")
        meta[key.strip()] = value.strip()
    return meta


def score(meta):
    runs = len([s for s in re.split(r"[ ,]+", meta.get("seen", "")) if s])
    scope = meta.get("scope", "")
    weight = 2 if scope == "universal" else 1 if scope.startswith("genre:") else 0
    impact = int(meta["impact"]) if meta.get("impact", "").isdigit() else 0
    return impact * runs * weight, runs


def rank(show_all):
    rows = []
    for _, m in cards():
        if not show_all and (CLOSED.match(m.get("status", "")) or m.get("kind") == "working"):
            continue
        s, runs = score(m)
        rows.append((s, m.get("id", ""), m.get("status", ""), m.get("impact", ""), runs,
                     m.get("scope", ""), m.get("kind", ""), m.get("title", "")))
    rows.sort(key=lambda r: (-r[0], r[1]))
    print("score\tid\tstatus\timpact\truns\tscope\tkind\ttitle")
    for r in rows:
        print("\t".join(str(c) for c in r))


READY_MIN, MILESTONES_MIN = 5, 3


def ready_cards():
    """Open, non-`working` cards seen in 2+ runs or of impact 3, highest score first."""
    out = []
    for _, m in cards():
        if m.get("status") != "open" or m.get("kind") == "working":
            continue
        s, runs = score(m)
        if runs >= 2 or m.get("impact") == "3":
            out.append((s, m.get("id", ""), m.get("title", "")))
    return sorted(out, key=lambda r: (-r[0], r[1]))


def last_harvest():
    """(number, date, milestones recorded at it) of the latest harvests/NNN.md, or None."""
    files = sorted(glob.glob(os.path.join(DIR, "harvests", "[0-9][0-9][0-9].md")))
    if not files:
        return None
    text = open(files[-1]).read()
    date = re.search(r"\((\d{4}-\d{2}-\d{2})\)", text.split("\n")[0])
    at = re.search(r"Milestones at harvest:\*{0,2}\s*(\d+)", text)
    return os.path.basename(files[-1])[:3], date.group(1) if date else "", int(at.group(1)) if at else None


def scorecard_dates():
    path = os.path.join(os.path.dirname(DIR), "scorecard.md")
    if not os.path.exists(path):
        return []
    return [m.group(1) for line in open(path) if (m := re.match(r"^\| (\d{4}-\d{2}-\d{2}) \|", line))]


def pending_count():
    path = os.path.join(DIR, "pending-decisions.md")
    return open(path).read().count("**Status:** pending") if os.path.exists(path) else 0


def due():
    ready = ready_cards()
    dates = scorecard_dates()
    last = last_harvest()
    if last is None:
        since, label = len(dates), "no harvest yet"
    else:
        num, date, at = last
        done = at if at is not None else sum(1 for d in dates if d <= date)
        since, label = len(dates) - done, f"since harvest {num} ({date})"
    reasons = []
    if len(ready) >= READY_MIN:
        reasons.append(f"{len(ready)} ready cards (>= {READY_MIN})")
    if since >= MILESTONES_MIN:
        reasons.append(f"{since} milestones {label} (>= {MILESTONES_MIN})")
    verdict = "DUE" if reasons else "NOT DUE"
    detail = "; ".join(reasons) or f"{len(ready)} ready cards, {since} milestones {label}"
    print(f"{verdict}\t{detail}\tpending decisions: {pending_count()}")
    return ready


def remind():
    if not os.path.isdir(DIR):
        return
    import io, contextlib
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        due()
    verdict, detail, pending = buf.getvalue().strip().split("\t")
    n = int(pending.rsplit(" ", 1)[-1])
    if verdict == "DUE":
        print(f"Trainer: a harvest is due ({detail}). Run it at the next close-out with the Lead "
              f"idle (framework-harvest, autonomous mode).")
    if n:
        print(f"Trainer: {n} harvest decision(s) wait for the maintainer in "
              f".ledger/learnings/pending-decisions.md; offer to review them when they're present.")


def next_id():
    nums = [int(m.group(1)) for f in os.listdir(DIR) if (m := re.match(r"^L-(\d+)-.*\.md$", f))] \
        if os.path.isdir(DIR) else []
    print(f"L-{max(nums, default=0) + 1:03d}")


def check():
    problems = []
    for path, m in cards():
        name = os.path.basename(path)
        problems += [f"{name}: missing {k}" for k in REQUIRED if not m.get(k)]
        if m.get("impact") not in ("1", "2", "3"):
            problems.append(f"{name}: impact must be 1, 2 or 3")
        if m.get("kind") not in KINDS:
            problems.append(f"{name}: unknown kind")
        if not re.match(r"^(universal|game|genre:[a-z0-9-]+)$", m.get("scope", "")):
            problems.append(f"{name}: unknown scope")
        if not STATUS.match(m.get("status", "")):
            problems.append(f"{name}: unknown status")
        if not name.startswith(f"{m.get('id')}-"):
            problems.append(f"{name}: id {m.get('id')} doesn't match file name")
    for p in problems:
        print(p)
    if not problems:
        print("learnings: all cards valid")
    return 1 if problems else 0


def watch(digest_path):
    digest = open(digest_path).read().split("\n")
    for _, m in cards():
        if m.get("status") != "watching":
            continue
        pattern = m.get("watch", "")
        if not pattern:
            print(f"MANUAL\t{m.get('id')}\t{m.get('title')}")
            continue
        results = [watch_one(part.strip(), digest) for part in pattern.split(" && ")]
        recurred = [r for ok, r in results if not ok]
        if recurred:
            print(f"RECURRED\t{m['id']}\t" + "; ".join(recurred))
        else:
            print(f"CLEAR\t{m['id']}\t" + "; ".join(r for _, r in results))


def watch_one(pattern, digest):
    """One watch part: (clear?, description). `!regex` = the symptom is the regex's absence."""
    negated = pattern.startswith("!")
    shown = pattern[1:] if negated else pattern
    hits = sum(1 for line in digest if re.search(shown, line))
    if negated:
        return (hits > 0, f"present ({hits}): {shown}" if hits else f"absent: {shown}")
    return (hits == 0, f"{hits} hits: {shown}" if hits else shown)

def main(argv):
    cmd = argv[1] if len(argv) > 1 else ""
    if cmd == "rank":
        rank("--all" in argv[2:])
    elif cmd == "ready":
        for s, cid, title in ready_cards():
            print(f"{s}\t{cid}\t{title}")
    elif cmd == "due":
        due()
    elif cmd == "remind":
        remind()
    elif cmd == "next-id":
        next_id()
    elif cmd == "check":
        return check()
    elif cmd == "watch" and len(argv) > 2 and os.access(argv[2], os.R_OK):
        watch(argv[2])
    else:
        print("usage: learnings.py rank [--all] | ready | due | next-id | check | watch <digest>",
              file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
