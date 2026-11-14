# M<N> implementation plan: <Name>

> Copy to `docs/design/milestones/M<N>-<name>-plan.md`. Written in `roblox-game-design`, stage 4
> (*Build handoff*). Spec: [M<N>-<name>.md](M<N>-<name>.md); features:
> [<Name>](../features/<Name>.md).

**Status:** draft / approved by <owner or Lead `(assumed)`> <date> (`decisions/<NNNN>`) /
building to CP<n> / done.

Checkpoints: **CP1** after task <a>, **CP2** after task <b>, … (M<N> done at the last one).
At each checkpoint: run the checks below, update `docs/STATUS.md`, tick the boxes, check in
with the owner if the GDD's *Owner involvement* asks for it, then start a new chat.

## Rules for every task

- Pure logic goes in `*Math` modules (Lune, dependency-free); every number goes in `GameConfig`
  (plain values).
- Edit files with the Edit tool.
- Testing: Tier 1 (`make test`) after every logic change; Tier 2 once per checkpoint, in a
  fresh Play session; a balance run once per checkpoint if the milestone touches numbers.
- Placeholders until the polish milestones (`milestone-catalog.md`, G1 and G7): plain UI
  through one layout helper, greybox looks, and every sound a key in the `Sounds` config table
  with an empty id; nothing hardcoded that a later pass would have to hunt down.
- Each task fits one chat (about 150 tool calls at most); split it if it won't.
- A task's *Files* list is a checklist, ticked as each item lands, so an interrupted task can
  resume from the plan. Tick a box only for work that exists.
- Add rules specific to this milestone here.

## Task 1: <Name>
- **Skills:** `roblox-test` (and any other the task needs: see `CLAUDE.md`, *Skills to load*)
- **Files:**
  - [ ] `GameConfig.<Key>`
  - [ ] `Modules/<X>Math.lua`
  - [ ] `tests/specs/<X>.spec.lua`: criteria IDs in the test names
- **Satisfies:** <Feature>-AC1, AC2.
- **Result (<date>):** Tier 1 <passed>/<failed>. What differed from the plan, and why. (Filled in
  when the task is done; leave empty before.)

## Task 2: <Name>
- **Skills:**
- **Files:**
  - [ ]
- **Satisfies:**
- **Result:**

## Closing the milestone

- [ ] Every acceptance criterion has a check (named by its ID) and evidence in the spec's
  *Result*.
- [ ] No open box in this plan on a milestone marked done: finish it, or move it to the next
  milestone or the backlog and say so here.
- [ ] `docs/TESTING.md` section, `docs/STATUS.md` (incl. *Deferred checks*) and the GDD
  *Milestones* row are current.
- [ ] Any gap found in the framework's mock store this milestone is fixed there, with a
  `StoreContract` case (`framework:` commit), not worked around in the game.
