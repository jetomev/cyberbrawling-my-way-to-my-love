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
- [x] The testers' review of 0812a0e: spin kick folds back before lowering, jab comes home on its line, hook hoop and waist lead, round kick heel turn, elbow to head height, the spare-hand check proven on a wrong jab (solo) (D-27)
- [x] Javier's combos: power punch ends P,P,P; low kick opens and side kick ends K,K,K; in the demo and the strips (solo) (D-28)
- [ ] Javier: do the hook, the front kick and the spinning kick come back somewhere (or stay for enemies)? (D-28)
- [x] Walking and running, the walk stance and X to switch; A punch, B kick, D block, W run (solo) (D-29)
- [x] Moving clips of every move in every build, full speed and half (solo) (D-22)
- [x] Javier: the arrow keys move the hero (2026-11-02 19:09) (D-29)
- [x] Recorded motion, reference only: CMU takes outside the repo, scripts/mocap_ref.py, the README credit (D-30)
- [x] From the recordings: the jump (a crouch first, extension, legs swinging forward), the flying kick (the front kick's shape), the everyday walk (real cadence), a live guard (solo) (D-30)
- [x] Side by side in every build: the hero beside the recording, same moments, same leg length, for the jump, flying kick, walk and stance (the testers' ask) (D-30)
- [x] Builds off the shelf: ~/Documents/Cyberbrawling/builds/; one plain report a day on the shelf, cyberbrawling-report-YYYY-MM-DD.md (Javier 20:14)
- [x] The testers' first joint session on a26ccd7: standing heel to the target (side and round kick; a drawing bug), the power punch loads low and wide, the round kick's waist rolls through, the elbow level at head height (D-27)
- [x] W alone runs the way he faces, an arrow steers it (Javier played: "S and W don't work")
- [x] Javier's play of a7c202b: a flying side kick (not the crane), a brisker walk (1.5 legs/s), a real run (0.6 s strides, 2.4 legs, runs tall) (D-30)
- [x] S: the kick (Javier's final keys, 21:56)
- [ ] Each day with work: write or rewrite that day's report on the shelf (the build says if it's missing)
- [ ] From the recordings: the long fall after a flying kick from the car hangs stiff (D-30); "Wushu Basics" (Commons, CC BY-SA 3.0, studied 11-02): knees stay tucked high, arms spread wide, legs unfold only ~100 ms before touchdown
- [x] From the recordings: the kicks (round kick high and straight on a tall standing leg, snap kicks chambered and snapping, side kick faster and tall); the punches checked, already matching (D-30)
- [x] Side-by-sides for the punches and kicks too, seen along each blow (D-30)
- [ ] The power punch leans far more than the recorded lunge punch (9-14 degrees); the sheet asks ~60% weight forward: the testers' call
- [x] The sweep on Z, drawn from the posture sheet (no recorded sweep exists in our libraries); first pass, the testers judge it
- [x] Javier's final keys (21:56): A punch, S kick, D block, W run, X stance, Z sweep, C roll, Space jump; a guard holds them
- [x] Only Javier's keys (his word 11-03 19:46): the old spares J, K, L, Shift cleared; test_only_javiers_keys fails on any other key (cd809c2)
- [x] The evasion roll on C, the way the arrows point, from common technique; evades 70% of it
- [x] The roll goes over the shoulder, chin tucked (the head had taken the street)
- [ ] The roll from a recording: CMU 128_09 "Run Roll Underneath" found; download waits on Javier's own yes
- [x] Every build: a frame sheet of every move (every frame, in order, timed), for the testers
- [x] The sweep sinks into a bow stance, not a kneel; a swinging knee never goes through the street (any move)
- [x] The demo rolls forward first (a roll back ran into the crate)
- [x] Every build refreshes the newest shelf report's facts (build, tests, changes waiting): no hand-typed numbers
- [x] The testers' joint session on 98a076f: roll head 20+ px clear, flying kick leans back only a touch, sweep long and low, power punch loads wider
- [x] Street-fixed frame sheets and clips in every build, so the travel shows
- [x] The roll from the team's roll reference: side-on dip with the guiding arm, timed evasion (only while round), 1.3 body lengths; credits in the README
- [x] The testers' session on f744019: power punch load 1.5x the guard (third time), no standing knee kneels (any move), the flying kick lands staggered and absorbs into the guard
- [x] Pictures: a running flying kick shown whole; the sweep seen from above
- [x] The testers' session on 66ce4c6 (00:57): power punch load measured (2.3 shoulder widths already; the fault was the hips over the front foot and the back knee near the street) and made a horse stance, hips centred, knees out; the sweep's foot goes a full circle; measurements in the build notes; the roll's shoulders up close; every frame sheet checked whole
- [x] The roll's close-up showed him hovering over the top: now placed by his drawn outline, hand then back then hips (46be0b9)
- [ ] The roll: four frames between the hand and the back where the tucked head holds him a few px up
- [x] The testers' session on 46be0b9 (01:56): power punch load, roll's shoulder support and head clearance, the full sweep drawing all PASS; nothing sent back
- [x] The testers' session at 02:29: the sweep turns on a planted forefoot, hips carried over it (bfe0316); sweep reach 195 (was 120), Javier to judge in play; the spin frame by frame with its circle (sweep-spin)
- [x] The testers' session at 04:00: the sweep PASSES (planted pivot foot, broad body, long sweeping leg, the full circle drawn); nothing sent back; everything judgeable from pictures has now passed
- [ ] Still jumping in the frame a spin flips: the sweep's long leg, head and hands (kept long and broad as asked); the spinning kick's pivot foot (not on the hero's keys)
- [ ] Waits for Javier's own play (pictures can't show it): smooth movement and natural pace at full and half speed, whole moves, the sweep's circle moving, the spinning kick, the sweep's reach 195
- [x] The run's first steps no longer snap: starting and stopping blend from the last drawn pose (was a 131 px jump)
- [ ] Kung-fu patterns: front, side, round kicks low/mid/high; punch strings ending in a power punch (D-21; after the team's research)
- [x] One enemy type that fights back and drops a weapon; reacts to stagger, knockdown, launch and push (solo) (2026-11-03: fight.gd, brain.gd, the thug in play, a bot fight clip in every build)
- [x] That enemy's own combos; the right hit or a perfect block interrupts them and can disarm him; a block takes less pain (solo) (2026-11-03: a counter, caught winding up, or a perfect block knocks his weapon loose)
- [x] Two hero combos in a row make an enemy dizzy: the window for a finishing combo (solo) (2026-11-03: within 4 s, no blow of his between; dazed 2.5 s)
- [x] Pain system in grey boxes: damage stages per part, broken arm/leg effects; no blood (solo) (#3) (2026-11-03: head, body, arms, legs go bruised → swollen → broken by where blows land; a broken leg limps, a broken arm hits at half and hangs; heals between levels)
- [x] Hit sounds, voices and the crack wired to the fight's events (2026-11-03: present/sound.gd plays assets/audio/sfx/<name>-<n>.ogg, silent until the team's sound batch lands)
- [ ] The team's sounds in: copy their batch into assets/audio/sfx/ under the names in sound.gd
- [x] The testers' send-back (2026-11-03): the combo window now ends exactly on its setting (24 frames, was 22 in practice); controlled trials in every build (combo edge, injuries, weapon wear, disarm, dizzy, scenery speeds)
- [x] Finding: Godot aborted (SIGABRT) as it quit, every run since 2026-11-01 (126 core dumps), after its work was written: a lambda hooked on Input's pad signal and never unhooked; now a method, unhooked on exit; every recording and the export fail on a crash from now on
- [x] Pick up a weapon; it stays in the hand (solo) (2026-11-03: walk over it with an empty hand; drawn in the lead hand)
- [x] Weapon combos (W,W,W swing, backswing, overhead smash) and each weapon's feel: knife, sword, bat, pipe/wrench, stick (solo) (2026-11-03: holding one, A swings it; each wears out after its hits)
- [x] Weapon mixes W,P,K (solo) (2026-11-03, the team's weapon combos: the same presses armed, the weapon in the fist's place; wear only on a hit, kicks never wear it)
- [x] The testers' trials send-back (22:30): the disarm frame by frame (leaves the hand, lies on the street, picked up), the counter, a broken arm, every weapon to breaking, the third combo on a dazed enemy; found and fixed on the way: a disarmed enemy grabbed his weapon straight back
- [ ] Throw the held weapon at a far enemy; it lands and can be picked up again (solo)
- [x] Layers: foreground props, play lane, skyline; in front / behind (solo) (2026-11-03: sky, far skyline, the block across, the shopfronts, the street, lampposts in front; each slides at its own speed; the team's level art replaces each)
- [x] Keyboard + gamepad, dead zone, drifting-stick test (solo) (2026-11-01: brought forward for F-1, the G13 stuck stick; 51 tests)
- [x] Both lane depths to try: flat line and shallow street (solo) (built with D-13: `scripts/play.sh --flat`, the feel lab's flat_line; tested in test_fighter and test_feel_lab)
- [x] A grey level 1 with the boss upstairs; the bot plays it (solo) (2026-11-03: level.gd + levels/level1.json, a placeholder layout; waves lock the street, two attack at once, food and first aid, three lives then a restart; the bot wins 2 of 3 seeds; a level clip in every build)
- [x] Level 1's real layout and enemy table from the team (2026-11-03: the team's seven screens, 17 enemies, props and pick-ups in levels/level1.json; the Glow Punk and the Bruiser in brain.gd and level.gd; the bot wins it on every seed)
- [x] DJ Volt's own fight (2026-11-03: records low, middle, high from range, dodged by stepping, jumping or a roll, a perfect block sends one back; the mic stand close in; the Bass Drop while his speakers stand; drops the bat)
- [x] The sparring friend on screen 1 (2026-11-03: block, perfect block, the dizzy finisher, a hint each; soft blows, can't be put down, never blocks the street)
- [ ] Level 1's still-to-come from the team's page: the umbrella, the cat
- [ ] Javier's grey-box feel test

## Stage 2 · The look (by Sun 29 Nov) — #4
- [x] Style sheet docs/STYLE.md: palette per level, neon to grit (solo) (2026-11-03, Javier: "move forward please")
- [x] Prompt sheets for ChatGPT: style frames, parts sheets, level 1 layers (solo) (docs/PROMPTS.md, count + cost per batch)
- [x] Three free style frames we drew ourselves (A neon ink, B soft glow, C grit comic) + the colour of each level, on the Dailies page
- [ ] Javier picks a direction; then the ChatGPT style frames, Batch 1 (6 pictures, $0 extra on ChatGPT Plus), on his yes
- [ ] Both heroes and two enemies as parts sheets, with bruised/swollen/broken stages; Javier approves
- [ ] Level 1 street in layers; Javier approves
- [x] The Dailies page (scripts/build_dailies.py; link in .dailies)

## Stage 3 · Level 1 playable (by Sun 13 Dec) — #5
- [ ] Cut, clean and rig the approved parts (solo)
- [ ] Level 1 layers in the game (solo)
- [x] First music cue (level 1, a minute, loops) and 8 sound effects × 3 takes, free drafts on the Dailies page (solo)
- [ ] Javier listens: music and effects approved or sent back
- [ ] Level 1 boss upstairs (solo)
- [ ] Linux build he can install; test matrix in testing/ (solo) (2026-11-03: scripts/export.sh exports it and the exported program plays level 1 through by itself; scripts/install.sh / uninstall.sh, user-only, a menu entry, passed on a bench home folder; left: the test matrix, the team's real icon)
- [ ] Javier plays level 1 with the matrix

## Stage 4 · Levels 2–5 (by Sun 31 Jan)
- [ ] Level 1 findings fixed
- [ ] The weapon bag: collect and switch
- [x] Story opening: choose your hero, the kidnapping (2026-11-03: the title, Him or Her, the team's opening and a moment before and after each level, the endings, the out-of-lives lines (story/story.json), the levels in order, a save at each level's start (D-15); the story's pictures come with the team's art)
- [x] Level 2, the Night Market (2026-11-04, the team's settled layout: 19 enemies, Snick, the pipe Bruiser, stall counters, ladders, the cracked tile's noodle bar, Big Mama Noodle's kitchen; the bot wins it on most seeds)
- [ ] Levels 3–5 on two floors; the level 5 boss (layouts from the team: levels 2-10 page)
- [ ] Each enemy type and boss: its own combos, counters to the hero's combos, its own way to be beaten (D-19; the team's table)

## Stage 5 · Levels 6–9 (by Sun 28 Feb)
- [x] Switches upstairs that open doors below (built 2026-11-03 in level.gd: floors, stairs through doorways at the back of the street, switches flipped by a blow, named doors; the team's layouts for levels 6-8 use it)
- [ ] Levels 6–8 on up to three floors; the level 8 boss
- [ ] Level 9
- [ ] The darker, grittier palette

## Stage 6 · The end (by Sun 14 Mar)
- [ ] Level 10 and the super boss who needs the best weapon
- [ ] The endings

## Stage 7 · Finished (Sun 21 Mar) and shipped with KognogOS 1.0
- [ ] Javier's full playthrough with the matrix; every finding fixed
- [ ] v1.0.0 release, AUR package (after his local test), KognogOS launcher entry
