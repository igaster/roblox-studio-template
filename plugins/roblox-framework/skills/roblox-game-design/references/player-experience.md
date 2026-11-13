# Player Experience Principles

Short reference for design-session steps 1–3. Use these to ask better questions,
not to lecture the creator.

## Fantasy and pillars

- **Fantasy**: the one-sentence promise ("run a ramen shop that becomes an empire",
  "outrun your friends down a collapsing mountain"). If the fantasy is vague, every
  later decision will be too.
- **Pillars**: 2–4 statements, each with a consequence:
  "Quick to pick up → no tutorial screens; the first stage *is* the tutorial."
  A pillar that never rejects a feature isn't doing its job.

## Core loop at three timescales

| Timescale | Question | Example (obby) |
|---|---|---|
| ~30 s | What does the player *do* over and over? | Jump a section, hit a checkpoint |
| 5–10 min | What goal does a session complete? | Finish a stage, beat a friend's time |
| Days | Why come back? | New stages, leaderboard position, cosmetics |

The 30-second action must be satisfying with zero progression attached. If it's only
fun because numbers go up, the loop is fragile.

## Motivation (MDA, needs)

- **MDA**: you design *mechanics*; players experience *dynamics* (what happens when
  rules meet players) and *aesthetics* (the feeling). Start from the feeling you want
  and work backward.
- Players stay for **competence** (getting better), **autonomy** (meaningful
  choices), and **relatedness** (other people). Ask which one the game leans on.

## Flow and difficulty

- Challenge should rise roughly with skill: too easy is boring, too hard is quitting.
- Failure should be fast and cheap to retry. Long walks back after failing kill flow.
- Alternate tension and rest: a hard section, then a breather or reward.

## Feedback

Every player action gets an immediate response: sound, motion, particles, a number
popping up. Missing feedback is the most common reason a mechanic "feels off" when the
logic is correct. Check feedback before rebalancing.

## Prove the fun first

M1 is a **greybox prototype** of the 30-second loop: primitive parts, placeholder UI,
one of each thing. Playtest it. If it isn't fun yet, adding content, progression or
monetization won't fix it. Iterate on the loop first.
