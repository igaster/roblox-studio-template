---
name: roblox-game-teardown
description: Use when the creator names an existing Roblox game as inspiration ("a game like X"), asks why a game is successful, or wants to study a competitor or genre leader before designing a game, milestone or system.
---

# Roblox Game Teardown

## Overview

Analyze an existing game to learn **why it works**, so the creator's game can keep
what players expect from the genre and differ where it matters. The output is an
analysis document, never a plan to recreate the game.

You can't play the game. Your evidence is what the creator has seen and what is
public. A shallow teardown with clear sources beats a confident one with guessed numbers.

## Sources, in order

1. **The creator's own play experience. Ask first.** What hooked you? Where did you get
   bored or quit? What did you (or friends) spend Robux on? What annoyed you?
   Screenshots welcome.
2. **Public information:** the experience page (description, update notes, game passes
   and developer products listed), the game's wiki, DevForum posts, update logs, video
   titles and descriptions. Use web search/fetch. For a broad search, run it in a
   subagent and keep only the findings.
3. **Inference** from genre knowledge (`roblox-game-design` → `references/genres.md`).

## Evidence labels (required)

Every claim in the teardown carries one label:

- `[verified](link)`: an official source (the experience page, the developer's own
  posts or update logs, Roblox) or reputable press.
- `[guide](link)`: a fan wiki, guide or tips site. Useful for mechanics details, but may
  be outdated, wrong, or describe a sequel or a different version.
- `[creator]`: from the creator's play notes.
- `[inferred]`: your reasoning. Say what it's based on.

Never state player counts, revenue or retention figures without a linked source and the
date seen. If they aren't public, write "not public". When `[guide]` and `[verified]`
disagree, the `[verified]` source wins; note the conflict.

## Process

1. Ask for the creator's play notes (source 1). Don't wait on them to start the public
   research, but don't finish without them.
2. Research public sources (source 2).
3. Write `docs/design/references/<GameName>.md` from
   `../../docs/design/templates/reference-teardown.md`.
4. Return a short summary (≤10 lines) to the design session: the 2–3 load-bearing
   reasons it works, the conventions to keep, and the best "like X, but Y" openings.
   The design session then asks the creator to choose Y (`roblox-game-design`, stage 0).

## Analyze, don't recreate

Genre conventions are shared: plant-grow-sell, checkpoints, rebirths, tower placement.
The reference's **identity** is not: its name, characters, art, look, specific items,
levels, maps, lore, UI layout and music. The *Keep / Change / Don't copy* table in the
template makes this explicit. Every "Don't copy" row must be named.

## Common mistakes

| Mistake | Instead |
|---|---|
| Listing the reference's features as a to-do list | Explain *why* each one works, then decide keep/change |
| Numbers from memory ("~1M players") | Linked source + date, or "not public" |
| Skipping the creator's play notes | Ask first; they're the richest source |
| "Change" column empty | A game with nothing different has no reason to exist next to the original |
| Analysing only the core loop | Also the first 60 seconds, retention, social and monetization |
