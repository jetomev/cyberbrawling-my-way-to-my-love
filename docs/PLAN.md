# The plan

*Written 2026-11-01. Javier & Claude. Plain words first; the details under each heading.*

## In one paragraph
We build it in **Godot 4** (already on this PC through nog, version 4.7.2). The feel comes first, with grey boxes in
place of art, until Javier says it plays right. Then the look: pictures made on **ChatGPT** first, cut into parts and
layers, approved by Javier on the Dailies page. Level 1 is playable by **Sun 13 Dec 2026**; the whole game is done by
**Sun 21 Mar 2027**, four weeks before KognogOS 1.0 ships. Every piece goes through the same five steps: design it,
prove it small, build it, test it, fix what the test found.

## The engine: Godot 4
- **Why:** it is free and open source (fits a public KognogOS game), it exports a native Linux build, we already
  know it from Karatecation, and its 2D tools cover everything this game needs out of the box:
  - **Cut-out characters:** `Skeleton2D` + `Bone2D` with each body part as its own picture. Animations are poses on
    the bones, blended smoothly. A weapon is a child of the hand bone, so it can never slip out of the hand.
  - **Layers:** `Parallax2D` for foreground props, the play lane and the skyline, each scrolling at its own speed.
  - **In front / behind:** y-sorting puts each prop and fighter at the right depth automatically.
  - **Gamepad and keyboard:** Godot's input map, with a dead zone on every stick (lesson L-6).
- **Installed from:** `nog` (godot, plus export templates). Anything missing is a finding against KognogOS.
- **Every Godot run is fenced** (`scripts/capped.sh` + `timeout`, lesson L-5). Tests run headless.
- **Output:** a Linux build; later an AUR package and a KognogOS launcher entry.

## The art pipeline
1. **Style first.** Claude writes the style sheet (`docs/STYLE.md`): palette per level (neon → grit), line weight,
   shading, how much 3D feel. ChatGPT makes 3–4 style frames; Javier picks one. That frame is attached to every
   later prompt so the whole game matches.
2. **Characters as parts sheets.** Each character is drawn once, side-on, as separate parts on a flat background
   (head, torso, upper arm, forearm, hand, thigh, shin, foot), plus each weapon. Claude cuts, cleans and rigs them.
   Every part also gets its **damage stages** (bruised, swollen, broken) for the pain system — **never blood**.
3. **Backgrounds flat and side-on, in layers from the start** (lesson L-3): skyline, buildings, the street, near
   props. Cars, posts, containers as separate pictures so they can sit on their own layer.
4. **ChatGPT first, always.** It's inside Javier's existing subscription, so no extra cost.
5. **OpenArt or Runway only with Javier's yes, per batch**: Claude writes what the batch is for, how many images,
   and the expected credits; after the run, what it actually cost (lesson L-4). No standing budget.
6. **Every asset goes on the Dailies page** for Javier's pick before it goes in the game (lesson L-9).
7. **Music and sound:** original, made on this PC from code and sound fonts (the way Karatecation's score was made),
   synth-driven to match the neon, getting heavier as the levels darken. Any outside sound is CC0 or CC BY with its
   licence recorded in `assets/LICENSES.md`.

## Milestones
| Week ending | Milestone | Javier's part |
|---|---|---|
| Sun 8 Nov | Kit done (GitHub, board, Vault); the Godot project; a grey-box hero that walks, jumps, punches, kicks | answer the open questions in `DESIGN.md` |
| Sun 15 Nov | The feel lab; flying kick, climb on/off, smash and jump obstacles; one enemy; pick up a weapon | — |
| **Sun 22 Nov** | **Grey-box feel test**: a whole grey level 1 with layers, keyboard + gamepad | **plays it, gives the verdict** |
| **Sun 29 Nov** | **The look locked**: style frame, both heroes, two enemies, the level 1 street | **picks on the Dailies page** |
| Sun 6 Dec | Art in the game: rigged heroes and enemies, level 1 layers, first music and sounds | — |
| **Sun 13 Dec** | **Level 1 playable**, boss upstairs, a build he can install | **plays it with the test matrix** |
| Dec 14 – Jan 3 | Holiday weeks: fix level 1's findings; level 2; the weapon bag (collect + switch) | one replay |
| Sun 31 Jan | Levels 3–5 (two floors, level 5 boss), the story opening (choose your hero, the kidnapping) | picks + a play each fortnight |
| Sun 28 Feb | Levels 6–9 (three floors, switches open doors below, level 8 boss), the darker palette | picks + a play each fortnight |
| Sun 14 Mar | Level 10 and the super boss, the endings, the title screen | a full play |
| **Sun 21 Mar** | **Finished**: full playthrough with the matrix, every finding fixed, packaged | **the final playthrough** |
| Mar 22 – Apr 18 | Buffer, AUR, KognogOS integration | his local install test, then the AUR push |

**The finish line is a ceiling, not a target:** done by Sun 21 Mar at the latest; Javier expects faster. If a
milestone lands early, the next one starts early.

**The honest risk:** DecadeDrop launches at the end of November and has a Christmas push. That lands on the same
weeks as the look lock and level 1. The milestones above need about **30 minutes of Javier a week** (picks and
answers) plus **one play session** at each bold line. If December gets swallowed, level 1 slips; the March date has
four weeks of buffer before KognogOS ships.

## Who does what
- **Claude builds:** code, rigs, levels, music and sound drafts, tests, builds, docs.
- **Javier's assistant team** (from another project) researches and designs, tests every piece, runs it on the
  KognogOS machines to check smoothness and lag, helps with packaging, and tallies any paid credits. Their notes
  reach Claude through Javier.
- **Javier decides:** picks, playtests, spending, anything public.

## The quality bar: design → prove → build → test → fix
Every feature, every level, every asset:
1. **Design** — written down first (`docs/DESIGN.md` or the level's own page), with what "done" looks like.
2. **Prove** — the smallest thing that shows it works: a grey box, a single test, one style frame. Nothing is built
   big before it is proven small.
3. **Build** — the real thing, in small commits, each with its tests.
4. **Test** — three layers:
   - automated tests (headless Godot, fenced), **count reported every time**, never allowed to drop silently;
   - a bot that plays every level on several seeds;
   - the assistant team's runs on the KognogOS machines (smoothness, lag);
   - Javier's play with a written test matrix (`testing/`) at each milestone. **His test gates the next step.**
5. **Fix** — every finding from his play is `F-n`, gets a GitHub issue, is fixed in a round, and closes only when
   his next play passes it.
