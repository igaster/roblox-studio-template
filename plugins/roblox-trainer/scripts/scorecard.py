#!/usr/bin/env python3
"""AI-suitability scorecard: one row per milestone, so the trend across runs shows whether the
framework is getting better at letting an agent build games with less human help.

  scorecard.py record <run> <milestone> --since <ISO> [--until <ISO>] [--reviewer-fixes N]
                     [--human-blockers N]
      append the milestone's row to .ledger/scorecard.md at the repo root (milestone end, Lead idle)
  scorecard.py show
      print the table

Measured from the Lead's transcript since <ISO> (the milestone's first owner message):
minutes of Lead work, tool calls, denials, errors and owner messages. From the tree: checks the
agent verified ([x] in docs/TESTING.md) and checks still open for a human (human_checks.py).
Given by the trainer: fixes the milestone reviewer made, and human-only blockers (a Studio or
Rojo step, a decision the policy reserves). Run with `python3 -I`.
"""
import datetime, importlib.util, os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.dont_write_bytecode = True  # loading sibling scripts must not leave __pycache__ in the plugin
HEADER = ("| Date | Run | Game | Milestone | Lead min | Tools | Denials | Errors | Owner msgs | "
          "Reviewer fixes | Human blockers | Agent-verified | Open for a human | Agent share |\n"
          "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|\n")
INTRO = ("# AI-suitability scorecard\n\nOne row per milestone (`scripts/scorecard.py record`). The "
         "framework is improving when minutes, denials, errors and human blockers fall and the "
         "agent's share of verified checks rises, across games. Compare rows of like milestones; "
         "one game's row is weak evidence.\n\n")


def scorecard_path():
    """The scorecard is data, not plugin definition: .ledger/scorecard.md at the repo root."""
    root = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True).stdout.strip()
    return os.path.join(root, ".ledger", "scorecard.md")


def load(name):
    spec = importlib.util.spec_from_file_location(name, os.path.join(HERE, f"{name}.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


# A silence longer than this inside one call is a pause (`lead.py stop`, then a resume hours
# later lands the interrupted tool's error at resume time), not Lead work.
IDLE_GAP_MIN = 30


def lead_numbers(since, until=None):
    tr = load("transcript")
    path = tr.find_transcript()
    minutes, tools, denials, errors, prompts = 0.0, 0, 0, 0, 0
    start = end = None
    for ts, kind, detail in tr.events(path):
        if not ts or ts < since or (until and ts > until):
            continue
        if kind == "prompt":
            if start and end:
                minutes += (tr.parse(end) - tr.parse(start)).total_seconds() / 60
            start = end = ts
            # A background task reporting back also resumes the Lead, but isn't the owner.
            prompts += not detail.lstrip().startswith("<task-notification>")
            continue
        if start and end and (tr.parse(ts) - tr.parse(end)).total_seconds() / 60 > IDLE_GAP_MIN:
            minutes += (tr.parse(end) - tr.parse(start)).total_seconds() / 60
            start = ts
        end = ts
        tools += kind == "tool"
        denials += kind == "denial"
        errors += kind == "error"
    if start and end:
        minutes += (tr.parse(end) - tr.parse(start)).total_seconds() / 60
    return round(minutes), tools, denials, errors, prompts


def checks(root):
    testing = os.path.join(root, "docs/TESTING.md")
    verified = len(re.findall(r"^\s*- \[x\]", open(testing).read(), re.M)) if os.path.exists(testing) else 0
    hc = load("human_checks")
    open_items = sum(len(items) for _, items in hc.collect(root))
    return verified, open_items


def record(argv):
    run, milestone = argv[0], argv[1]
    opts = dict(zip(argv[2::2], argv[3::2]))
    since = opts.get("--since") or sys.exit("scorecard.py: --since <ISO> is required")
    root = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True).stdout.strip()
    game = load("human_checks").game_name(root) or "-"
    minutes, tools, denials, errors, prompts = lead_numbers(since, opts.get("--until"))
    verified, open_items = checks(root)
    share = f"{100 * verified // (verified + open_items)}%" if verified + open_items else "-"
    row = (f"| {datetime.date.today()} | {run} | {game} | {milestone} | {minutes} | {tools} | {denials} | "
           f"{errors} | {prompts} | {opts.get('--reviewer-fixes', '-')} | {opts.get('--human-blockers', '-')} | "
           f"{verified} | {open_items} | {share} |\n")
    path = scorecard_path()
    if not os.path.exists(path):
        open(path, "w").write(INTRO + HEADER)
    open(path, "a").write(row)
    print(row, end="")


def main(argv):
    if argv[:1] == ["record"] and len(argv) >= 3:
        record(argv[1:])
    elif argv[:1] == ["show"]:
        path = scorecard_path()
        print(open(path).read() if os.path.exists(path) else "(no scorecard yet)")
    else:
        sys.exit(__doc__.strip().split("\n\n")[1])


if __name__ == "__main__":
    main(sys.argv[1:])
