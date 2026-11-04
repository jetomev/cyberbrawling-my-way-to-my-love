extends RefCounted
## One fighter's body and moves, stepped one tick at a time. No nodes, no engine time: the same inputs always give
## the same result, so tests and the bot can drive it bare. The hero uses it now; enemies will too.
##
## Space: x runs along the street, z is the depth of the street (0 = far edge), y is height above the street.
## An input is a Dictionary: {mx: -1..1, mz: -1..1, jump, punch, kick, sweep, roll, block, run, stance: bool}; jump,
## punch, kick, sweep, roll and stance are "pressed this tick"; block and run are "held" (D-19: hold to guard; its first moments are a perfect
## block). Two stances (Javier, 2026-11-02 18:48: "W for running, X to swtich stance (fight/walk)"): the fight stance
## (guard "idle", the shuffle "walk") and the walk stance (relaxed "stand", the everyday walk "stroll"); X switches
## between them through a short "to_walk" / "to_fight"; running ("run" held: alone, the way he faces; with an arrow, that way) works from either and
## comes back to it. A blow, a block or a press from the walk stance raises the guard first ("to_fight"): the press
## waits through it. A world (street_world.gd) is optional: without one the street is empty.
## Attacks and combos live in moves.gd: the state is the move's name ("punch", "cross", "spin_kick", …).

const Tuning := preload("res://scripts/sim/tuning.gd")
const Moves := preload("res://scripts/sim/moves.gd")
const Weapons := preload("res://scripts/sim/weapons.gd")

const GROUND_STATES := ["idle", "walk", "stand", "stroll", "run"]
const SWITCH_STATES := ["to_walk", "to_fight"]
const DOUBLE_TAP_TICKS := 3
const MAX_QUEUE := 2  # P then K pressed during one long blow play P then K
const AIR_STATES := ["jump", "air_kick", "hammer_fist"]
## What food and first aid give back, as a share of a full health bar (D-14)
const HEALS := {"food": 0.4, "takeaway": 0.4, "sandwich": 0.4, "soda": 0.25, "apple": 0.25, "bowl": 0.4, "first_aid": 1.0, "noodles": 1.0,
	"protein_bar": 0.4, "shake": 0.4, "water": 0.25}  # (level 4's gym: a protein bar, a shake, Coach's water bottle)  # noodles: level 2's hidden bar
## Being hit: no input counts until the reaction ends (fight.gd decides who hits whom; take_hit() reacts); "held":
## in the Grabber's bear hug, where only wriggling counts (3 quick punches, or a roll)
const HURT_STATES := ["hurt", "block_hit", "stagger", "push", "knockdown", "launch", "down", "get_up", "ko", "dizzy", "held",
	"tumble"]
const ESCAPE_TAPS := 3
const DUCK_TICKS := 12  # how long a duck under a high kick lasts, before he comes up

