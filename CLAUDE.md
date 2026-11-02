# Cyberbrawling my way to my love! — how this project works

A side-scrolling street brawler for Linux, our own from the first line, part of KognogOS and shipping with
KognogOS 1.0 (week of 19 April 2027). Public and open source. Javier & Claude, as everywhere.

## Decisions
- **D-1** A project with the full kit (Javier, 2026-11-01): public GitHub, README, licence, topics, issues, TODO.md,
  this file, memory, a Vault hub, a mindForge board.
- **D-2** The game as approved is `docs/DESIGN.md` (Javier, 2026-11-01). Changing it is a new decision here.
- **D-3** Built on Karatecation's lessons (`docs/LESSONS.md`), **not** on Karateka: no material, timing, levels or
  names from it or from any existing game.
- **D-4** Engine: **Godot 4**, from `nog`. Characters are **2D cut-out parts on bones**; backgrounds flat, in layers.
- **D-5** Art: **ChatGPT first**. OpenArt or Runway only with Javier's yes **per batch**, with the count and the
  expected cost written before the run and the real cost after. No standing credit budget.
- **D-6** Dates (Javier, 2026-11-01): level 1 playable mid-December 2026 (target Sun 13 Dec), finished
  **Sun 21 Mar 2027**. Milestones in `docs/PLAN.md`.
- **D-7** The title is **"Cyberbrawling my way to my love!"** (Javier, 2026-11-01; his name-clash check is running). Folder and repo:
  `cyberbrawling-my-way-to-my-love`. **No "Cyberpunk" anywhere in the title.**
- **D-8** Open source (Javier, 2026-11-01). Licence (approved with the public repo, 2026-11-01): code **GPL-3.0-or-later** (like nog and the Forge Suite);
  art, music and sound **CC BY-SA 4.0** (`assets/LICENSE.md`).
- **D-9** **No blood. Pain shows on both sides**, hero and enemies (Javier, 2026-11-01): bruises, black eyes,
  swollen mouths, broken arms and legs, screams, cracks. Damage is drawn on the cut-out parts and heard, never bled.
- **D-10** Schedule stands: **done by Sun 21 Mar 2027 at the latest**; Javier expects faster (2026-11-01).
- **D-11** Team roles (Javier, 2026-11-01): **Claude builds.** Javier's assistant team (from another project) does
  research and design, tests every piece, runs it on the KognogOS machines for smoothness and lag, helps package it,
  and tallies any paid credits. Their notes reach this project **through Javier**. That project's names never appear
  in this repo: here they are "the assistant team".
- **D-12** Level 9 = **the tower gauntlet**: up the boss's tower, three floors, no new mechanic, the hardest regular
  fights, and the best weapon is found here (Javier, 2026-11-01).
- **D-13** Movement = **a shallow street**: left/right plus a few steps up and down the street, enemies can surround
  you, in front of / behind props comes naturally. The grey box still builds the flat line too, for comparison
  (Javier, 2026-11-01).
- **D-14** Health = **a bar**, refilled by food and first-aid kits; **weapons wear out** after a number of hits
  (Javier, 2026-11-01).
- **D-15** **Saves at the start of every level, three lives per level**; losing them restarts that level (Javier,
  2026-11-01).
