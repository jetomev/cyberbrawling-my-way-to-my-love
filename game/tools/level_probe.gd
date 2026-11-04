extends SceneTree
## Plays level 1 with the bot on one seed and prints how it goes, wave by wave (for balancing; not a test).
## Usage: godot --headless --path game -s res://tools/level_probe.gd -- <seed>

const Level := preload("res://scripts/sim/level.gd")
const HeroBot := preload("res://scripts/sim/hero_bot.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var s := int(args[0]) if not args.is_empty() else 1
	var l = Level.new(Level.load_data("res://levels/level1.json"), {}, s)
	var bot = HeroBot.new(l.hero, s)
	var dealt := 0.0
	var taken := 0.0
	var last := ""
	for i in 30000:
		if l.won or l.lost:
			break
		bot.me = l.hero
		l.step(bot.think(l.standing()))
		for e in l.events:
			if e["result"] in ["hit", "blocked"]:
				var d: float = e["attacker"].move().get("damage", 0.0) if e["attacker"].move().size() else 0.0
				if e["attacker"] == l.hero:
					dealt += d
				else:
					taken += d
		var now := "%s wave %d lives %d" % [l.where, l.wave, l.lives]
		if now != last:
			print("t=%d %s hero %.0f/%.0f dealt %.0f taken %.0f" % [l.tick, now, l.hero.health, l.hero.max_health, dealt, taken])
			last = now
	print("END t=%d won=%s lost=%s" % [l.tick, l.won, l.lost])
	quit()