var tune: Dictionary
var world = null
var x := 0.0
var z := 0.0
var y := 0.0  # feet height; standing on a car, y is the car's top
var vx := 0.0
var vy := 0.0
var facing := 1  # 1 = right, -1 = left
var state := "idle"
var stance := "fight"  # "fight" (the guard) or "walk" (relaxed)
var squat_mx := 0.0  # the stick when the jump was pressed: a running jump still carries forward from its crouch
var roll_dir := 1  # which way along the street a roll goes (+1 right, -1 left)
var roll_mz := 0.0  # and up or down the street
var t := 0  # ticks spent in the current state
var queue: Array[String] = []  # buttons pressed early, in order, waiting for the fighter to be free
var buffer_left := 0  # once free, how long the waiting presses stay good
var clock := 0  # ticks since this fighter was made
var last_press := -100  # the tick of the last attack button that counted
var chain := ""  # the combo so far ("P", "PK", …); "" = none
var chain_until := -1  # the last tick a press still continues the chain (the blow's end + combo_window_ticks)
var attack_serial := 0  # counts attacks, so a world can tell one blow from the next
var air_kicked := false  # one air attack (flying kick or hammer fist) per jump
var push_ticks := 0  # how long the stick has pushed into something climbable
var climb_from := Vector2.ZERO  # (x, y) where a climb started
var climb_to := Vector2.ZERO  # (x, y) where it ends, on top
var climb_z := Vector2.ZERO  # up or down a ladder: the depth it starts from and ends at
var on_ladder := false  # this climb is a ladder's (straight up or down, slower)
var can_climb := true  # ladders are the hero's (enemies don't climb in level 2)
var team := 0  # 0 = the hero's side; blows only land on the other team
var max_health := 20.0
var health := 20.0
var weapon := ""  # what this fighter carries ("pipe", …); an enemy drops it when knocked down (take_weapon())
var weapon_hits_left := 0  # it wears out (D-14)
var soft := false  # a sparring friend: his blows don't hurt
var shield := 0  # blows something he's holding will take for him (level 1's umbrella: one, then it breaks)
var rubber := false  # rubber gloves on (Mr. Static's prize): a perfect block takes a shock like any blow
## The team's roster, each enemy's own trick: blows (by move) he ducks or hops out of, blows he parries with his
## weapon, slow weapons he's too quick for (the Neon Dancer)
var slam_in := -1  # frames till his floor slam lands (Mr. Static's), -1 when none: what a watcher reads to jump it
var charging := false  # winding up for or running a charge (Coach Crusher's tackle): what a watcher reads to step aside
var no_swing := false  # no room to swing a weapon here (the crane's cab): fists and feet only, the weapon kept
var reads_combos := false  # parries a combo used twice in a row (Madame Chrome; the Godfather's rage round): mix it up
var hit_scale := 1.0  # his blows' damage, scaled (the team's balance ruling, 11-04: the Mechanic hits softer up close)
var stays_up := false  # knockdown and launch blows only stagger him
var unflinching := false  # every blow hurts, none rocks him (Twin Loans' opening swap, the team's third ruling)
var min_health := 0.0  # blows can't take him lower than this (the Godfather's rage round: only the dizzy finisher ends it)
var armour := false  # a coat only the Lovelight cuts: every other blow bounces off (the Godfather's first round)
var only_counters := false  # too fast for anything but a blow into his wind-up (the Godfather's second round)
var catches := false  # a thrown weapon coming at his front is caught, not taken (the Godfather's)
var keeps_weapon := false  # a boss's signature weapon: not worn out, not knocked loose by a counter or a knockdown;
# only its own rule ends it (Madame Chrome's cane: three kicks into its wind-up; Velvet Rook's sword: three perfect blocks)
var grip := false  # a perfect block doesn't knock his weapon loose (a boss's own: Velvet Rook's sword, Mr. Static's baton)
var gloves := []  # blows his guard takes every time from the front, without raising it (Coach Crusher's big gloves)
var dodges := []
var parries := []
var too_quick := false  # the Neon Dancer on skates: every weapon but the light ones (knife, stick) misses her (roster v4)
var held_by = null  # who holds him in a bear hug: a thrown weapon hits him instead (the team's house rule)
var from_kick := false  # this blow is a weapon strike in a kick's place (Pippin's grips page): it counts as a kick
var escape_taps := 0  # held: punches tapped so far toward wriggling free
var weapon_snaps := false  # his weapon breaks as it's knocked loose (level 2's pipe Bruiser: the pipe stays level 5's prize)
var shrugs := []  # blows (by move) that hurt him but don't make him flinch (the Bruiser's "Iron Gut": a jab)
var no_pickup_until := -1  # knocked out of his hand, a weapon can't be grabbed straight back (until this tick)
var knock_dir := 1  # which way the last blow drove him (+1 right, -1 left)
var finishers_taken := 0  # combo finishers landed on him in a row (D-19: two make him dizzy)
var last_finisher := -1000  # the tick the last one landed
var dizzy_left := 0  # ticks of dizziness still to come once the blow's reaction ends
## Pain, not blood (D-9; DESIGN, "Pain, not blood"): every blow hurts the part it lands on, and the parts go fresh →
## bruised → swollen → broken. A broken leg limps (slower), a broken arm hits weaker (and, with weapons, can't swing
## one). The head and chest stop at swollen. It heals between levels (heal()).
var pain := {"head": 0.0, "chest": 0.0, "arm_f": 0.0, "arm_b": 0.0, "leg_f": 0.0, "leg_b": 0.0}
var just_broke := ""  # the part the last blow broke, or "" (for the crack sound)


func _init(tuning: Dictionary = {}, start_x := 200.0, start_z := 80.0, street = null) -> void:
	tune = tuning if not tuning.is_empty() else Tuning.fresh()
	x = start_x
	z = start_z
	world = street
	max_health = tune.get("health", 20.0)
	health = max_health


