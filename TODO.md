# Cyberbrawling my way to my love! — TODO

*Started 2026-11-01. Javier & Claude. Decisions in CLAUDE.md; the game in docs/DESIGN.md; dates in docs/PLAN.md.
Items marked (solo) can run in an unattended session (docs/UNATTENDED.md).*

## Stage 0 · The kit (by Sun 8 Nov)
- [x] Project folder, README, licence files, CLAUDE.md, TODO.md, design, plan, lessons, unattended plan
- [x] Memory file and its MEMORY.md line
- [x] Vault hub
- [x] mindForge board
- [x] Javier approves the name, licence and README for the public GitHub repo (2026-11-01)
- [x] Public GitHub repo jetomev/cyberbrawling-my-way-to-my-love: README, About, topics, issues #1–#5
- [x] Vault entry (1) for the first push
- [x] Top-down Gantt: docs/schedule.json + scripts/gantt.py, its page beside the board (2026-11-01)
- [x] Two Claude mods for this work (2026-11-01): godot-fence refuses unfenced Godot runs; pages-sync keeps the board and Gantt in step with this list
- [x] Both mods installed for every new session (2026-11-01); a fresh session's load is still to be seen
- [x] Javier answers the open questions in docs/DESIGN.md (level 9, lane depth, health, lives, two players) (#1): D-12 to D-16
- [x] Javier says yes or no to the unattended plan (and his working hours): yes, works 8:00–17:00 (D-17)
- [ ] First weekday morning run (Mon 2 Nov, 9:00) reviewed with Javier that evening
- [x] Title decided: "Cyberbrawling my way to my love!" (D-7); no blood, pain on both sides (D-9); team roles (D-11)

## Stage 1 · The feel, in grey boxes (by Sun 22 Nov) — #2
- [x] Godot project, fenced test runner, headless tests (solo) (2026-11-01: 4 tests, 16 checks; test-count floor)
- [x] Grey-box hero on bones: walk, jump, punch, kick (solo) (2026-11-01 night: 24 tests, 237 checks; demo recorded)
- [x] The feel lab: live settings on the F-keys (solo) (2026-11-01 night: F1 opens it, 15 settings, F8 saves; 32 tests)
- [x] Flying kick; climb onto objects and down; smash or jump obstacles, never walk through (solo) (2026-11-01 night: 44 tests)
- [x] Combos: P/K three-hit chains with finishers, hammer fist, feel-lab window (solo) (2026-11-01 night, D-18: 62 tests)
- [x] Block: hold to guard, perfect-block window with a flash, attack out of the guard (solo) (2026-11-01 night, D-19: 68 tests)
- [x] A fuller body: spine, neck, shoulders, hands, feet and toes; planted feet, wind-up and follow-through (solo) (2026-11-01 night, D-20: 76 tests)
- [x] Motion from the hips: the whip, weight shifts with planted feet, shoulders swing, the back bends into kicks (solo) (2026-11-02 night, D-21: 81 tests)
- [x] The build step: tests, demo, move stills, onto the review shelf (solo) (D-22)
- [x] Close-ups of the hips, hands and feet in every build (the team's first ask) (solo) (D-22)
- [x] Timed close-up strips of every move in every build, and the move stills framed head to feet (solo) (D-22)
- [x] First review's form notes: free hand guards the face, wider hook, spinning kicks turn and pivot (solo) (D-23)
- [x] Second review's notes: guard hands up, jab vs cross, hook swing, spinning kicks chamber/turn/pivot, air-kick tuck, every-frame hit strips (solo) (D-24)
- [x] Third review's notes: spin without the sliver, fist in front of the jaw, level hook (forearm foreshortening), roundhouse vs spin kick at contact, landing strips (solo) (D-25)
- [ ] The team's notes on the D-25 build; their call on the landing's one-frame snap into the crouch (D-22)
- [x] The stance: low, wide, weight between the feet, chin down, hands up; the guard rocks; the walk is a shuffle (solo) (D-26)
- [x] The posture under every move: planted feet stay put, the hips do the shifting, heel drive, the street stops a swinging foot (solo) (D-26)
- [x] Kicks stand tall on the standing leg (step-up for front-leg kicks) (solo) (D-26)
- [x] Fourth review: the landing reaches, touches, sinks and rises; the hips lead the spin and roundhouse; the standing foot pivots where it shows (solo) (D-26)
- [x] Each built move pose by pose against the team's posture sheet: guard, jab, cross, hook, uppercut, elbow, front and push kick, round kick, knee (solo) (D-27)
- [x] The testers' joint review of b033c19: hook (compact load, level arc, pivot), elbow raised to the jaw, knee in stages, round kick recoil, spin with the head first; body kick a snap kick; push kick in the demo (solo) (D-27)
- [ ] The sheet's new moves: power punch (bow stance), side kick, low kick, sweep, spinning side kick; their combo presses are a design call (D-27)
- [ ] Kung-fu patterns: front, side, round kicks low/mid/high; punch strings ending in a power punch (D-21; after the team's research)
- [ ] One enemy type that fights back and drops a weapon; reacts to stagger, knockdown, launch and push (solo)
- [ ] That enemy's own combos; the right hit or a perfect block interrupts them and can disarm him; a block takes less pain (solo)
- [ ] Two hero combos in a row make an enemy dizzy: the window for a finishing combo (solo)
- [ ] Pain system in grey boxes: damage stages per part, broken arm/leg effects, hit sounds; no blood (solo) (#3)
- [ ] Pick up a weapon; it stays in the hand (solo)
- [ ] Weapon combos (W,W,W swing, backswing, overhead smash; W,P,K) and each weapon's feel: knife, sword, bat, pipe/wrench (solo)
- [ ] Throw the held weapon at a far enemy; it lands and can be picked up again (solo)
- [ ] Layers: foreground props, play lane, skyline; in front / behind (solo)
- [x] Keyboard + gamepad, dead zone, drifting-stick test (solo) (2026-11-01: brought forward for F-1, the G13 stuck stick; 51 tests)
- [ ] Both lane depths to try: flat line and shallow street (solo)
- [ ] A grey level 1 with the boss upstairs; the bot plays it (solo)
- [ ] Javier's grey-box feel test

## Stage 2 · The look (by Sun 29 Nov) — #4
- [ ] Style sheet docs/STYLE.md: palette per level, neon to grit (solo)
- [ ] Prompt sheets for ChatGPT: style frames, parts sheets, level 1 layers (solo)
- [ ] ChatGPT style frames; Javier picks one
- [ ] Both heroes and two enemies as parts sheets, with bruised/swollen/broken stages; Javier approves
- [ ] Level 1 street in layers; Javier approves
- [ ] The Dailies page

## Stage 3 · Level 1 playable (by Sun 13 Dec) — #5
- [ ] Cut, clean and rig the approved parts (solo)
- [ ] Level 1 layers in the game (solo)
- [ ] First music cue and sound effects, as drafts for Javier's ear (solo)
- [ ] Level 1 boss upstairs (solo)
- [ ] Linux build he can install; test matrix in testing/ (solo)
- [ ] Javier plays level 1 with the matrix

## Stage 4 · Levels 2–5 (by Sun 31 Jan)
- [ ] Level 1 findings fixed
- [ ] The weapon bag: collect and switch
- [ ] Story opening: choose your hero, the kidnapping
- [ ] Level 2; levels 3–5 on two floors; the level 5 boss
- [ ] Each enemy type and boss: its own combos, counters to the hero's combos, its own way to be beaten (D-19; the team's table)

## Stage 5 · Levels 6–9 (by Sun 28 Feb)
- [ ] Switches upstairs that open doors below
- [ ] Levels 6–8 on up to three floors; the level 8 boss
- [ ] Level 9
- [ ] The darker, grittier palette

## Stage 6 · The end (by Sun 14 Mar)
- [ ] Level 10 and the super boss who needs the best weapon
- [ ] The endings

## Stage 7 · Finished (Sun 21 Mar) and shipped with KognogOS 1.0
- [ ] Javier's full playthrough with the matrix; every finding fixed
- [ ] v1.0.0 release, AUR package (after his local test), KognogOS launcher entry
