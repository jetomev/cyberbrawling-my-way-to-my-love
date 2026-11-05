extends RefCounted
## The score (Merry's game-wide list, 2026-11-05: the helper setting buys lives with it, the harder mode and the boss rush
## have one to beat). PLACEHOLDER POINTS, every one: what counts and how much waits on the assistant team's answer
## (art-in 2026-11-05-answers-signs-and-gamewide); until then the game counts it and doesn't show it (D-2: changing the
## game is a decision). Javier & Claude.

const ENEMY := 100  # a goon down
const BOSS := 1000  # a boss down
const FINISHER := 50  # a combo's last blow landing
const COLLECTIBLE := {"matchbook": 500, "photo": 1000}  # the hidden extras; every other pick-up for score: OTHER
const OTHER := 250  # level 3's trophy, level 4's glove and whistle, level 5's coins, note and key, the fed cat
const HEALTH_LEFT := 10  # a level won: this much for every point of health left
const NO_HIT := 2000  # a level won without being hit once


## What a pick-up is worth.
static func for_collectible(kind: String) -> int:
	return COLLECTIBLE.get(kind, OTHER)