func step(inp: Dictionary) -> void:
	var mx: float = clampf(inp.get("mx", 0.0), -1.0, 1.0)
	var mz: float = clampf(inp.get("mz", 0.0), -1.0, 1.0)
	clock += 1
	if state == "held":  # the bear hug: tap punch fast, or roll, to wriggle free
		t += 1
		queue.clear()
		if inp.get("punch", false):
			escape_taps += 1
		if escape_taps >= ESCAPE_TAPS or inp.get("roll", false):
			escape_taps = 0
			_enter("idle")
		return
	if state in HURT_STATES:
		t += 1
		queue.clear()
		_react()
		return
	if inp.get("throw", false) and weapon != "" and state in GROUND_STATES and not no_swing:
		vx = 0.0  # the weapon in hand, thrown (level.gd lets it fly at the release)
		attack_serial += 1
		_enter("throw")
		return
	for own in ["grab", "headbutt"]:  # enemies' own moves (the Grabber's, the Mechanic's): no button reaches them
		if inp.get(own, false) and state in GROUND_STATES:
			vx = 0.0
			attack_serial += 1
			_enter(own)
			return
	for b in ["jump", "punch", "kick", "sweep"]:
		if inp.get(b, false):
			# during a blow, a press is kept until the blow ends, so a rhythm of presses chains a combo; a press
			# hard on the heels of the last one (a bounced or doubled tap) is dropped, so it can't fire twice
			if b != "jump":
				if clock - last_press < DOUBLE_TAP_TICKS:
					continue
				last_press = clock
			if queue.size() < MAX_QUEUE:
				queue.append(b)
			buffer_left = tune["buffer_ticks"]
	t += 1
	# C: the evasion roll (Javier, 2026-11-02 21:56: "c for evation role (direction of the keys)"), from the ground or a
	# block, the way the arrows point (forward if none), facing the threat the whole time
	if inp.get("roll", false) and (state in GROUND_STATES or state == "block") and queue.is_empty():
		chain = ""
		roll_dir = int(signf(mx)) if mx != 0.0 else facing
		roll_mz = mz
		_enter("roll")
		return
	if inp.get("stance", false) and state in GROUND_STATES and queue.is_empty():
		vx = 0.0
		stance = "walk" if stance == "fight" else "fight"
		_enter("to_walk" if stance == "walk" else "to_fight")
		return
	match state:
		"idle", "walk", "stand", "stroll", "run":
			_ground(mx, mz, inp.get("run", false))
		"to_walk", "to_fight":
			if t >= tune["stance_switch_ticks"]:
				_enter(_rest())
		"roll":
			_roll()
		"jump", "air_kick", "hammer_fist":
			if state == "jump" and not queue.is_empty() and queue[0] in ["punch", "kick"] and not air_kicked:
				var move: String = _armed(Moves.AIR["P" if _take_buffer() == "punch" else "K"])
				air_kicked = true
				attack_serial += 1
				_enter(move)
			_air(mx)
		"block":
			if mx != 0.0:
				facing = 1 if mx > 0.0 else -1  # turn to face a threat without dropping the guard
			if not inp.get("block", false):
				_enter("idle")
		"land":
			if t >= tune["land_ticks"]:
				_enter(_rest())
		"jump_squat":
			# the crouch before take-off, feet planted; then the legs drive him up (the stick steers the jump)
			if t >= tune["jump_squat_ticks"]:
				vy = Tuning.takeoff_speed(tune)
				vx = (mx if mx != 0.0 else squat_mx) * tune["jump_speed"]
				_enter("jump")
		"climb":
			_climb()
		"duck":
			if t >= DUCK_TICKS:
				_enter(_rest())
		_:
			if _ground_attack() and t >= attack_length(state):
				# a press up to combo_window_ticks frames after this one continues the chain: exactly the setting (the
				# testers, 2026-11-03: a countdown made it 22 frames against the setting's 24)
				chain_until = clock + tune["combo_window_ticks"]
				_enter("idle")
	# a blow or a block from the walk stance raises the guard first; the press waits through it
	if stance == "walk" and state in GROUND_STATES and (inp.get("block", false) or (not queue.is_empty() and queue[0] != "jump")):
		vx = 0.0
		stance = "fight"
		_enter("to_fight")
	# a fighter who just became free acts on a buffered button in the same tick
	if (state in GROUND_STATES or state == "block") and not queue.is_empty():
		_start(_take_buffer(), mx)  # a press from the guard comes straight out of it
	if state in GROUND_STATES and inp.get("block", false):
		chain = ""
		vx = 0.0
		_enter("block")
	if not _ground_attack() and not state in SWITCH_STATES:
		if clock >= chain_until:
			chain = ""
		if buffer_left > 0:
			buffer_left -= 1
			if buffer_left == 0:
				queue.clear()


