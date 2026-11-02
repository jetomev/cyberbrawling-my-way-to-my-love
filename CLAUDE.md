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
