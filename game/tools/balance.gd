extends SceneTree
## The bot's balance numbers for the team (their playtester-designer, 2026-11-04: "health left after each screen,
## where it died, which enemy types took the most health"). Plays each level on a few seeds, headless, and writes a
## Markdown page: per run, the health and lives as the bot leaves each screen, where each life was lost; per level,
## the health taken by each kind of enemy (or hazard), summed over the runs. scripts/balance.sh runs it.
## Usage: godot --headless --path game -s tools/balance.gd -- OUT.md level3 level4 ...

const Level := preload("res://scripts/sim/level.gd")
const Score := preload("res://scripts/sim/score.gd")
const HeroBot := preload("res://scripts/sim/hero_bot.gd")

const SEEDS := [1, 2, 3]
const MAX_TICKS := 45000
const SCREEN := 1920.0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path: String = args[0]
	var lines := ["# The bot's balance numbers", "",
		"*Javier & Claude, written by `scripts/balance.sh` (game/tools/balance.gd). The bot plays each level on seeds %s, " % [SEEDS]
		+ "up to %d frames (%.0f minutes). Health is out of 30, three lives a level. A screen is 1920 px of one floor; " % [MAX_TICKS, MAX_TICKS / 3600.0]
		+ "floors are numbered in walking order (F0, F1, ...). The bot is a simple player: it blocks a little, throws random "
		+ "combos, goes for food when hurt; these numbers say where it struggles, not what a person would feel.*", ""]
	for n in args.slice(1):
		lines.append_array(_level(n))
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("BALANCE written: %s" % out_path)
	quit()