func _ground_attack() -> bool:
	return Moves.is_move(state) and not Moves.is_air(state)


func _take_buffer() -> String:
	return queue.pop_front()


func _blocked(nx: float, nz: float) -> bool:
	return world != null and world.blocks(nx, nz, y)


## The flight of stairs he's on, up off the street (one fighter deep: no stepping sideways off it), or {}.
func flight() -> Dictionary:
	if world == null or y < 1.0:
		return {}
	return world.stairs_under(x, z, y)


## Feet on the step under him after moving along a flight (up or down it); a step ahead of the landing's end is as far
## as the flight goes (the floor above is reached through the level's link there).
func _settle() -> void:
	if world == null or state == "launch" or state in AIR_STATES:
		return
	var st: Dictionary = world.stairs_under(x, z, y)
	if not st.is_empty():
		x = minf(x, st["x1"] - 4.0)
		y = world.step_height(st, x)


## Where a free fighter rests: the guard in the fight stance, standing relaxed in the walk stance.
func _rest() -> String:
	return "idle" if stance == "fight" else "stand"


func _ground(mx: float, mz: float, run := false) -> void:
	if run and mx == 0.0:
		mx = float(facing)  # W alone runs the way he faces; an arrow steers it (Javier, 2026-11-02: "W don't work")
	var moving: bool = mx != 0.0 or (mz != 0.0 and not tune["flat_line"])
	var speed := "walk_speed"
	if run and moving:
		speed = "run_speed"
	elif stance == "walk":
		speed = "stroll_speed"
	# at a ladder: up climbs it from its foot, down climbs it from the top (the team's level 2: "press up to climb,
	# down to come off")
	if can_climb and world != null and absf(mz) > 0.5:
		var lad: Dictionary = world.ladder_near(x, z, y)
		if not lad.is_empty() and ((lad["at"] == "foot" and mz < 0.0) or (lad["at"] == "top" and mz > 0.0)):
			var o: Dictionary = lad["ladder"]
			var cx: float = (o["x0"] + o["x1"]) * 0.5
			climb_from = Vector2(x, y)
			climb_to = Vector2(cx, o["top"] if lad["at"] == "foot" else 0.0)
			climb_z = Vector2(z, maxf(0.0, o["z0"] - 25.0) if lad["at"] == "foot" else o["z1"] + 30.0)
			on_ladder = true
			vx = 0.0
			_enter("climb")
			return
	vx = mx * tune[speed] * (tune["limp"] if limping() else 1.0)
	var nx := clampf(x + vx, tune["street_left"], tune["street_right"])
	if mx != 0.0:
		facing = 1 if mx > 0.0 else -1
	var on_flight := not flight().is_empty()
	if _blocked(nx, z):
		_push(mx)
	else:
		x = nx
		push_ticks = 0
	if not tune["flat_line"] and not on_flight:
		var nz := clampf(z + mz * tune["depth_speed"], 0.0, tune["street_depth"])
		if not _blocked(x, nz):
			z = nz
	if state == "climb":
		return
	_settle()
	# D-14: the health bar refills from food and first-aid kits lying on the street; the hero eats what he walks over
	# when he's hurt (an enemy leaves them)
	# level 1's umbrella, leaning on the noodle bar: he takes it up; it will take one blow for him
	if team == 0 and shield == 0 and world != null and not world.items.is_empty():
		for it in world.items:
			if it["kind"] == "umbrella" and absf(it["x"] - x) <= Weapons.PICK_UP_REACH and absf(it["z"] - z) <= Weapons.PICK_UP_REACH:
				shield = 1
				world.items.erase(it)
				break
	if team == 0 and not rubber and world != null:  # Mr. Static's rubber gloves: put on, and kept
		for it in world.items:
			if it["kind"] == "rubber_gloves" and absf(it["x"] - x) <= Weapons.PICK_UP_REACH and absf(it["z"] - z) <= Weapons.PICK_UP_REACH:
				rubber = true
				world.items.erase(it)
				break
	if team == 0 and health < max_health and world != null and not world.items.is_empty():
		for it in world.items:
			if HEALS.has(it["kind"]) and absf(it["x"] - x) <= Weapons.PICK_UP_REACH and absf(it["z"] - z) <= Weapons.PICK_UP_REACH \
					and absf(it.get("y", 0.0) - y) < 20.0:
				health = minf(max_health, health + HEALS[it["kind"]] * max_health)
				world.items.erase(it)
				break
	# walking over a weapon with an empty hand picks it up (the bag for more than one comes with Stage 4)
	if weapon == "" and world != null and not world.items.is_empty() and clock >= no_pickup_until:
		var it: Dictionary = Weapons.within_reach(world.items, x, z, y)
		if not it.is_empty():
			world.items.erase(it)
			take_weapon(it["kind"])
	if world != null and world.floor_at(x, z, y) < y - 0.5:
		vy = 0.0  # walked off an edge: fall
		_enter("jump")
		return
	var next := _rest()
	if moving:
		next = "run" if run else ("walk" if stance == "fight" else "stroll")
	if next != state:
		_enter(next)


