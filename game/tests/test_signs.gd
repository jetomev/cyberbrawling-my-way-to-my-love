extends "res://tests/test_case.gd"
## The sign jokes on the agreed level pages (Pippin's jokes, Javier's yes 2026-11-04), word for word, on each level's
## street: level 1's four, level 2's two, level 3's and level 5's one, level 4's flickering gym sign.

const Level := preload("res://scripts/sim/level.gd")

const PAGES := {
	"level1": ["WE BUY GOLD, SILVER\nAND REGRETS", "LINUX REPAIR\nWE FIX IT IN THE TERMINAL", "OPEN 25 HOURS\nwe're tired",
		"MAFIA HQ\nTOTALLY NORMAL BAKERY"],
	"level2": ["EVERYTHING FRESH, MOSTLY", "FRESH YESTERDAY"],
	"level3": ["CASH FOR ANYTHING. ANYTHING."],
	"level4": ["GYM: NO PAIN NO GAIN"],
	"level5": ["YOU'RE ALREADY WINNING\n(YOU'RE NOT)"],
}


func test_every_agreed_level_has_its_signs_word_for_word() -> void:
	for n in PAGES:
		var d: Dictionary = Level.load_data("res://levels/%s.json" % n)
		var fl: Dictionary = d["floors"][0]
		var texts: Array = fl.get("signs", []).map(func(sg): return sg[2])
		eq(texts, PAGES[n], "%s's signs" % n)
		for sg in fl.get("signs", []):
			check(float(sg[0]) > 0.0 and float(sg[0]) < float(fl["length"]), "%s: '%s' on the street (x %.0f)" % [n, sg[2], sg[0]])
