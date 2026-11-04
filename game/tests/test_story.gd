extends "res://tests/test_case.gd"
## The story's words (the assistant team's, story/story.json) have every part the game shows: choosing the hero, the
## opening, a moment before level 1 and level 10, after each of levels 1 to 9, the ending, the out-of-lives lines.

func test_the_story_has_every_part() -> void:
	var s = JSON.parse_string(FileAccess.get_file_as_string("res://story/story.json"))
	check(s is Dictionary, "story.json reads")
	check(s["choose"]["lines"].size() >= 1 and s["choose"]["him"] != "" and s["choose"]["her"] != "", "choosing the hero")
	check(s["opening"].size() >= 5, "the opening (%d lines)" % s["opening"].size())
	check(s["before"].has("1") and s["before"].has("10"), "before level 1 and the last")
	for n in range(1, 10):
		check(s["after"].has(str(n)) and s["after"][str(n)].size() >= 1, "after level %d" % n)
	check(s["ending"].size() >= 3, "the ending")
	check(s["out_of_lives"].size() >= 1, "the out-of-lives lines")
	for part in [s["opening"], s["ending"]]:
		for line in part:
			check(not line.contains("Frodo") and not line.contains("Auren") and not line.contains("Balih"), "no names from another project in the game")
