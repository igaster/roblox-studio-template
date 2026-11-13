# Blind reviewer prompt

The trainer sends this to a **fresh** subagent at each milestone end, filling in the paths. The
subagent gets no conversation, no trainer notes and no run record: only raw evidence. Its job is
a second opinion the trainer can't anchor.

---

You are reviewing how a game-development **framework** performed for an AI agent (the "Lead")
that just built one milestone of a Roblox game with it. Review the framework, not the game.
The framework is the repo root `{ROOT}` (its `CLAUDE.md` describes the layout): `CLAUDE.md`,
the skills, agents, commands and hooks in `plugins/roblox-framework/`, the shared modules in
`src/shared/`, the doc templates in `docs/design/templates/`, the starter game `template/`,
and the tooling (`scripts/`, `tests/`). The game is `{GAME_DIR}`, its own folder; the Lead
works there and reaches the framework at `../../`.

Read only these:
- Transcript digest (one line per tool call, skill load, error, denial and Lead message):
  `{DIGEST}`
- The Lead's own friction log: `{GAME_DIR}/FRAMEWORK_FEEDBACK.md` (this milestone's entries
  are the last ones)
- Framework files the Lead edited: `{FRAMEWORK_DIFF}` (empty means none)
- The milestone's result: `{MILESTONE_FILE}` (its *Result* section)
- The owner's messages to the Lead, in order: `{MESSAGES_DIR}`
- The owner's policy: `{SCENARIO}`
- The framework itself, whenever you need to check what it says.

Don't read `.ledger/`, `.training/` (beyond the policy file above), `plugins/roblox-trainer/`
or anything else the trainer wrote: the point is an opinion formed without them. Read only;
don't edit any file.

## Part 1: framework findings

Where did the framework fail, mislead or slow the Lead down? Look for:
- time lost (long waits, retries, loops), with minutes from the digest timestamps;
- denials and errors, and what the Lead was trying to do;
- skills that should have loaded and didn't, or loaded late;
- conventions the Lead invented that the framework should have provided;
- rules the Lead broke without knowing, or followed and still failed;
- what needed a human, and whether an agent could have done it with better tooling.

Also list what **worked**: a framework rule or tool that clearly saved time or caught a bug.

For each finding: severity (High / Medium / Low), the evidence (digest timestamp, feedback
entry or file), and the smallest framework change that would have prevented it.

## Part 2: owner-proxy audit

The owner's messages were written by an agent answering for the owner from the policy file.
Check every message against the policy:
- **Leaks:** does any message hint that the Lead is being trained or evaluated, or mention
  the framework, a ledger, a review of the Lead, or `.training/`? (The milestone wrap-up
  "note anything that slowed you down…" is a standard owner line, not a leak.)
- **Invented preferences:** does any message state a preference the policy doesn't, or nudge
  a decision the policy leaves to the Lead ("your call")?
- **Overreach:** did it approve something the policy reserves for the maintainer (Robux, a
  published place, monetization, a lobby, trading)?
- **Under-answering:** did it send a question back as "your call" that the policy did cover?

Quote the message and the policy line for each issue. "No issues" is a valid answer.

## Output

Two sections, *Framework findings* (ranked, then *Worked*) and *Owner-proxy audit*. Be
concrete and short. Don't propose game changes.
