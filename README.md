# Cyberbrawling my way to my love!

A side-scrolling street brawler for Linux. The mob has taken the one you love; you fight your way through ten levels
of neon streets, rooftops and warehouses to get them back. Pick up whatever the thugs drop — bats, pipes, wrenches,
sticks, knives, swords — keep it, switch between what you've collected, and save the best for the last fight.

It starts bright, neon and fun, and gets darker and grittier the deeper you go.

> **Status: Stage 1, the feel in grey boxes (2026-11-02).** A grey hero built from cut-out parts on 21 bones (spine,
> neck, shoulders, fists and open hands, feet that plant, toes) stands in a low fighting stance, shuffles, switches to
> an everyday walk, runs, jumps, punches, kicks and flying-kicks, blocks, and chains three-hit **combos** into
> finishers (jab, cross, power punch; low kick, body kick, side kick to the face; and more); kicks smash crates; cars
> are climbed and jumped off; nothing is ever walked through. The jump, the flying kick, the walk and the guard are
> drawn from measurements of recorded human motion; the punches and kicks are next. A feel lab (F1) changes the feel
> while you play. No enemies yet, no art yet.
> First level playable: mid-December 2026. Whole game: by 21 March 2027 at the latest. It ships with **KognogOS 1.0** (April 2027).

| | |
|---|---|
| Runs on | Linux (any distribution; developed on KognogOS / Arch) |
| Desktop | any (X11 or Wayland) |
| Works on a tty | no (it is a graphical game) |
| Engine | Godot 4 |
| Controls | keyboard and gamepad |
| Licence | code GPL-3.0-or-later · art, music and sound CC BY-SA 4.0 |

## The game
- **Choose your hero:** a man or a woman. The mob kidnaps their partner; the rest is the rescue.
- **Ten levels**, growing upward as you go:
  - Levels 1–2: one floor, with the boss waiting upstairs.
  - Levels 3–5: two floors; a boss at level 5.
  - Levels 6–8: up to three floors, with switches that open doors below; a boss at level 8.
  - Level 9: the tower gauntlet, three floors up the boss's tower, the hardest fights, and the best weapon.
  - Level 10: the super boss, who can only be beaten with the best weapon in the game.
- **Melee only.** Every weapon is taken from an enemy. You collect them and switch between them.
- **Moves:** punches, kicks, jumps, flying kicks; climb onto cars, crates and containers and jump off them.
  Obstacles are smashed or jumped — you never walk through them.
- **Layered streets:** fast props in the foreground, the street you fight on, and a slow skyline behind. Cars,
  posts and containers each sit on their own layer, so you pass in front of some and behind others.
- **The look:** simple, bold 2D art with a slight 3D feel and flat painted backgrounds. Characters are built from
  cut-out parts the game moves itself, so every frame is consistent and smooth, and the weapon is always in hand.
- **No blood, but it hurts:** bruises, black eyes, swollen mouths, broken arms and legs, screams and cracks, on
  the hero and the enemies alike.
- Music and sound effects, all original.

## How it is made
- `docs/DESIGN.md` — the game as Javier approved it, with his answers to its open questions.
- `docs/PLAN.md` — the engine, the art pipeline, the milestones and the quality bar.
- `docs/LESSONS.md` — what our previous game project taught us, and what we do differently because of it.
- `docs/UNATTENDED.md` — how work keeps moving on weekdays, and what always waits for Javier.
- `game/` — the Godot 4 project. `scripts/test.sh` runs its tests headless, inside a memory and CPU fence with a
  time limit, logs to `logs/`, and fails if the number of tests ever drops below `game/tests/FLOOR`.
- `scripts/play.sh` plays it in a window (keyboard: the arrows move, A punch, B kick, hold D to block, hold W to run,
  X switches between the fight stance and the walk stance, Space jump, Z the sweep (coming); gamepad: stick or d-pad, X punch, B kick,
  A jump, hold Y or RB to block, hold LB to run, click the left stick to switch stance). **F1 opens the feel lab**: change walk and run speed, jump, punch and kick timing and more
  while you play; F8 saves your changes for next time. `scripts/record.sh` records the scripted demo to a contact
  sheet and a clip.
- `scripts/build.sh` is a build: the tests, the recorded demo, stills, close-ups and timed strips of every move,
  moving clips at full and half speed, the hero side by side with the recorded motion, and a note, handed to the
  reviewers first.
- `TODO.md` — the live list.
- `docs/schedule.json` — the timeline: every task's dates and the gates where Javier plays it; `scripts/gantt.py`
  turns it and the TODO ticks into the Gantt page.

## Roadmap
| Date | Milestone |
|---|---|
| Sun 22 Nov 2026 | The feel, in grey boxes: hero, moves, one enemy, the layers, keyboard + gamepad |
| Sun 29 Nov 2026 | The look locked: hero (both), first enemies, level 1 street |
| **Sun 13 Dec 2026** | **Level 1 playable**, with art, music and sound |
| Sun 31 Jan 2027 | Levels 2–5 (two floors, the level 5 boss), weapon collection and switching, the story opening |
| Sun 28 Feb 2027 | Levels 6–9 (three floors, switches and doors, the level 8 boss), the darker look |
| Sun 14 Mar 2027 | Level 10, the super boss, the endings: the whole game |
| **Sun 21 Mar 2027** | **Finished**: full playthrough, every finding fixed, packaged |
| Week of 19 Apr 2027 | Ships with KognogOS 1.0 |

## Thanks
To everyone who made the side-scrolling brawlers of the arcades and the living room, and to the Godot community for
an engine anyone can build with.

The hero's movement is drawn by hand from measurements of recorded human motion: "The data used in this project was
obtained from mocap.cs.cmu.edu. The database was created with funding from NSF EIA-0196217." Thank you, Carnegie
Mellon University. The recordings themselves are not part of this game or this repository.

The jumping kicks' timing and shapes were also studied (only watched and measured, nothing copied) from "Wushu
Basics" by Atoomenergie, on Wikimedia Commons under CC BY-SA 3.0
(https://commons.wikimedia.org/wiki/File:Wushu_Basics.ogv). Thank you.

Made by Javier and Claude, a human and an AI building together.
