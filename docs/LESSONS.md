# What Karatecation taught us

*Karatecation x Free!!! (`jetomev/karatecation-x-free`, Oct 2026) was our first game: a Godot 4 project, painted
scenery, 3D fighters, an original score. These are its lessons and what this project does about each one.
Javier & Claude.*

| # | What happened there | What we do here |
|---|---|---|
| L-1 | **Feel decides everything.** The first playthrough was a "big fail": stiff, too fast. It took four rounds and a feel lab (live settings on F-keys) to get close, and it still felt "clunky". | The feel comes **first**, in grey boxes, before any art. The feel lab is built in week one. Javier's feel test gates the art. |
| L-2 | **3D fighters painted to look 2D fought the look.** Poses snapped, the joins between moves showed. | **Cut-out 2D characters** (Godot's 2D bones). Parts are drawn once; the engine moves them; weapons ride the hand bone. |
| L-3 | **Paintings had seams.** A scene repeated when the camera passed one painting width; one approved painting (one-point perspective) could never be widened. | Backgrounds are drawn **side-on and flat from the start**, made to tile or drawn as wide as the level, split into layers on purpose — never split after the fact. |
| L-4 | **Generated-art credits leak.** 7 of 18 Runway runs were wasted. | ChatGPT first. OpenArt or Runway **only with Javier's yes, per batch, with the count and the cost** written down before the run and what it actually cost after. |
| L-5 | **A runaway test crashed the PC** (2,809 stranded 3D models, 31 GB). | **Every Godot run goes through `scripts/capped.sh`** (6 GB, no swap, 8 cores) plus a `timeout`. Big scratch files go to a git-ignored folder on disk, never `/tmp` (it is RAM here). |
| L-6 | **A stuck gamepad stick held "Left" forever** (the G13). | A dead zone on every stick from day one, and a test that feeds a drifting stick. |
| L-7 | **GPU texture limit:** one image may not be wider than 16,384 px. | Long backgrounds are tiles from the start. |
| L-8 | **A bot that plays the whole game** caught breakage early. | A bot plays every level on several seeds in the test run, from the first grey box. |
| L-9 | **The approval page worked.** Every asset went on one page; Javier picked there. | Same here: the Dailies page, one card per asset, his pick recorded. |
| L-10 | **The IP question came late.** Karatecation copied the original's timing and order, which made a public release risky. | This game is ours from the first line. No existing game is used as a reference for timing, levels or characters. |
| L-11 | **Findings as rounds.** Each playthrough became F-n findings, each a GitHub issue, fixed in a round. | Same: every test round writes `testing/` results, every finding becomes an issue `F-n: …`, closed when his next play passes it. |