## Pushing into something: after a moment, climb it if it's climbable and not too tall.
func _push(mx: float) -> void:
	if mx == 0.0:
		push_ticks = 0
		return
	var o: Dictionary = world.ahead(x, z, y, facing)
	if o.is_empty() or not o["climbable"] or o["top"] - y > tune["climb_max"]:
		push_ticks = 0
		return
	push_ticks += 1
	if push_ticks >= tune["climb_hold_ticks"]:
		push_ticks = 0
		var edge: float = o["x0"] if facing == 1 else o["x1"]
		climb_from = Vector2(x, y)
		climb_to = Vector2(edge + facing * 30.0, o["top"])
		_enter("climb")


func _climb() -> void:
	if on_ladder:  # hand over hand, straight up or down
		var lk := clampf(float(t) / float(tune.get("ladder_ticks", 45)), 0.0, 1.0)
		y = lerpf(climb_from.y, climb_to.y, lk)
		x = lerpf(climb_from.x, climb_to.x, clampf(lk * 4.0, 0.0, 1.0))
		z = lerpf(climb_z.x, climb_z.y, lk)
		if lk >= 1.0:
			on_ladder = false
			_enter(_rest())
		return
	var k := clampf(float(t) / float(tune["climb_ticks"]), 0.0, 1.0)
	# up first, then over the edge
	y = lerpf(climb_from.y, climb_to.y, clampf(k * 1.6, 0.0, 1.0))
	x = lerpf(climb_from.x, climb_to.x, clampf(k * 1.6 - 0.6, 0.0, 1.0))
	if k >= 1.0:
		y = climb_to.y
		x = climb_to.x
		_enter(_rest())


func _air(mx: float) -> void:
	# a jump keeps its momentum; only a pushed stick bends it (letting go mid-air must not brake)
	if mx != 0.0:
		vx = lerpf(vx, mx * tune["jump_speed"], tune["air_steer"] * 0.1)
	var nx := clampf(x + vx, tune["street_left"], tune["street_right"])
	if _blocked(nx, z):
		vx = 0.0  # bumped into the side of something
	else:
		x = nx
	var ground: float = 0.0 if world == null else world.floor_at(x, z, y)
	y += vy
	vy -= Tuning.gravity(tune)
	if y <= ground:
		y = ground
		vy = 0.0
		air_kicked = false
		_enter("land")


func _start(action: String, mx: float) -> void:
	if action == "jump":
		chain = ""
		vx = 0.0
		if tune["jump_squat_ticks"] > 0:
			squat_mx = mx
			_enter("jump_squat")  # a crouch first: recorded jumps load the legs before they leave the ground
		else:
			vy = Tuning.takeoff_speed(tune)
			vx = mx * tune["jump_speed"]
			_enter("jump")
	elif action == "sweep":
		# its own move on Z (Javier, 2026-11-02 19:28), outside the combos: it ends any chain
		vx = 0.0
		attack_serial += 1
		chain = ""
		chain_until = -1
		_enter(_armed("sweep"))
	else:
		vx = 0.0
		attack_serial += 1
		var link: Array = Moves.next(chain, "P" if action == "punch" else "K")
		chain = link[0]
		chain_until = -1
		_enter(_armed(link[1]))


