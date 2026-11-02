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
| 9 | three | the tower gauntlet: hardest regular fights, the best weapon | — |
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

### Combos (D-18, Javier 2026-11-01: "make combos to make fights fun… FUN!")
Three presses in quick succession chain into a finisher. Once a blow ends, the next press has a short window
(24 ticks, 0.4 s; a feel-lab setting) to continue the chain; miss it and the chain starts over. Presses made during a
blow wait their turn, in order, so a rhythm of taps chains naturally; a doubled tap (two presses within 3 ticks)
counts once. The table lives in `game/scripts/sim/moves.gd`.

| Presses | Moves | The finisher |
|---|---|---|
| P, P, P | jab, cross, hook | staggers |
| P, P, K | jab, cross, push kick | pushes away, makes space |
| P, K, P | jab, knee, uppercut | launches |
| K, K, K | front kick, body kick, spinning kick to the head | knocks down |
| K, P, K | front kick, elbow, roundhouse | staggers |
| jump + K | flying kick | — |
| jump + P | hammer fist | — |

The team's starter list opened K,K,K with a low kick and K,P,K with a front kick. The first press can't know which
chain follows, so both open with the front kick.

### Blocks, enemy combos, counters (D-19, Javier 2026-11-01, 23:00)
> "Please include blocks too. Enemies should have combos too, and depending on the type kick/punch and early block
> they can be stopped and disarm them, and give chance for our combos to hit. Hitting enemies with two consecutive
> combos can lead them to get dizzy opening time for a third and final combo, and stuff like that. Each enemy have
> different combos, and anti-combos, same as bosses which have different combinations and ways to kill."

- **Block (built):** hold the block button (L or Shift; pad Y or RB). The hero covers up and stands his ground; he
  can turn to face a threat, and a punch or kick comes straight out of the guard. The first moments of a block
  (8 ticks, a feel-lab setting) are a **perfect block**, shown by a flash.
- **With enemies (to build):** enemies throw their own combos. The right punch or kick, or a perfect block,
  **interrupts** an enemy's combo and can **disarm** him: his weapon drops to the floor and can be picked up, and he
  is open for the hero's combo. A plain block takes less pain than a clean hit. **Two hero combos in a row** on one
  enemy make him **dizzy** for a short time: the window for a third, finishing combo.
- **Each enemy type and each boss** has its own combos, its own counters to the hero's combos ("anti-combos") and its
  own way to be beaten. The assistant team is writing the full table (hero combos, each enemy's combos, counters, weak
  spots, bosses); it reaches the game through Javier.

**Still to come, with weapons:** W, W, W = swing, backswing, overhead smash (wears the weapon faster); W, P, K mixes;
a **throw** sends the held weapon at a far enemy, it lands where it stops and can be picked up again; **each weapon
feels different** (knife fast and short, sword a wide sweep, bat big knockback, pipe and wrench heavy). What the
finishers do (stagger, knockdown, launch, push) shows on enemies once they exist; pain on body parts, never blood
(D-9).

## The street, in layers
- Fast foreground props, the play lane, a slow background (parallax: nearer things slide past faster).
- Cars, posts and containers sit on **their own layers**: you pass in front of some and behind others.

## Sound and controls
- Original music and sound effects.
- Keyboard and gamepad. Linux.

## Answered (Javier, 2026-11-01; decisions D-12 to D-16 in CLAUDE.md)
1. **Level 9: the tower gauntlet.** Up the boss's tower: three floors, no new mechanic, the hardest regular fights,
   and the best weapon is found here, so level 10 is the payoff.
2. **Movement: a shallow street.** Left and right plus a few steps up and down the street, the way classic arcade
   brawlers work: enemies can surround you, and passing in front of or behind props comes naturally. The grey box
   also builds the flat line, so Javier can feel the difference before it's locked.
3. **Health: a bar.** Food and first-aid kits refill it. Weapons wear out after a number of hits, so collecting
   them matters.
4. **Lives and saving:** the game saves at the start of every level; three lives per level; losing them restarts
   that level, not the game.
5. **Two players: not in 1.0.** The code keeps the door open for a second player after launch.
6. ~~The name~~ — decided: **"Cyberbrawling my way to my love!"** (Javier, 2026-11-01).
