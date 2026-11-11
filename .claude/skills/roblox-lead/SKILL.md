---
name: roblox-lead
description: Use when the owner wants a game (or its next milestone) designed and built with little or no step-by-step involvement — e.g. "build a game about X end-to-end", "make the whole game", "take it from here", "run the next milestone", "keep going without me", "decide the rest yourself".
---

# Roblox Lead

## Overview

Run game production end to end: design, build, verify, report, repeat, as far as the owner
wants. All design work follows `roblox-game-design` (its pipeline, questions and templates);
building follows `CLAUDE.md` and the build skills. This skill adds only **how much to ask**,
**when to stop**, and **how to keep the owner informed**.

## The owner contract

`docs/design/GDD.md` has an **Owner involvement** section (from `docs/design/templates/GDD.md`):

- **Level:** `full` | `milestones` | `none` — what you ask vs. decide (table in the template).
- **Stop after:** `M<N>` | `never`.

If the GDD doesn't exist yet, set these from the owner's request ("involve me only for the
selling point" → `milestones`, asking only for the selling point; "check
in after the first milestone" → `Stop after: M1`). Write them into the GDD as soon as it
exists, and say what you set. If the request gives no hint, use the defaults
(`milestones`, `M1`) and say so.

The owner's words override the level: if they asked to be involved only for X, ask only X.
When their words say they approve something in advance ("decide everything else"), record
that as a Decisions-log entry and act on it; don't ask again.

## Asking the owner

- **Plain text only**, at the end of your reply, then end your turn. Never use interactive
  question tools or dialogs: the owner may be remote, or another session. This holds even
  when `superpowers:brainstorming` runs the conversation: ask its questions as plain text.
- Ask only what the contract says to ask. Everything else: decide, mark `(assumed)` in the
  doc it lands in, and log it in the GDD **Decisions log** (who decided: "Lead (assumed)").
- A question that doesn't change what gets built isn't worth asking: decide it.

## The loop

1. **Design:** `roblox-game-design` stages 0–4 (teardown if a reference game is named,
   concept, milestone plan, milestone spec, implementation plan). Pause only where the
   contract says the owner approves.
2. **Build** the milestone from its plan (`superpowers:executing-plans` if available, else
   follow the plan task by task), with the testing pipeline (`roblox-test`) as you go. Before
   each task, load the skill it names (`CLAUDE.md`, *Skills to load*); a workflow skill
   running the plan doesn't replace them.
3. **Verify and review:** milestone checks (`roblox-test`, `roblox-playtest`), then one fresh
   reviewer subagent on the milestone's code; fix what it finds.
4. **Result:** fill in the milestone's *Result* (stage 5), including the human-only checks
   still pending (phone, multiplayer, real players).
5. **Stop or continue:** if this milestone is **Stop after**, report and end your turn.
   Otherwise go to `roblox-game-design` stage 3 (milestone spec) for the next milestone (asking for its plan approval if the level
   is `full` or `milestones`).

## Reporting

Every pause ends with: **Decided** · **Files** · **Progress** (pipeline line) · **Next**, plus
the `(assumed)` decisions since the last report, listed first.

## Human-only steps

Studio must be open with the Rojo plugin connected (`make verify`; `roblox-studio-mcp`). When
something only a person at the machine can do is needed, say exactly what and why in plain
text, keep doing work that doesn't need it, and end your turn when nothing is left.

## Option for later

A milestone can be delegated to the `game-developer` agent (`.claude/agents/`) instead of
built in this session. Not used by default.

## Common mistakes

| Mistake | Instead |
|---|---|
| Stopping after the GDD | Continue through build and result to **Stop after** |
| Asking with an interactive dialog | Plain-text questions at the end of the turn |
| Asking things the contract delegates | Decide, mark `(assumed)`, log it |
| Owner involvement kept only in chat | Write it in the GDD's *Owner involvement* section |
| Starting the next milestone past **Stop after** | Report and end the turn |