## Takes a blow from attacker (fight.gd calls it once per blow). Returns "hit", "blocked", "perfect", "evaded", or ""
## when he can't be hit at all (falling, lying, getting up).
func take_hit(blow: Dictionary, attacker) -> String:
	if evading():
		return "evaded"
	if not hittable():
		return ""
	var dir := 1 if x >= attacker.x else -1  # driven away from whoever hit him
	knock_dir = dir
	var move: String = blow.get("move", "")
	if move in dodges or (too_quick and blow.get("weapon_speed", -99) >= 0):
		if move in dodges and state in GROUND_STATES:
			_enter("duck")  # down under the high kick (the Wrench Mechanic): he comes up out of it
		return "dodged"  # under it, or gone before it lands
	if move in parries and facing == -dir and state in GROUND_STATES:
		return "parried"  # caught on the flat of his blade
	if armour and not (attacker is Object and attacker.weapon == "lovelight"):
		return "bounced"  # off the armoured coat: only the Lovelight cuts it
	if only_counters and not blow.get("counter", false) and state in GROUND_STATES:
		return "dodged"  # too fast: only a blow into his wind-up catches him
	if move in gloves and facing == -dir and state in GROUND_STATES + ["block", "block_hit"]:
		_enter("block_hit")
		return "blocked"  # the big gloves take it: no harm done
	if weapon == "shield" and facing == -dir:
		return "shielded"  # everything from the front bounces off the Doorman's shield
	if blow.get("effect", "") == "grab":
		queue.clear()
		escape_taps = 0
		_enter("held")  # right through the guard
		return "grabbed"
	var guard := blocking()
	just_broke = ""
	if guard != "" and facing == -dir:  # only a guard facing the blow stops it
		if guard == "perfect":
			return "perfect"
		health = maxf(health - blow["damage"] * tune["block_damage"], 0.0)
		_hurt("arm_f", blow["damage"] * tune["block_damage"])  # the forearms take a blocked blow
		if blow.get("guard_break", false):
			_enter("stagger")  # a heavy overhead smash knocks the guard open (break it, don't block it)
			return "guard_broken"
		_enter("block_hit")
		return "blocked"
	if shield > 0:
		shield -= 1
		return "umbrella"  # the umbrella takes it, and breaks
	health = maxf(health - blow["damage"], min_health)
	_hurt(region_hit(blow, attacker), blow["damage"])
	if (blow.get("move", "") in shrugs and blow.get("effect", "") == "" or unflinching) and health > 0.0:
		return "hit"  # it hurts, but he doesn't flinch: whatever he was doing goes on
	stance = "fight"  # a hit snaps him out of the walk stance
	queue.clear()
	chain = ""
	chain_until = -1
	vx = 0.0
	var effect: String = blow.get("effect", "")
	if health <= 0.0 and effect != "launch":
		effect = "knockdown"  # the last blow puts him down, for good
	if stays_up and effect in ["knockdown", "launch"]:
		effect = "stagger"  # too angry to fall (the Godfather's rage round): rocked, still on his feet, the count kept
	if effect in ["knockdown", "launch"]:
		roll_dir = facing  # the drawing falls him backward, the way he faces
		dizzy_left = 0  # put down, he comes up clear-headed
		finishers_taken = 0
	elif blow.get("finisher", false):
		# D-19: two hero combos in a row make him dizzy; any blow of his in between starts the count again (fight.gd)
		if finishers_taken >= 1 and clock - last_finisher <= tune["dizzy_window_ticks"]:
			dizzy_left = tune["dizzy_ticks"]
			finishers_taken = 0
		else:
			finishers_taken = 1
		last_finisher = clock
	match effect:
		"stagger", "push", "knockdown":
			_enter(effect)
		"launch":
			vy = 4.0 * tune["launch_height"] / float(tune["jump_air_ticks"])
			_enter("launch")
		_:
			_enter("hurt")
	return "hit"


## Where a blow lands on him, by the middle of its height band above his feet: the head (a jab, a cross, a hook, a
## side kick to the face, an uppercut), the body, or the legs (a low kick, a sweep). The lead side takes it.
func region_hit(blow: Dictionary, attacker) -> String:
	var mid: float = attacker.y + (blow.get("low", 100.0) + blow.get("high", 200.0)) * 0.5 - y
	if mid >= 175.0:
		return "head"
	if mid >= 100.0:
		return "chest"
	return "leg_f"


