# Art and sound brief for the assistant team

*Javier & Claude, 2026-11-03. Javier: the team designs and makes the pieces; Claude builds them into the game (D-11).
This is the list of what the game needs, how each piece must come, and where it goes. The look is `docs/STYLE.md`;
the words for ChatGPT are `docs/PROMPTS.md`; the three free style frames are on the Dailies page (link in `.dailies`).*

**Who organizes it:** the team's chief of staff (Javier, 2026-11-03: the team's own organizer runs the team), who
decides who makes what, keeps the order below, and is the one point of contact for batches and questions.

## The rules that don't bend
- **Money:** only Javier's existing subscriptions (ChatGPT Plus). Anything paid on top (Suno, OpenArt, Runway, a
  sound library) waits for his own yes, with the cost written first.
- **Ours only:** nothing copied or imitated from an existing game, film, artist or brand. No real logos or brand names.
- **No blood, ever** (D-9). Pain shows as bruises, swelling, a broken limb; it's heard as grunts, screams, cracks.
- **Licences:** generated or our own work only; anything from outside must be CC0 or CC BY, its source written down.
- **Count and cost:** every batch comes with a note saying what it is, how many pictures or sounds, what tool, and
  what it cost (even "$0, ChatGPT Plus").

## How a piece must come
- **Pictures:** PNG, on a flat `#00ff00` green wherever it's see-through (Claude cuts the green out), side-on, no
  perspective, the fighter facing right. One fighter's sheets all at the same scale: the whole body would stand
  1,100 px tall.
- **Sounds:** Ogg Vorbis or WAV, 48 kHz. Music loops cleanly (the end runs straight into the start).
- **Where:** `~/Documents/Cyberbrawling/art-in/YYYY-MM-DD-<batch>/`, with a `note.md` (what, count, tool, cost, any
  source and licence). Claude takes it from there: cuts, cleans, rigs, puts it in the game, and every build shows it.

## What the game needs, in order
1. **The style.** The direction from the three style frames (A neon ink, B soft glow, C grit comic): Javier's pick if
   he makes it; otherwise the team's call, written in the batch note. Then ChatGPT's own style frames in it (Batch 1 of
   `docs/PROMPTS.md`, 6 pictures).
2. **The fighters, as cut-out parts.** Each part its own piece with a rounded overlap at the joint, near side and far
   side (the far side a little darker): head (with the face), neck, chest, belly, hips, upper arm, forearm, a fist and
   an open hand, thigh, shin, foot, toes. Four sheets per fighter: fresh, bruised, swollen, broken.
   - the hero, a man · the hero, a woman (you choose at the start) · the thug (big, tank top, a pipe) · the knife
     fighter (lean, hoodie) · later: the other enemy types and the bosses, one level at a time
3. **The weapons and props, each alone:** pipe, bat, knife, sword, wrench, stick; crate (whole and broken), car,
   dumpster, barrier, lamppost, fire hydrant; food (a takeaway box, a soda) and a first-aid kit.
4. **Level 1, Neon Row, in six layers** (`docs/STYLE.md`, The layers): sky, far skyline, the block across the street,
   the shopfronts behind the fighters, the street itself, the foreground. Tiles 2048 × 1080 whose left and right edges
   join. Then the boss's upstairs room.
5. **Sound.** Voices for each fighter (grunts on a blow, a shout on a finisher, pain on a hit, a scream on a break;
   no words), hit sounds per weapon, a bone crack, the crowd and the city at night. Music: level 1's cue (a free draft
   is on the Dailies page to build on or replace), then one per level, darker as the levels go, a boss cue, a title.
6. **The game's icon**, 256 × 256 PNG, for the menu (a stand-in neon "CB" is in `packaging/icon-placeholder.svg`).
7. **Then levels 2 to 10**, the same way: the layers, the new enemies and the boss for each (`docs/DESIGN.md`).

## What Claude does with it
Cuts and cleans every piece, rigs the parts on the fighters' bones, lays in the layers, wires the sounds to the
moves, and keeps building the game meanwhile (pain, weapons, the levels, the bosses). The testers see each piece in the
next build. Pieces that don't fit (wrong scale, a seam, a gap at a joint) go back with a note saying exactly what.
