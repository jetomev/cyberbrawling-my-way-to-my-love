# The game — design

*As Javier approved it on 2026-11-01. Javier & Claude. Changes to this file are decisions: they get a D-number in
`CLAUDE.md` and Javier's words.*

## What it is
A side-scrolling brawler for Linux, our own from the first line. It is part of KognogOS and ships with KognogOS 1.0
(the week of 19 April 2027). Public and open source.

It is **not** a remake of anything. No material, names, characters, levels or code from any existing game.

## The story
The mob kidnaps the hero's girlfriend or boyfriend. At the start you choose your hero: **a man or a woman**. The game
is the rescue, level by level, up to the mob's boss.

## The look
- **Neon and fun at the start, darker and grittier as you go.** Level 1 is bright signs and wet streets at night;
  by level 10 the colour has drained to rust, smoke and red light.
- **Simple, attractive 2D art with a slight 3D feel**, on **flat backgrounds**. The 3D feel comes from shading
  painted into each part and from depth between layers, not from 3D models.
- **Characters are cut-out parts moved by the engine** (head, torso, arms, hands, legs, feet, each its own picture,
  jointed like a paper puppet). That keeps every character consistent from every angle the game uses, keeps the
  motion smooth, and keeps a weapon locked in the hand.

## The levels
| Levels | Floors | What's new | Boss |
|---|---|---|---|
| 1–2 | one floor | the street; the boss waits on a second floor | at the end of each, upstairs |
| 3–5 | two floors | moving between floors | level 5 |
| 6–8 | up to three | switches upstairs open doors below | level 8 |
| 9 | *open question* | — | — |
| 10 | — | the super boss, who needs the best weapon | the super boss |

## Pain, not blood
**No blood, anywhere.** But every fight has to hurt, on **both sides**, hero and enemies (Javier, 2026-11-01):
- **Seen:** bruises, black eyes, swollen mouths, an arm or a leg that breaks and hangs, a limp.
- **Heard:** screams, grunts, cracks of bone, the thud of a pipe.
- **Built in:** each cut-out part has damage stages (fresh → bruised → swollen → broken) that the game swaps in as
  health drops. A broken arm can't swing a weapon; a broken leg slows you down. The hero carries the damage into the
  boss fight; it heals between levels.

## Fighting
- **Melee weapons only:** bats, pipes, wrenches, sticks, knives, swords. No guns.
- Weapons are **taken from enemies**. You **collect** them and **switch** between them.
- **Moves:** jump, flying kicks, climb onto objects and get down from them.
- **Obstacles are smashed or jumped. You never walk through one.**

## The street, in layers
- Fast foreground props, the play lane, a slow background (parallax: nearer things slide past faster).
- Cars, posts and containers sit on **their own layers**: you pass in front of some and behind others.

## Sound and controls
- Original music and sound effects.
- Keyboard and gamepad. Linux.

## Open questions (Claude's recommendation in brackets; Javier decides)
1. **Level 9.** The spec names 1–8 and 10. [A gauntlet up the boss's tower: three floors, no new mechanic, the
   hardest regular fights, and the best weapon found here, so level 10 is the payoff.]
2. **How deep is the play lane?** A flat line (you only go left, right and up onto things), or a shallow street you
   can also step up and down in, the way classic arcade brawlers work. [The shallow street: it makes "in front of /
   behind" natural and lets enemies surround you. The grey-box build tries both so Javier can feel the difference.]
3. **One hit or a health bar?** [A health bar with food or first-aid pickups; weapons break after a number of hits
   so collecting matters.]
4. **Lives and saving.** [Save at the start of every level; three lives per level.]
5. **Two players on one screen?** [Not for 1.0. The code keeps the door open.]
6. ~~The name~~ — decided: **"Cyberbrawling my way to my love!"** (Javier, 2026-11-01).