## 0 fresh, 1 bruised, 2 swollen, 3 broken (the head and chest top out at swollen).
func pain_stage(part: String) -> int:
	var p: float = pain[part]
	var stage := 3 if p >= tune["pain_broken"] else 2 if p >= tune["pain_swollen"] else 1 if p >= tune["pain_bruised"] else 0
	return mini(stage, 2) if part in ["head", "chest"] else stage


func broken(part: String) -> bool:
	return pain_stage(part) == 3


func limping() -> bool:
	return broken("leg_f") or broken("leg_b")


func _hurt(part: String, amount: float) -> void:
	var was := pain_stage(part)
	pain[part] += amount
	if pain_stage(part) == 3 and was < 3:
		just_broke = part


## The move a combo's press becomes with the weapon in hand (the team's weapon combos: the same presses, the weapon in
## the fist's place); bare-handed, or with the lead arm broken, the fist move itself.
func _armed(move: String) -> String:
	from_kick = false
	if weapon == "" or broken("arm_f") or no_swing:
		return move
	var kicked: String = Weapons.kick_armed(move, weapon)
	if kicked != move:
		from_kick = true  # (a kick press turned weapon strike still breaks a wind-up the way a kick did: Pippin)
		return kicked
	return Weapons.ARMED.get(move, move)


## Takes a weapon in hand, fresh, with all its hits to come.
func take_weapon(kind: String) -> void:
	weapon = kind
	weapon_hits_left = Weapons.TABLE[kind]["hits"] if Weapons.is_weapon(kind) else 0
	tune["weapon"] = kind


## Lets go of it (knocked loose, knocked down, worn out); returns what it was.
func drop_weapon() -> String:
	var was := weapon
	weapon = ""
	weapon_hits_left = 0
	tune.erase("weapon")
	no_pickup_until = clock + int(tune.get("regrab_ticks", 90))
	return was


## A blow with the weapon landed (on a body or a guard): it wears; worn through, it breaks and is gone. Returns what
## broke, or "".
func wear(amount: int) -> String:
	if weapon == "" or amount <= 0:
		return ""
	weapon_hits_left -= amount
	return drop_weapon() if weapon_hits_left <= 0 else ""


## Between levels the body mends (the hero carries his damage into the boss fight; DESIGN).
func heal() -> void:
	for part in pain:
		pain[part] = 0.0


## Out of a blow's reaction: dazed if two combos in a row got him (a hit while dazed doesn't clear it), else the guard.
func _recover() -> void:
	_enter("dizzy" if dizzy_left > 0 else "idle")


## Can a blow land on him now? Not while falling, lying or getting up (no hitting a man when he's down).
func hittable() -> bool:
	return not state in ["knockdown", "down", "get_up", "ko", "tumble"]


func defeated() -> bool:
	return state == "ko"


## Driven along the street by a blow: stopped by the street's ends and by anything in the way.
## Down to whatever is under him, under gravity (hit or knocked down while he was up in the air).
func _fall() -> void:
	var ground: float = 0.0 if world == null else world.floor_at(x, z, y)
	if y > ground:
		vy -= Tuning.gravity(tune)
		y = maxf(ground, y + vy)
		if y <= ground:
			vy = 0.0


func _slide(speed: float) -> void:
	var nx := clampf(x + knock_dir * speed, tune["street_left"], tune["street_right"])
	if not _blocked(nx, z):
		x = nx
	_settle()


