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
const BLADES := ["enforcer", "snick", "rook"]  # the sword and knife goons (the team's "one at a time", level 8)
const Fighter := preload("res://scripts/sim/fighter.gd")


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
	var arrivals := {}  # where the whistled goons came in, against the hero (the team's 11-04 rule: ahead or down a ladder)
	var shield_runs := []  # the robot with a picked-up shield, per run
	var bruiser_fight := {}  # screen -> {what -> count or health}: the robot against the Bruiser (the team, 11-05)
	var falls := []  # each fall through a gap: where, from how high, the Whistler near or not
	var things := {}  # what happened, counted (the team's level 7 questions, 11-05): counters, parries, tanks, shocks
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
		var furthest := [0, 0]  # the furthest floor and screen he's reached (the team, 11-05: was a life lost back there?)
		var was_down := false
		var down_at := ""  # where he went down for the life about to be lost, who did it, and how far he'd got
		var down_here := ""
		var last_hit := "?"
		var shield := [0, 0]  # ticks he held a Doorman's shield he'd picked up, blows he landed with it
		var mech_at := -9999  # the last frame a Mechanic's blow landed on him (the team, 11-05: the Bruiser and a pile-on)
		var hop_at := -9999  # the last frame a Whistler hopped from lamp to lamp
		var ys := []  # his height over the last two seconds (a fall: where from)
		var last_pair := ""
		for i in MAX_TICKS:
			if l.won or l.lost:
				break
			bot.me = l.hero
			bot.goal = l.next_door()
			bot.goal_hit = l.goal_is_switch
			bot.jump_cue = l.crane_jump_cue()
			bot.dodge_x = l.shadow_cue()
			bot.climb = l.climb_cue()
			var seen_before: int = l.enemies.size()
			var food_was: Array = l.world.items.filter(func(it): return Fighter.HEALS.has(it["kind"])).map(func(it): return it["kind"])
			var floor_was: int = l.on
			var broken_was: Array = l.world.objects.filter(func(o): return o["broken"]).map(func(o): return o["id"])
			var held_by = l.hero.held_by if l.hero.state == "held" else null
			l.step(bot.think(l.standing()))
			var sc: int = int(l.hero.x / SCREEN) + 1
			ys.append(l.hero.y)
			if ys.size() > 120:
				ys.pop_front()
			var here := "F%d s%d" % [l.on, sc]
			if l.on > furthest[0] or (l.on == furthest[0] and sc > furthest[1]):
				furthest = [l.on, sc]
			for e in l.enemies:
				if e.get("whistled", false) and not called.has(e["f"]):  # where each whistled goon came in, against him
					var esc: int = int(e["f"].x / SCREEN) + 1
					var how: String = "up on a stack" if e["f"].y > 1.0 else "on the ground"
					var side: String = "ahead" if e["f"].x > l.hero.x else "behind"
					var cleared_screen: bool = l.on == furthest[0] and esc < furthest[1]
					var key := "%s, %s%s" % [side, how, ", on a screen he'd already passed (s%d; he'd reached s%d)" % [esc, furthest[1]] if cleared_screen else ""]
					arrivals[key] = arrivals.get(key, 0) + 1
			if l.hero.weapon == "shield":
				shield[0] += 1
			for k in range(seen_before, l.enemies.size()):  # where each enemy came in (the team, 11-05: the balcony Doorman)
				var ne: Dictionary = l.enemies[k]
				_tally(things, "where they came in (x, against the robot's)", "%s at x %d on F%d (robot at x %d)" % [ne["kind"],
					int(ne["f"].x), l.on, int(l.hero.x)], 1)
			if l.on == floor_was:  # what he ate, and the props he broke (the team, 11-05: the vending machine, the shrimp)
				var food_now: Array = l.world.items.filter(func(it): return Fighter.HEALS.has(it["kind"])).map(func(it): return it["kind"])
				for k in food_was:
					if food_was.count(k) > food_now.count(k):
						_tally(things, "food the robot ate", "%s on %s" % [k, here], 1)
						food_now.append(k)  # (count each kind once a frame)
				for o in l.world.objects:
					if o["broken"] and not o["id"] in broken_was and o.get("holds", "") != "":
						_tally(things, "props broken for what they hold", "%s (%s) on %s" % [o.get("name", o["kind"]), o["holds"], here], 1)
			var swinging_now: Array = l.enemies.filter(func(e): return not e["gone"] and e["f"].attack_phase() in ["startup", "active"] \
					and absf(e["f"].x - l.hero.x) < 400.0 and e["kind"] in BLADES)
			var pair := ""
			if swinging_now.size() >= 2:
				var ks: Array = swinging_now.map(func(e): return e["kind"])
				ks.sort()
				pair = " and ".join(ks)
			if pair != "" and pair != last_pair:
				_tally(things, "blades swinging at him at once (each time it starts)", "%s on %s" % [pair, here], 1)
			last_pair = pair
			if held_by != null:
				for ev in l.events:
					if ev.get("target") == l.hero and ev.get("attacker") != null and ev.get("attacker") != held_by \
							and ev.get("result", "") in ["hit", "blocked"]:
						_tally(things, "blows on him while someone held him", "%s on %s" % [_kind_of(l, ev), here], 1)
			got_there = got_there or l.on == last_floor
			for e in l.enemies:
				if e.get("whistled", false):
					called[e["f"]] = true
			for ev in l.events:
				if ev.get("attacker") == l.hero and ev.get("result", "") == "hit":
					landed += 1
					if l.hero.weapon == "shield":
						shield[1] += 1
				if ev.get("target") == l.hero and ev.get("result", "") in ["hit", "blocked", "shocked", "guard_broken"]:
					last_hit = _kind_of(l, ev)
					if last_hit.begins_with("wrench_mechanic"):
						mech_at = i
				if ev.get("result", "") == "hop":
					hop_at = i
				var r: String = str(ev.get("result", ""))
				if ev.get("attacker") == l.hero and ev.get("counter", false):
					_tally(things, "the robot's blows that caught a wind-up (its glint)", str(ev.get("move", "?")), 1)
				if ev.get("attacker") == l.hero and r in ["parried", "dodged", "evaded"] and ev.get("target") != null:
					_tally(things, "%s %s the robot's" % [_kind_of(l, {"attacker": ev["target"]}), r], str(ev.get("move", "?")), 1)
				if r in ["into_the_tank", "shorts_out"]:
					_tally(things, "the tanks", r.replace("_", " "), 1)
				if r == "shocked":
					var who_s: String = "the robot" if ev.get("target") == l.hero else _kind_of(l, {"attacker": ev.get("target")})
					_tally(things, "shocks", "%s by %s on %s" % [who_s, {"live_floor": "a live floor", "shock": "blocking Static's baton"}.get(str(ev.get("kind", "")), str(ev.get("kind", ""))), here], 1)
				if r == "live" and ev.get("kind", "") == "live":
					_tally(things, "Mr. Static", "floor slams", 1)
				var a_kind: String = _kind_of(l, {"attacker": ev.get("attacker")}) if ev.get("attacker") != null else ""
				var t_kind: String = _kind_of(l, {"attacker": ev.get("target")}) if ev.get("target") != null and ev.get("target") != l.hero else ""
				if t_kind.begins_with("bruiser") and ev.get("attacker") == l.hero:
					_tally(bruiser_fight, here, "his blows at the Bruiser: %s" % ev.get("result", "?"), 1)
					if ev.get("counter", false):
						_tally(bruiser_fight, here, "of them caught as the Bruiser wound up (his swing broken)", 1)
				if a_kind.begins_with("bruiser") and ev.get("target") == l.hero:
					_tally(bruiser_fight, here, "the Bruiser's swings at him: %s" % ev.get("result", "?"), 1)
				if ev.get("target") == l.hero and ev.get("result", "") == "hero_fell":
					var whistler := "no Whistler near"
					for e in l.enemies:
						if e["kind"] == "lookout" and not e["gone"] and absf(e["f"].x - l.hero.x) < 600.0:
							whistler = "the Whistler %d px away, %s" % [int(absf(e["f"].x - l.hero.x)),
								"he'd hopped %.1f s before" % ((i - hop_at) / 60.0) if i - hop_at < 600 else "no hop in the last 10 s"]
					falls.append("seed %d, %s (x %d, from up to %d px up in the 2 s before; %s)" % [s, here, int(l.hero.x), int(ys.max()), whistler])
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
			if l.hero.defeated() and not was_down:  # the moment he goes down: that's where the life is lost
				down_here = here
				var doing: String = "on a food errand to x %d" % int(bot.eat_x) if bot.eat_x > -1.0e8 else "fighting"
				var near := []
				for e in l.enemies:
					if not e["gone"] and not e["f"].defeated() and absf(e["f"].x - l.hero.x) < 500.0:
						near.append("%s x %d" % [e["kind"], int(e["f"].x)])
				down_at = "%s (x %d, by %s; furthest so far F%d s%d; the robot %s; near him: %s)" % [here, int(l.hero.x), last_hit,
					furthest[0], furthest[1], doing, ", ".join(near) if not near.is_empty() else "nobody"]
			was_down = l.hero.defeated()
			if l.lives < lives or (l.lost and lives > 0 and down_here != ""):
				lost_at.append(down_at if down_at != "" else here)
				deaths[down_here if down_here != "" else here] = deaths.get(down_here if down_here != "" else here, 0) + 1
				lives = l.lives
				down_at = ""
				down_here = ""
			if drop > 0.0:
				var who := []
				for ev in l.events:
					if ev.get("target") == l.hero and ev.get("result", "") in ["hit", "blocked", "shocked", "guard_broken"]:
						who.append(_kind_of(l, ev))
				if who.is_empty():  # nothing hit him: say what it was (a fall, a shove, the floor) from this frame's events
					var what: Array = l.events.filter(func(ev): return ev.get("target") == l.hero).map(func(ev): return str(ev.get("result", "?")))
					if "hero_fell" in what:
						who.append("a fall through a gap (a missed jump)")
					elif l.enemies.any(func(e): return e["kind"] == "crane_operator" and not e["gone"] and l.plan["floors"][l.on].get("cab", false)):
						who.append("crane_operator (his horn's shove)")
					else:
						who.append("other (%s)" % (", ".join(what) if not what.is_empty() else l.hero.state))
				for k in who:
					taken[k] = taken.get(k, 0.0) + drop / who.size()
					if k.begins_with("bruiser"):
						_tally(bruiser_fight, here, "health he took from the Bruiser with a Mechanic's blow landing too (within a second)" if i - mech_at <= 60 \
							else "health he took from the Bruiser alone", drop / who.size())
					if not per_screen.has(here):
						per_screen[here] = {}
					per_screen[here][k] = per_screen[here].get(k, 0.0) + drop / who.size()
			hp = l.hero.health
		whistled += called.size()
		for fl in l.floors:
			for o in fl["world"].objects:
				if o["kind"] == "vending":
					_tally(things, "the vending machine", "kicked %d times (seed %d)" % [int(o.get("kicks", 0)), s], 1)
		if shield[0] > 0:
			shield_runs.append("seed %d: held %.0f s, %d blows landed with it" % [s, shield[0] / 60.0, shield[1]])
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
		out.append("Where they came in: %s" % ", ".join(arrivals.keys().map(func(k): return "%s ×%d" % [k, arrivals[k]])))
		out.append("")
	if not bruiser_fight.is_empty():
		out.append("**The Bruiser against the robot**, all runs, by screen:")
		var bs: Array = bruiser_fight.keys()
		bs.sort()
		for sc in bs:
			out.append("- %s: %s" % [sc, "; ".join(bruiser_fight[sc].keys().map(func(k): return "%s %s" % [k, str(snappedf(bruiser_fight[sc][k], 0.1))]))])
		out.append("")
	if not things.is_empty():
		out.append("**What happened, counted**, all runs:")
		var tk: Array = things.keys()
		tk.sort()
		for k in tk:
			out.append("- %s: %s" % [k, ", ".join(things[k].keys().map(func(m): return "%s ×%d" % [m, int(things[k][m])]))])
		out.append("")
	if not falls.is_empty():
		out.append("**Falls through a gap**: %s" % "; ".join(falls))
		out.append("")
	if not shield_runs.is_empty():
		out.append("**A picked-up shield**: %s" % "; ".join(shield_runs))
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
		out.append("- %s: %.1f (%s)" % [sc, per_screen[sc].values().reduce(func(a, b): return a + b, 0.0),
			", ".join(ks.map(func(k): return "%s %.1f" % [k, per_screen[sc][k]]))])  # (one decimal: the parts add up, the team 11-05)
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


func _tally(d: Dictionary, screen: String, what: String, n: float) -> void:
	if not d.has(screen):
		d[screen] = {}
	d[screen][what] = d[screen].get(what, 0.0) + n
