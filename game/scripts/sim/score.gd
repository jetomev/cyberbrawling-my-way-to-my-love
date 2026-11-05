extends RefCounted
## The score: the assistant team's points (Merry and Pippin's agreed list, 2026-11-05 18:37). Counted on every level and
## kept in parts (goons, bosses, finishers, blocks, finds, health, no-hit) so the robot's page can split it; shown on
## screen only with Javier's yes (their proposal: a number top right and a tally at each level's end). Javier & Claude.

const ENEMY := 100  # a goon down
const BOSS := 1000  # a boss down
const GODFATHER := 3000  # the Godfather down
const FINISHER := 50  # a combo's last blow landing
const DIZZY_FINISHER := 250  # a combo's last blow landing on someone dizzy
const PERFECT_BLOCK := 100  # a perfect block that breaks a combo (never a thrown wrench)...
const PERFECT_BLOCKS_MAX := 3  # ...at most this many per enemy
const COLLECTIBLE := {"matchbook": 500, "photo": 1000}  # the hidden extras; every other pick-up for score: OTHER
const OTHER := 250  # level 3's trophy, level 4's glove and whistle, level 5's coins, note and key, the fed cat
const HEALTH_LEFT := 50  # a level won: this much for every point of health left...
const HEALTH_MAX := 1500  # ...up to this
const NO_HIT := 2000  # a level won with no health lost to anything (enemies, crates, the container, live floors, falls)
const HARDER := 1.5  # the harder mode counts everything this much more
const LIFE := 2000  # the helper: another life, when the last one goes (off by default, a switch in the pause menu)
const LIFE_HARDER := 3000
const PARTS := ["goons", "bosses", "finishers", "blocks", "finds", "health", "no_hit"]


## What a pick-up is worth.
static func for_collectible(kind: String) -> int:
	return COLLECTIBLE.get(kind, OTHER)