func _react() -> void:
	if state != "launch" and state != "tumble" and state != "held":
		_fall()  # hit while up in the air (a jump, the crane's container): he comes down, he doesn't hang there
	match state:
		"tumble":
			pass  # rolling down a flight of stairs: the level rolls him (level.gd _stairs) and lays him at the foot
		"hurt", "block_hit":
			var n: int = tune[state + "_ticks"]
			_slide(tune["knockback"] * (1.0 - float(t) / n) * (0.5 if state == "block_hit" else 1.0))
			if t >= n:
				if state == "block_hit":
					state = "block"  # back in the guard, past its perfect window (no chain of perfect blocks)
					t = tune["perfect_block_ticks"]
				else:
					_recover()
		"stagger":
			_slide(tune["knockback"] * 0.8 * clampf(1.0 - float(t) / tune["stagger_ticks"], 0.0, 1.0))
			if t >= tune["stagger_ticks"]:
				_recover()
		"push":
			_slide(tune["push_speed"] * (1.0 - float(t) / tune["push_ticks"]))
			if t >= tune["push_ticks"]:
				_recover()
		"dizzy":
			dizzy_left -= 1
			if dizzy_left <= 0:
				dizzy_left = 0
				_enter("idle")
		"knockdown":
			if t < tune["knockdown_ticks"] / 2:
				_slide(tune["knockback"] * 1.2)
			if t >= tune["knockdown_ticks"]:
				_enter("ko" if health <= 0.0 else "down")
		"launch":
			_slide(tune["knockback"])
			var ground: float = 0.0 if world == null else world.floor_at(x, z, y)
			y += vy
			vy -= Tuning.gravity(tune)
			if y <= ground and vy < 0.0:
				y = ground
				vy = 0.0
				_enter("ko" if health <= 0.0 else "down")
		"down":
			if t >= tune["down_ticks"]:
				_enter("get_up")
		"get_up":
			if t >= tune["get_up_ticks"]:
				stance = "fight"
				_enter("idle")


func _enter(s: String) -> void:
	state = s
	t = 0


## Rolling along the street: the body moves the way the roll goes, stopped by what blocks it; then back to the rest.
func _roll() -> void:
	if t >= tune["roll_ticks"]:
		vx = 0.0
		_enter(_rest())
		return
	vx = roll_dir * tune["roll_speed"]
	var on_flight := not flight().is_empty()
	var nx := clampf(x + vx, tune["street_left"], tune["street_right"])
	if not _blocked(nx, z):
		x = nx
	_settle()
	if not tune["flat_line"] and not on_flight:
		var nz := clampf(z + roll_mz * tune["depth_speed"], 0.0, tune["street_depth"])
		if not _blocked(x, nz):
			z = nz


## True while a roll can't be hit: only while he is round, over the shoulder; in the dip and coming up he is open,
## so a dodge has to be timed (the team's roll reference, 2026-11-02).
func evading() -> bool:
	return state == "roll" and t >= int(tune["roll_ticks"] * tune["roll_evade_from"]) and t < int(tune["roll_ticks"] * tune["roll_evade_to"])


## "perfect" in a block's first perfect_block_ticks, "block" after that, "" when not blocking.
func blocking() -> String:
	if state != "block":
		return ""
	return "perfect" if t < tune["perfect_block_ticks"] else "block"


func on_ground() -> bool:
	return not state in AIR_STATES and state != "launch"


func attack_length(a: String) -> int:
	return Moves.length(a, tune)


## "startup", "active" or "recovery" while attacking; "" otherwise. Air attacks stay out until landing.
func attack_phase() -> String:
	if not Moves.is_move(state):
		return ""
	var d := Moves.data(state, tune)
	if t < d["startup"]:
		return "startup"
	if t < d["startup"] + d["active"]:
		return "active"
	return "recovery"


## The move being thrown, with its damage and effect (moves.gd), or {}.
func move() -> Dictionary:
	if not Moves.is_move(state):
		return {}
	var d := Moves.data(state, tune)
	var part := limb_part(d["limb"])
	if part != "" and broken(part):
		d["damage"] = d["damage"] * 0.5  # a blow with a broken arm or leg lands weak
	return d


## Which of his parts throws a blow with this limb ("hand_f" → "arm_f", "leg_b_lower" → "leg_b"), or "".
static func limb_part(limb: String) -> String:
	var side := "f" if limb.ends_with("_f") or limb.contains("_f_") else "b"
	if limb.begins_with("hand") or limb.begins_with("arm"):
		return "arm_" + side
	if limb.begins_with("foot") or limb.begins_with("leg"):
		return "leg_" + side
	return ""


## The space a blow covers this tick, or {} when nothing can be hit: {x0, x1, z0, z1} on the street.
func hit_box() -> Dictionary:
	if attack_phase() != "active":
		return {}
	var reach: float = move()["reach"]
	var near := x + facing * 20.0
	var far := x + facing * reach
	return {"x0": minf(near, far), "x1": maxf(near, far), "z0": z - tune["hit_depth"], "z1": z + tune["hit_depth"]}


func snapshot() -> Array:
	return [snappedf(x, 0.001), snappedf(z, 0.001), snappedf(y, 0.001), facing, state, t]
