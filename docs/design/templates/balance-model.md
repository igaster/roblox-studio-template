# Balance Model

> Optional (see the `game-modeling` skill). Status: level <1–4>, last validated <date>.

## Questions it answers
- <e.g. when can a player afford the second upgrade?>

## Layers
| Layer | File | What it is |
|---|---|---|
| Parameters | `GameConfig` | Every gameplay number |
| Formulas | `Modules/*Math.lua` | Pure functions the live game uses |
| Simulation | `tests/sim/…` | Step-by-step session with a scripted player (say which: optimizing or plain) |
| Model | `tests/sim/…` | Closed-form prediction |

Tools:
- `lune run tests/sim/<tool>.lua`: <what it prints>

## Parameters
| Symbol | Config key | Meaning |
|---|---|---|
| | | |

## Formulas
<Each formula with its parameters. Name fitted constants as calibration.>

## How far to trust it (validated <date>)
| Check | Result |
|---|---|
| Measures compared, and tolerance | |
| Sensitivity: changes, not responding, opposite direction | |
| Replay on the real code | not run |
| Scripted player in the live game | not run |
| Step sizes the live game uses | not run |
| Real players | not run |

**Valid for**: <questions it can answer>
**Not valid for**: <questions it can't>

## Not modeled
| Mechanic | Questions left unanswered |
|---|---|
| | |

## Current reading
<What the numbers say today, measured against the design targets, with the date.>