func _level(n: String) -> Array:
	var d: Dictionary = Level.load_data("res://levels/%s.json" % n)
	var out := ["## %s%s" % [d.get("name", n), "  (DRAFT)" if d.get("draft", false) else "  (settled)"], ""]
	var taken := {}  # enemy kind (or hazard) -> health taken, all runs
	var deaths := {}  # where lives were lost -> count
	var per_screen := {}  # screen -> {kind -> health taken}, all runs
	var reached_last := 0
	var moments := {}  # a boss's set pieces seen (the twins' opening and swaps), all runs
	var whistles := 0  # the Whistler's whistles, all runs, and the goons they brought in
	var whistled := 0
	var hard := []  # which enemies in this layout are the hard versions (the team's ask, third ruling)
	for fl in d["floors"]:
		for w in fl.get("waves", []):
			for e in w.get("enemies", []):
				if e.get("hard", false) and not hard.has(e["kind"]):
					hard.append(e["kind"])
	var last_floor: int = d["floors"].size() - 1
	out.append("| Seed | Result | Health and lives leaving each screen | Lives lost at | Blows he landed |")
	out.append("|---|---|---|---|---|")
	for s in SEEDS:
		var l = Level.new(d, {}, s)
		var bot = HeroBot.new(l.hero, s)
		var screen := ""
		var marks := []
		var lost_at := []
		var lives: int = l.lives
		var hp: float = l.hero.health
		var landed := 0
		var got_there := false
		var called := {}  # the goons whistled in this run, counted as each one arrives (a floor left behind drops its list)
		for i in MAX_TICKS:
			if l.won or l.lost:
				break
			bot.me = l.hero
			bot.goal = l.next_door()
			bot.goal_hit = l.goal_is_switch
			bot.jump_cue = l.crane_jump_cue()
			bot.dodge_x = l.shadow_cue()
			bot.climb = l.climb_cue()
			l.step(bot.think(l.standing()))
			var here := "F%d s%d" % [l.on, int(l.hero.x / SCREEN) + 1]
			got_there = got_there or l.on == last_floor
			for e in l.enemies:
				if e.get("whistled", false):
					called[e["f"]] = true
			for ev in l.events:
				if ev.get("attacker") == l.hero and ev.get("result", "") == "hit":
					landed += 1
				if ev.get("result", "") == "whistle":
					whistles += 1
				if ev.get("result", "") in ["opening", "swap", "compound"]:
					moments[ev["result"]] = moments.get(ev["result"], 0) + 1
			if here != screen:
				if screen != "":
					marks.append("%s %.0f/%d" % [screen, l.hero.health, l.lives])
				screen = here
			# health lost this frame, shared out over whoever hit him (food or a new life raises it: nothing lost)
			var now: float = l.hero.health
			var drop: float = maxf(0.0, hp - now)
			if l.lives < lives:
				lost_at.append(here)
				deaths[here] = deaths.get(here, 0) + 1
				lives = l.lives
			if drop > 0.0:
				var who := []
				for ev in l.events:
					if ev.get("target") == l.hero and ev.get("result", "") in ["hit", "blocked", "shocked", "guard_broken"]:
						who.append(_kind_of(l, ev))
				if who.is_empty():
					who.append("other")
				for k in who:
					taken[k] = taken.get(k, 0.0) + drop / who.size()
					if not per_screen.has(here):
						per_screen[here] = {}
					per_screen[here][k] = per_screen[here].get(k, 0.0) + drop / who.size()
			hp = l.hero.health
		whistled += called.size()
		var result: String = "won" if l.won else ("lost on %s" % screen if l.lost else "not finished at %s" % screen)
		var parts: Array = Score.PARTS.filter(func(k): return l.score_parts.get(k, 0) != 0).map(func(k): return "%s %d" % [k.replace("_", "-"), l.score_parts[k]])
		result += ", score %d%s" % [l.score, " (%s)" % ", ".join(parts) if not parts.is_empty() else ""]  # (the team's
		# points, sim/score.gd, split: goons, bosses, finishers, blocks, finds, health, no-hit)
		if got_there:
			reached_last += 1
		out.append("| %d | %s | %s | %s | %d |" % [s, result, ", ".join(marks + ["%s %.0f/%d" % [screen, l.hero.health, l.lives]]), ", ".join(lost_at) if not lost_at.is_empty() else "-", landed])
	out.append("")
	var kinds: Array = taken.keys()
	kinds.sort_custom(func(a, b): return taken[a] > taken[b])
	var total: float = taken.values().reduce(func(a, b): return a + b, 0.0)
	out.append("Health taken, all %d runs (%.0f in all): %s" % [SEEDS.size(), total,
		", ".join(kinds.map(func(k): return "%s %.0f (%d%%)" % [k, taken[k], int(round(100.0 * taken[k] / maxf(total, 1.0)))]))])
	out.append("")
	out.append("**Pass mark** (the team's: the bot reaches the level's last screen, F%d, at least once in %d runs): %s (%d of %d)" % [
		last_floor, SEEDS.size(), "PASS" if reached_last > 0 else "UNDER", reached_last, SEEDS.size()])
	out.append("")
	out.append("**Hard versions** in this layout: %s" % (", ".join(hard) + " (tagged \"(hard)\" below)" if not hard.is_empty() \
		else "none (no hard version of any enemy is built yet; when one is, it shows here and as \"(hard)\" below)"))
	out.append("")
	if whistles > 0:
		out.append("**The Whistler**, all runs: %d whistles, %d goons whistled in (tagged \"(whistled in)\" below)" % [whistles, whistled])
		out.append("")
	if not moments.is_empty():
		out.append("**Boss moments seen**, all runs: %s" % ", ".join(moments.keys().map(func(k): return "%s ×%d" % [
			{"opening": "the twins' opening", "swap": "the twins' swap", "compound": "the twins' Compound (both at once)"}.get(k, k), moments[k]])))
		out.append("")
	out.append("Health taken by screen, all runs:")
	var screens: Array = per_screen.keys()
	screens.sort()
	for sc in screens:
		var ks: Array = per_screen[sc].keys()
		ks.sort_custom(func(a, b): return per_screen[sc][a] > per_screen[sc][b])
		out.append("- %s: %.0f (%s)" % [sc, per_screen[sc].values().reduce(func(a, b): return a + b, 0.0),
			", ".join(ks.map(func(k): return "%s %.0f" % [k, per_screen[sc][k]]))])
	if not deaths.is_empty():
		var where: Array = deaths.keys()
		where.sort_custom(func(a, b): return deaths[a] > deaths[b])
		out.append("")
		out.append("Lives lost, by screen: %s" % ", ".join(where.map(func(k): return "%s ×%d" % [k, deaths[k]])))
	out.append("")
	return out


## Who a hit on the hero came from: the attacker's kind, or what flew or struck (a wrench, a record, the floor).
func _kind_of(l, ev: Dictionary) -> String:
	var a = ev.get("attacker")
	if a != null:
		for e in l.enemies:
			if e["f"] == a:
				return e["kind"] + (" (hard)" if e.get("hard", false) else "") + (" (whistled in)" if e.get("whistled", false) else "")
	var p = ev.get("projectile")
	if p != null and p.get("catchable", false) and p["team"] == 1:
		return "wrench_mechanic (thrown %s)" % p["kind"]  # (his hurl: his wrench, or whatever he'd picked up)
	if p != null:
		return {"wrench": "wrench_mechanic (thrown wrench)", "record": "dj_volt (records)", "card": "chrome (cards)",
			"ball": "coach (medicine ball)", "soup": "big_mama (soup)"}.get(p["kind"], "thrown " + str(p["kind"]))
	return str(ev.get("kind", ev.get("move", "other")))