- **D-16** **One player in 1.0**; the code keeps the door open for a second player after launch (Javier, 2026-11-01).
- **D-18** **Combos** (Javier, 2026-11-01 night, through the assistant team: "make combos to make fights fun…
  FUN!", details left to Claude): three-press chains into finishers, a 0.4 s window (feel lab), presses during a
  blow queue in order, a doubled tap counts once; both K chains open with the front kick. Table in
  `docs/DESIGN.md` → Combos and `game/scripts/sim/moves.gd`; weapon combos and the throw come with weapons.
- **D-19** **Blocks, enemy combos, counters, dizzy** (Javier, 2026-11-01 23:00, his words in `docs/DESIGN.md`): a
  held block with a perfect-block window (built); enemy combos that the right hit or a perfect block interrupts and
  disarms; two hero combos in a row make an enemy dizzy for a finisher; each enemy and boss has its own combos,
  counters and way to be beaten (with the enemies; the team's table comes through Javier).
- **D-20** **A fuller body** (Javier, 2026-11-01 23:20: "the character movements seem to stiff, the upper body has
  little to none flexibility, no feet, no hands…"): 21 bones (belly, chest, neck, head, shoulders, upper and lower
  arms, hands that are fists or open, thighs, shins, feet, toes). Poses stay short and `poses.gd` bake() adds the body
  sense: feet stand on the street and roll onto the toes as the leg drives, shoulders roll into punches, the head
  follows the eyes; every strike winds up, lands, follows through and eases back. The real art uses the same parts.
- **D-21** **Motion from the hips out** (Javier, 2026-11-01 23:45: "still stiff as a pipe... no hip movements, not
  side movements, no back and shoulders moving with hits and kicks"): in a strike the hips move first, then the spine,
  the shoulder and the upper limb, and the fist or foot arrives last, on the logic's timing (the whip, `LEAD` in
  `poses.gd`); the weight shifts (`hip_x`) while planted feet stay put (two-bone leg solving; the hips sink if a leg
  can't reach); the pelvis tips (`hip_turn`) and the back bends into kicks; one shoulder swings forward, the other
  back. His wish for kung-fu patterns over karate (front, side and round kicks low, middle and high; fast punch strings
  ending in a power punch from a side stance) waits for the assistant team's research, including whether free
  motion-capture data can drive these bones and under what licence.
- **D-22** **The team reviews every build before Javier** (Javier, 2026-11-01: "have the team critize the build,
  before I do it"): `scripts/build.sh` is the build step: tests (red = no demo), the recorded demo, a still of every
  move as it lands, close-ups of the hips, hands and feet for each (the team's first ask, 2026-11-02: the hero is
  small in the demo frame), a timed strip of close-ups through each move (a still every 50 ms lined up on the hit:
  the reviewers read pictures, not video), a short note, all copied to the review shelf (its folder is set outside the repo in
  `.review-shelf`, git-ignored). Javier sees a build after the reviewers' fixes, or with their list.
- **D-23** **Form from the first review** (the assistant team, 2026-11-02, on build e7a5106; their notes reach the
  project through Javier's rule D-22): the free hand guards the face while the other strikes (`cover_f`/`cover_b` in
  `poses.gd`: the fist goes to the cheek, elbow down, and doesn't count as a reach for the shoulder swing); the hook
  winds up low and wide and turns the hips more than the cross; the spinning kicks turn the body and pivot on the
  standing foot (`spin`: the drawing squeezes edge-on and shows his back; `rise_f`/`rise_b`: heel off the street) — the
  spin kick goes all the way round and lands facing, the roundhouse turns a third of the way into it.
- **D-24** **Form from the second review** (the assistant team, 2026-11-02, on build 6809c7d): the guard keeps both
  hands up (rear fist at the cheek, front fist out at chin height; a move that uses the rear arm switches its cover
  off); the jab stays upright and short, the cross lunges, turns the shoulders over and reaches further (164 px); the
  swinging moves (hook, roundhouse, spin kick) cock early (`WINDUP_AT`) and pass a `sweep` key, so the swing lasts 4+
  ticks and the kicking knee comes up bent before the shin sweeps; the roundhouse turns the hips and shoulders over
  (`turn`: his back shows, the far arm and leg come in front) and swings the standing foot round (`pivot_f`); after a
  flying kick the knee tucks back in (`tuck`). Every build also makes an every-frame strip around each hit.
- **D-25** **Form from the third review** (the assistant team, 2026-11-02, on build eb78ba7): a spin never squashes
  the fighter thin — the limbs keep their width, the chest narrows at most to about half, and past 90 the drawing flips
  round; the covering fist sits in front of the jaw (`CHEEK`), where it shows past the face; a forearm pointing at the
  camera draws shorter (`fore_f`/`fore_b`, hits measured on the same arm), so the hook swings level at head height with
  the elbow up instead of lifting the forearm; the roundhouse lands turned over (his back to us), upright, the knee
  still bent as it sweeps through, while the spin kick lands facing front, leg straight, leaning back. Every build
  also strips the flying kick's landing frame by frame.
- **D-26** **The stance first, then the posture under every move** (Javier, 2026-11-02 08:16 after playing build
  27f398f: "posture and movements ..... still terrible. Need 100% lots of work and effort. More attention to detail
  please"; the assistant team's order: stance, posture, then each move pose by pose): the guard is a low, wide
  fighting stance (front foot 44 px ahead, back foot 63 px behind, front knee well bent, back leg nearly straight,
  hips dropped, weight between the feet, chin down, both fists at the cheeks, a V-shaped torso, a head with a jaw);
  the guard rocks gently from leg to leg with the knees giving; the walk is a fighter's shuffle whose planted feet stay
  put; strikes move the hips and leave the planted feet where they are (no strike writes a standing leg); a driving
  back leg lifts its heel as far as a straight leg needs; a swinging foot is stopped by the street. Judged by eye with
  `scripts/pose_sheet.sh` (any poses side by side, large) before every build.
- **D-27** **The posture sheet is the reference** (the assistant team's sheet, 2026-11-02, from coaching guides and
  motion studies; on the shelf as `cyberbrawling-posture-sheet-2026-11-02.md`): every blow in four poses (wind-up,
  hit, follow-through, back in guard); feet and hips start it, the spare hand stays home, chin down, the hand or foot
  comes back the way it went, knees never lock but for the kicking leg at the hit, about 60% of the weight forward
  on punches. `game/tests/test_sheet.gd` holds the sheet's checks for every built move; a new move gets its row
  there before it's drawn. A move may write its own follow-through (snap back, hold) instead of carrying the hit on.
- **D-28** **The combos Javier chose** (2026-11-02 18:19, through the assistant team: "Power Button is part of the 3
  punch combination, it is the last punch. The side kick (to the face) is part of the 3 kick combo, the low kick could
  be the first kick of the 3 kick combo (down, middle, side up)."): P, P, P = jab, cross, power punch (a bow-stance
  blow to the chest, the spare fist pulled to the hip); K, K, K = low kick, body kick, side kick to the face; K opens
  every kick chain with the low kick (it keeps the old opener's name "kick", its feel-lab dials and its damage).
  P, P, K stays the push kick. The hook, the front kick (now "front_kick") and the spinning kick keep their poses,
  no press reaches them; no sweep. Each new move has its posture-sheet row in `test_sheet.gd`.
- **D-29** **Walking, running and two stances** (Javier, 2026-11-02 18:48, through the assistant team: "the character
  needs to be able to walk, and run. ASDW are not key for walking. Let's do: A for punches, B for kicks, D for
  blocking, W for running, X to swtich stance (fight/walk)"): keyboard A punch, B kick, D block (held), W run (held),
  X switch stance; the arrows move until he says what moves the hero (`MOVE_KEYS` in `controls.gd` is the one place to
  change); read as keyboard keys, not the gamepad's A/B/X. The fight stance (guard, shuffle) and the walk stance
  (standing easy, an everyday walk); a short switch between them; running from either and back; a blow or a block
  from the walk stance raises the guard first and the press waits. The demo ends with the switch, a walk and a run.
- **D-17** **Weekday morning runs: yes** (Javier, 2026-11-01). He works 8:00–17:00; one scheduled session on this PC
  at 9:00 Mon–Fri, done by 12:00, rules in `docs/UNATTENDED.md`.

## Names
This is a KognogOS-side project: "Javier & Claude" in every file, commit and Vault note. No names from any other
project's role-play, ever.

## Build and test
- Godot project in `game/`. Linux export to `export/` (git-ignored).
- **Every Godot run goes through `scripts/capped.sh`** (max 6 GB, no swap, 8 of 16 cores) **and a `timeout`**:
  tests, exports, recordings, probes. A run that goes long or a log that balloons is a stop signal.
- **Big scratch files go to `scratch/` (on disk, git-ignored), never `/tmp`** (`/tmp` here is RAM).
- Tests run headless: **`scripts/test.sh`** (fenced, timed, logs to `logs/test-latest.log`, last line `OK <n> tests`).
  A test is a `test_<name>()` method in a `game/tests/test_<topic>.gd` that extends `tests/test_case.gd`; the runner
  finds it by name. A file that doesn't load, or a test that makes no check, fails the run.
- **Report the test count** every time; it never drops silently: `game/tests/FLOOR` is the lowest count allowed,
  raised by `test.sh` when tests are added (commit it); lowering it is a decision written in the commit.
- Logic that can be tested bare lives in `game/scripts/sim/` (no nodes); what draws and plays lives in
  `game/scripts/present/`.
- A bot plays every finished level on several seeds as part of the test run.
- **A build is `scripts/build.sh`** (D-22): tests, the demo, the move stills, the note, the review shelf. Never hand
  Javier a build that didn't go through it.
- Every script Javier runs logs to `logs/` (with a `-latest` link) and ends with an OK line.
- Packages: `nog` first; anything missing is a KognogOS finding.

## Assets
- Every asset goes on the Dailies page (`approvals/`) and waits for Javier's pick before it goes in the game.
- Outside assets: CC0 or CC BY only, source and licence in `assets/LICENSES.md`.

## Unattended runs
`docs/UNATTENDED.md` holds the rules. Javier leaves his Claude sessions open while at work, so work sessions are planned around his work hours. In short: only items marked **(solo)** in TODO.md, on a `daily/YYYY-MM-DD`
branch, never pushed, fenced, timed, one report in `reports/`. Not scheduled until Javier's yes.

## Documentation, at every step
- `TODO.md` after every step, and **both pages re-sent in the same step**: the board (mindForge `board.py build`)
  and the Gantt (`scripts/gantt.py scratch/gantt` → its `status.json` as the page's `gantt/status`; republish
  `gantt.html` only when `docs/schedule.json` changes). Links in `.board` and `.gantt`.
- README accurate top to bottom; roadmap and changelog newest first.
- Every push gets its Vault entry in `Cyberbrawling my way to my love/`, numbered `(N) YYYY-MM-DD — title.md`.
- Findings from Javier's plays: `F-n`, a GitHub issue each, results in `testing/`.
