# Cyberbrawling my way to my love! — Test Matrix, level 1 (v0.1.0, working label)

*Javier & Claude, 2026-11-05. For Javier's play of level 1 (TODO: "Javier plays level 1 with the matrix"). The version
is a working label for the first playable level until Javier names the release; the grey box was v0.0.1.*

How to use it: play in order, write PASS / FAIL / ? in **Result** and anything odd in **Notes** (your own words are
fine, a screenshot is better). Each FAIL becomes a finding, `F-n`, with a GitHub issue and an entry in the results
file. Nothing here needs you to know how the game is built: **EXPECT** says what you should see.

## 0 · Before you play (Claude, done and checked before the session)

| ID | What | Proven by | Result |
|---|---|---|---|
| 0.1 | All automated tests green (419 on 2026-11-05; the count never drops) | `scripts/test.sh` | — |
| 0.2 | The exported game plays level 1 through by itself with no window and says it won | `scripts/export.sh` (its smoke test) | — |
| 0.3 | Install for this user only, no sudo: a `cyberbrawling` command and a menu entry | `scripts/install.sh` on a spare home folder | — |
| 0.4 | The latest build's pictures checked by the testers (the team reviews before Javier, D-22) | the build's review note | — |

## 1 · Install and start

| ID | Task | EXPECT | Result | Notes |
|---|---|---|---|---|
| 1.1 | Run the install (one command, given at the time) | it ends with an `OK` line | | |
| 1.2 | Open the game from the KognogOS launcher | a window with the title "CYBERBRAWLING MY WAY TO MY LOVE!" | | |
| 1.3 | Same, from a terminal: `cyberbrawling` | the same title screen | | |
| 1.4 | The icon in the launcher | a placeholder icon for now (the team's real one comes later) | | |

## 2 · The first screens

| ID | Task | EXPECT | Result | Notes |
|---|---|---|---|---|
| 2.1 | ← → on the title | the choice moves between HIM and HER, marked ▶ ◀ | | |
| 2.2 | A to start | the mode screen: THE GAME · HARDER · BOSS RUSH · HELPER: OFF | | |
| 2.3 | Pick HELPER, press A | it flips to HELPER: ON (and back on a second A) | | |
| 2.4 | Pick THE GAME, press A | the story pages, a line at a time; A goes on, or they go on by themselves | | |
| 2.5 | One press of A | moves on one screen only, never two | | |

## 3 · Moving (arrow keys; W run, X stance)

| ID | Task | EXPECT | Result | Notes |
|---|---|---|---|---|
| 3.1 | ← → | he shuffles left and right in his fighting stance, the feet stay planted between steps | | |
| 3.2 | ↑ ↓ | he steps up and down the street (towards the back and the front) | | |
| 3.3 | Hold W with an arrow | he runs; let go and he settles back | | |
| 3.4 | X | he switches between the fighting stance and the walking stance (standing easy, an everyday walk) | | |
| 3.5 | Walk past a hydrant, a crate, the dumpster, the car | he goes in front of or behind them depending on where he is up or down the street; he doesn't walk through them | | |
| 3.6 | Smoothness: walk, run and switch for a minute | no stutter, no jump in the picture, the pace feels natural | | |

## 4 · Fighting (A punch, S kick, D block, Space jump, Z sweep, C roll)

| ID | Task | EXPECT | Result | Notes |
|---|---|---|---|---|
| 4.1 | A, A, A | jab, cross, power punch (a chain; the third ends with the spare fist pulled to the hip) | | |
| 4.2 | S, S, S | low kick, body kick, side kick to the face | | |
| 4.3 | A, A, S | the push kick (knocks a goon back) | | |
| 4.4 | Hold D | he holds his guard; blows on it do little | | |
| 4.5 | D at the very moment a blow lands | a perfect block: a flash, and it can break the enemy's combo | | |
| 4.6 | Two of your combos in a row on one goon | he goes dizzy; a finisher then lands big | | |
| 4.7 | Space, then A or S in the air | a hammer fist or a flying kick; the landing looks natural (knees tucked, legs out at the last moment) | | |
| 4.8 | Z | the sweep: a low spin, the long leg out | | |
| 4.9 | C | the roll: hand down, over the back, up again; never resting on his head | | |
| 4.10 | Pressing fast | presses during a blow queue up in order; a doubled tap counts once | | |
| 4.11 | From the walking stance, press A | he raises his guard first, then punches | | |

## 5 · Screen 1: the friend, the umbrella

| ID | Task | EXPECT | Result | Notes |
|---|---|---|---|---|
| 5.1 | The sparring friend on screen 1 | he teaches the block, the perfect block and the dizzy finisher; the hints read clearly | | |
| 5.2 | Walk over the umbrella | he picks it up | | |
| 5.3 | Block one blow with the umbrella | it takes one blow, then breaks | | |

## 6 · Neon Row, the street (seven screens)

| ID | Task | EXPECT | Result | Notes |
|---|---|---|---|---|
| 6.1 | First fight | two glow punks from the right | | |
| 6.2 | Second fight | one punk hidden, then more from the left and one from a door as the first go down | | |
| 6.3 | Third fight | a Bruiser and two punks | | |
| 6.4 | The bat lying in the street | walking over it with empty hands picks it up; A swings it; it wears out after a number of hits | | |
| 6.5 | Takeaway and soda | walking over them heals | | |
| 6.6 | Fourth fight | three punks, then a Bruiser with a bat from a door and two more punks as they fall | | |
| 6.7 | Last fight | two punks from a door | | |
| 6.8 | The torn photo near the end | picked up (a collectible) | | |
| 6.9 | The stray cat by the bins on screen 7 | stand by it to feed it; it follows you | | |
| 6.10 | The signs on the walls | readable, nothing cut off | | |
| 6.11 | Getting hit | pain shows on him and on them (bruises, swelling, cracks), never blood | | |
| 6.12 | Crowds | never more than five on him at once; nobody walks back onto a cleared screen | | |
| 6.13 | Lag | none, even with the most enemies on screen | | |

## 7 · The club upstairs: DJ Volt

| ID | Task | EXPECT | Result | Notes |
|---|---|---|---|---|
| 7.1 | The end of the street | he goes up the club's back stairs by himself to the room upstairs | | |
| 7.2 | DJ Volt from range | he throws records like frisbees, low, middle and high: jump the low ones, step up or down the street or roll for the rest; a perfect block sends one back at him | | |
| 7.3 | Close in | he swings the mic stand | | |
| 7.4 | The speakers | hold your guard for about two seconds while his speakers stand and the Bass Drop's wave pushes you back; break the speakers to stop it | | |
| 7.5 | Beat him | the level's won; he drops a bat, the prize | | |
| 7.6 | If you finished without losing any health (the first time only) | NOT A SCRATCH! and three letters to type (↑ ↓ change, A next); they light up in neon on level 2's first screen | | |

## 8 · Lives and saving

| ID | Task | EXPECT | Result | Notes |
|---|---|---|---|---|
| 8.1 | Lose a life | he gets up again with full health where he fell, and the fight goes on | | |
| 8.2 | Lose all three, helper OFF | the level restarts from its start | | |
| 8.3 | Lose all three, helper ON | "ANOTHER LIFE FOR 2,000?" YES gives a life (your score goes down, never below zero); NO loses the level | | |
| 8.4 | Close the window mid-level, open the game again | CONTINUE (level 1) on the title starts you at the start of the level | | |
| 8.5 | Win level 1, close, open again | CONTINUE (level 2) | | |

## 9 · Harder mode (a quick look only)

| ID | Task | EXPECT | Result | Notes |
|---|---|---|---|---|
| 9.1 | New game, HARDER | the same level; DJ Volt has a quarter more health and a shorter warning flash | | |

## 10 · The G13 (F-1 from the grey box, still waiting on your re-try)

| ID | Task | EXPECT | Result | Notes |
|---|---|---|---|---|
| 10.1 | Play with the Logitech G13 plugged in | the hero stands still until you move him; he never walks left by himself | | |

## 11 · Uninstall

| ID | Task | EXPECT | Result | Notes |
|---|---|---|---|---|
| 11.1 | Run the uninstall (one command, given at the time) | ends with `OK`; the menu entry and the `cyberbrawling` command are gone | | |
| 11.2 | Your save | kept unless you ask for it to go (it lives in the game's own folder) | | |

## Not in this matrix, on purpose

- The score on screen: off until your yes (`SHOW_SCORE`).
- A pause key, the throw and switch keys, the pad buttons for the sweep and the roll: waiting on your pick.
- Sounds: none yet (the team's batch drops straight in when it lands).
- Art: grey-box shapes; the real art comes after your pick of a direction.
- Levels 2-10: their own matrices.
