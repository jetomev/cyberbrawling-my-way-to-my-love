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

## Names
This is a KognogOS-side project: "Javier & Claude" in every file, commit and Vault note. No names from any other
project's role-play, ever.

## Build and test
- Godot project in `game/`. Linux export to `export/` (git-ignored).
- **Every Godot run goes through `scripts/capped.sh`** (max 6 GB, no swap, 8 of 16 cores) **and a `timeout`**:
  tests, exports, recordings, probes. A run that goes long or a log that balloons is a stop signal.
- **Big scratch files go to `scratch/` (on disk, git-ignored), never `/tmp`** (`/tmp` here is RAM).
- Tests run headless. **Report the test count** every time; it never drops silently.
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
- `TODO.md` after every step, and the board re-sent in the same step.
- README accurate top to bottom; roadmap and changelog newest first.
- Every push gets its Vault entry in `Cyberbrawling my way to my love/`, numbered `(N) YYYY-MM-DD — title.md`.
- Findings from Javier's plays: `F-n`, a GitHub issue each, results in `testing/`.
