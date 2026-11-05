extends RefCounted
## A level as runs of fights on one or more floors (DESIGN, The levels: one floor in levels 1-2, two in 3-5, up to
## three in 6-8 where switches upstairs open doors below; the boss at the end). The layout is data (levels/levelN.json),
## so the team's layouts drop straight in. Plain logic like fighter.gd: it spawns the fighters, holds the hero at a wave
## until it's beaten (the floor "locks" there), moves him between floors by the stairs (walk into the doorway at the back
## of the street), lets a blow flip a switch that opens a door on another floor, and the level is won when the boss is
## down for good. Three lives per level; losing them all restarts the level from its start (D-15). Seeded, so a run
## replays the same (the bot plays every level on several seeds: L-8).
##
## The data, full form: {name, floors: [{name, length, obstacles, items, waves}...], links: [{from, x, to, to_x}...],
##   switches: [{floor, x, opens}...], boss: {floor, x, kind, health, weapon}}
## Obstacles: [kind, x0, x1, z0, z1, top, climbable, strength, name?] (a "door" with a name opens from a switch);
## items: [kind, x, z]; waves: [{at, enemies: [{kind, dx, z, weapon}]}...].
## The short form (level 1): one street ({length, obstacles, items, waves}), "stairs" at the end up to the boss's room
## ("upstairs_length", "boss").

const Fighter := preload("res://scripts/sim/fighter.gd")
const Fight := preload("res://scripts/sim/fight.gd")
const Moves := preload("res://scripts/sim/moves.gd")
const Brain := preload("res://scripts/sim/brain.gd")
const StreetWorld := preload("res://scripts/sim/street_world.gd")
const Tuning := preload("res://scripts/sim/tuning.gd")
const Projectiles := preload("res://scripts/sim/projectiles.gd")
const Tutor := preload("res://scripts/sim/tutor.gd")
const Weapons := preload("res://scripts/sim/weapons.gd")

## Enemy types by name: health, how they fight (brain.gd tables), what they drop when put down for good, and blows
## that don't make them flinch. From the team's enemy table (art-in 2026-11-03): the Glow Punk, the warm-up (slap,
## slap, shove; drops food) and the Bruiser, the big lad (shrugs off a jab, "Iron Gut"; drops a bat).
const KINDS := {
	"thug": {"health": 12.0, "brain": "THUG"},
	"glow_punk": {"health": 8.0, "brain": "GLOW_PUNK", "drops": "takeaway"},
	"bruiser": {"health": 20.0, "brain": "BRUISER", "drops": "bat", "shrugs": ["punch"], "no_stairs": true},
	"boss": {"health": 40.0, "brain": "BOSS"},
	"dj_volt": {"health": 40.0, "brain": "DJ_VOLT", "drops": "bat"},
	"snick": {"health": 10.0, "brain": "SNICK", "weapon": "knife"},  # her knife falls when she's put down
	"bruiser_pipe": {"health": 20.0, "brain": "BRUISER", "weapon": "pipe", "shrugs": ["punch"], "snaps": true, "no_stairs": true},
	"big_mama": {"health": 50.0, "brain": "BIG_MAMA", "weapon": "wok", "drops": "wrench"},
	# level 3's boss, Twin Loans (the team's roster): two brothers, slow to climb back up a flight; the tall one has the
	# prize, the stick
	"twin_tall": {"health": 25.0, "brain": "TWIN", "drops": "stick", "twin": true},
	"twin_short": {"health": 25.0, "brain": "TWIN", "twin": true},
	# level 4's boss, Coach Crusher (the team's roster): gloves that block every punch, so kicks only; his prize waits on
	# the team's call (the "Last Call" combo, or a first-aid kit and his whistle): a first-aid kit for now
	# level 5's boss, Madame Chrome (the team's roster): her chrome cane snaps after three kicks into its wind-up, and
	# then she's done; the pipe is her prize (and the casino key, with level 5)
	"chrome": {"health": 40.0, "brain": "CHROME", "weapon": "cane", "drops": "pipe", "reads": true, "keeps_weapon": true, "grip": true},
	# level 7's boss, Mr. Static (the team's roster): a perfect block on his baton shocks the HERO; rubber gloves his prize
	"static": {"health": 40.0, "brain": "STATIC", "weapon": "baton", "drops": "rubber_gloves", "grip": true},
	# level 8's boss, Velvet Rook (the team's roster): the sword from his cane, held through perfect blocks till the
	# third on his last cut breaks it; parries the plain combos' finishers (P P P, K K K; the armed smash too)
	# level 6's boss, the Crane Operator (the team's roster): out of reach in his cab till the three switches are thrown;
	# P P K shoves him out of it, and that's it; the better knife his prize (it spins further once throwing comes)
	"crane_operator": {"health": 30.0, "brain": "CRANE", "drops": "knife"},
	# level 10's boss, the Godfather of Glow (the team's roster): three rounds (armour, speed, rage); he catches any
	# weapon thrown at him; his prize is the ending
	"godfather": {"health": 30.0, "brain": "GODFATHER_1", "catches": true},
	"rook": {"health": 45.0, "brain": "ROOK", "weapon": "sword", "drops": "sword", "grip": true, "keeps_weapon": true,
		"parries": ["power_punch", "side_kick", "smash"]},
	"coach": {"health": 40.0, "brain": "COACH", "drops": "first_aid",
		"gloves": ["punch", "cross", "power_punch", "hook", "uppercut", "elbow", "hammer_fist", "air_punch",
			"swing", "backswing", "smash", "rising_swing", "handle_jab", "chop"]},  # (and weapon swings: the team's level 4)
	# the rest of the team's roster (enemy roster v2)
	"wrench_mechanic": {"health": 14.0, "brain": "WRENCH_MECHANIC", "weapon": "wrench", "dodges": ["side_kick", "roundhouse"],
		"hit_scale": 0.6},  # (the team's balance ruling, 11-04: softer up close; his thrown wrench as it was)
	"doorman": {"health": 18.0, "brain": "DOORMAN", "weapon": "shield", "no_stairs": true},  # (off the stairs: his only weak side
	# is his back, and nobody walks round anyone on a flight; the team's level 5)
	"neon_dancer": {"health": 12.0, "brain": "NEON_DANCER", "too_quick": true, "speed": 1.8, "drops": "stick", "no_stairs": true},  # (skates on flat floor only)
	"enforcer": {"health": 20.0, "brain": "ENFORCER", "weapon": "sword", "parries": ["punch"]},
	"lookout": {"health": 1.0, "brain": "LOOKOUT", "drops": "takeaway"},
	"grabber": {"health": 22.0, "brain": "GRABBER", "drops": "takeaway"},
}
## DJ Volt's records (the team: "three records thrown like frisbees, low, middle, high"): their height bands above the
## street, how fast they fly, how far apart in time, what they do
const RECORDS := [[0.0, 60.0], [110.0, 180.0], [210.0, 280.0]]
const RECORD_SPEED := 9.0
const RECORD_GAP := 14
const RECORD_DAMAGE := 1.5
## "Bass Drop": a guard held this long while his speakers stand, and the music's wave pushes the hero back
const BASS_HOLD := 120
## Big Mama Noodle's kitchen (the team's level 2): her hot soup comes on the hero's third block in a row; running onto
## the wet patch by the sink she slips and is dazed at once; at half health she mops it dry; a blow on the tap floods it.
const SOUP_AFTER_BLOCKS := 3
const SOUP_DAMAGE := 2.0
const SLIP_DAZE := 150
const HINT_TICKS := 240  # a wave's hint stays up this long
const WHISTLE_EVERY := 360  # the lookout whistles in two more goons this often while he's up and the hero's near
# (about six seconds: the team's level 3 page, feel lab)
const WHISTLE_RANGE := 1000.0
const HUG_TICKS := 70  # the bear hug: this long without wriggling free, and he throws the hero down
const HURL_DAMAGE := 3.0
const GENTLE_THROW := 1.5  # the first bear hug's throw where a level says so: a plain knockdown's damage (feel lab)
## The stairs (the team's level 3 page): a push kick or any knockdown on the slope rolls him to the foot, bowling over
## anyone below him; a bit more damage than a plain knockdown and about two seconds before he's up (feel lab)
const TUMBLE_SPEED := 10.0  # px a tick down the flight
const TUMBLE_DAMAGE := 1.5
const TUMBLE_DOWN_EXTRA := 46  # on top of down_ticks and get_up_ticks: about 2 s on the street in all
const ONE_AT_A_TIME := ["enforcer", "neon_dancer"]  # of these kinds only one swings (or skates in) at a time (rulings two and three)
const TWIN_OPEN_RANGE := 600.0  # how near he is when the brothers open with their swap
const SWINGING_MAX := 2  # enemies throwing a blow at once (the team's balance ruling, 2026-11-04)
const ON_STAIRS_MAX := 2  # enemies on the slope at once; the rest wait at the top or the foot
const BALL_SPEED := 10.0  # Coach Crusher's medicine ball, at the chest
const BALL_DAMAGE := 2.0
const TACKLE_DAMAGE := 3.0
const TACKLE_REACH := 70.0  # he runs into the hero when this close along the street (and on his line of the street)
const ROPES_DAZE := 70  # the tackle missed: he slams into the ropes and is open this long
const VENDING_REACH := 30.0  # the machine falls across its own width and this much either side...
const VENDING_FALL := 150.0  # ...onto the street in front of it, this deep
const VENDING_DAMAGE := 2.0
const SHOVE_TICKS := 50  # the Crane Operator flying out of his cab: this long
const SHOVE_DISTANCE := 1150.0  # out through the cab's open door and off the screen
const SHOVE_HEIGHT := 140.0  # up in an arc...
const SHOVE_DROP := 260.0  # ...and down past the cab's floor as he goes over the side
## Level 4's balcony gap (the team's page, Javier's yes 2026-11-04): a goon standing at the gap in the low railing, at the
## balcony's front edge, push-kicked or knocked down, tips over the bar and drops to the ring hall below: out of the
## fight, counted as beaten, nothing dropped. The hero never goes over (the street's edge holds him: for him it's a wall).
const GAP_REACH := 45.0  # how near the front edge he must stand to be "at the gap"
const GAP_TICKS := 40  # tipping over the bar and dropping out of sight
const GAP_FORWARD := 60.0  # out past the railing...
const GAP_DROP := 520.0  # ...and down to the floor below
const RING_IN := 150.0  # a ring's ropes stand this far inside the room's walls (so the camera shows them give)
const SWAP_LANE := 45.0  # crossing, the attacker passes this far in front of where they stood, his brother behind
const SWAP_TICKS_MAX := 150  # a crossing that hasn't arrived by then (a prop in the way) ends where they stand
const REBOUND_TICKS := 16  # off the ropes he bounces back this long (the team's level 4: "he bounces off the ropes")
const REBOUND_SPEED := 11.0  # px a frame at the start of the bounce, easing to nothing (about 90 px in all)
const TACKLE_WINDUP := 30  # first he backs off a few steps, head down, then charges: time to step aside (feel lab)
const CARD_SPEED := 12.0  # Madame Chrome's cards, three in a row at the chest and the head
const CARD_DAMAGE := 1.0
const CARDS := [[110.0, 180.0], [200.0, 270.0], [110.0, 180.0]]
const CHROME_OPEN := 50  # after her cards she's open this long: no guard, no parry
const CANE_KICKS := 3  # kicks into the cane's wind-up that snap it
const KICKS := ["kick", "body_kick", "side_kick", "push_kick", "front_kick", "roundhouse", "spin_kick", "air_kick", "sweep"]
const SLAM_WINDUP := 24  # Mr. Static raises the baton over his head, crackling, then slams the floor
const LIVE_TICKS := 30  # and it's live this long: jump as it comes down (a jump stays up 40 frames; the team's page
# says "for a second", feel lab: half a second is what a jump can clear)
const SHOCK_DAMAGE := 1.5
const TANK_REACH := 140.0  # P P K'd in this close to the water tank, he shorts out
const TANK_DAMAGE := 3.0
const CRANE_EVERY := 300  # the crane swings a container along the floor this often (while it runs)
const CRANE_WARN := 60  # its warning: the horn and the container showing at the edge of the floor
const CONTAINER_SPEED := 16.0
const CONTAINER_WIDTH := 200.0
const CONTAINER_TOP := 100.0  # it swings this low: jump it (a jump peaks at 150)
const CONTAINER_DAMAGE := 3.0
const CRATE_WARN := 40  # a crate's shadow shows this long before it lands
const CRATE_DAMAGE := 2.0
const HORN_REACH := 320.0
const ROOK_BREAKS := 3  # perfect blocks on his last cut that break his sword
const CHECKMATE_EVERY := 600  # his Enforcers come at most this often (one a door switch still standing)
const TWIN_CLIMB := 0.3  # how fast a Twin Loans brother goes up a flight, of his walk: knocked down it, about ten
# seconds before he's back up (the team's roster, feel lab)
const MAX_ON_SCREEN := 5  # never more than five enemies at once; the rest wait off screen (the team's fairness rules)
const OFF_SCREEN := 1150.0  # "from the left/right": they walk in from this far beyond the wave's spot
const AMBUSH := 260.0  # a hidden enemy jumps out when the hero comes this close
const LIVES := 3
const LOCK_MARGIN := 700.0  # a floor "locks" this far either side of a wave until it's beaten
const ATTACKERS := 2  # at most this many enemies attack at once; the rest wait their turn (a fair fight in a crowd)
const DOWN_TICKS := 150  # a fighter put down for good lies this long before he's gone (an enemy) or respawns (the hero)
const DOORWAY := 50.0  # standing this close to a stairs' x at the back of the street (z under DOORWAY_Z) takes them
const DOORWAY_Z := 12.0
const SWITCH_REACH := 30.0  # a blow whose reach covers a switch's x (± this) flips it

var data: Dictionary
var plan: Dictionary  # the level in its full form (short layouts are unfolded into it)
var tune: Dictionary
var floors := []  # each {name, length, world, waves, wave, active_wave, enemies}
var on := 0  # the floor he's on
var visited := {0: true}  # the floors he's been on (the bot doesn't go back up a ladder it came down)
var hero
var fight
var flipped := {}  # switch index -> true once flipped
var boss_spawned := false
var arrived_x := -1.0e9  # where he came up or down the stairs: that doorway doesn't take him straight back
var lives := LIVES
var won := false
var lost := false  # out of lives: the level restarts (restart())
var tick := 0
var hero_down_for := 0
var dice_seed := 1
var dice := RandomNumberGenerator.new()  # the level's own chances (where the crane's crates land)
var events := []  # this tick's fight events (for sounds and the view)
var collected := []  # what the hero has found (a matchbook, the torn photo)
var projectiles  # what's flying (records)
var held_guard := 0  # how long the hero has held his guard, for DJ Volt's Bass Drop
var bass_at := -1  # the tick the last bass wave went out (for the view and the sound)
var wet := true  # Big Mama's kitchen floor by the sink
var mopped := false  # she's mopped it once (at half health)
var blocks_in_row := 0  # the hero's blocks in a row against her (her hot soup)
var hug := {}  # the bear hug under way: {by (the grabber's entry), at (tick)}
var tumbling := {}  # fighter -> the flight he's rolling down
var compound := false  # Twin Loans at half their health: both rush the hero together
var climbing_back := {}  # fighters tumbled down a flight, on their way back up (a Twin Loans brother: slowly)
var live_until := -1  # Mr. Static's floor, live till this tick
var shocked_beat := {}  # who a live strip has shocked this beat
var crane := {}  # the docks' crane (the plan's "crane"): {next, container {x, dir, hit}, crates [{x, z, at}]}
var hint_text := ""  # a wave's small hint, the first time (shown till hint_until)
var hint_until := -1
var hints_shown := {}
var hugs_thrown := false
var used_moves := {}  # the hero's moves used this level (a wave's hint about one he already knows is skipped)  # a bear hug has thrown him this level (the first is gentle where the level says)
var rope_hit := {}  # the ropes he last slammed into (the view bends them a moment): side, z, tick
var crossing := {}  # Twin Loans walking past each other mid-combo ("Interest"): who, from where, to where
var twins_opened := false  # Twin Loans have opened with their swap (the team's third ruling)
var early := []  # events from before this tick's blows are settled (the twins' swap): joined to events after
var cat_fed := false  # level 1's stray cat, fed (it follows him, and turns up in level 2)
var cat := Vector2(-1.0e9, 0.0)  # where the cat is (x, z): by its bins, or at his heels once fed
var cat_with := 0  # how long he's stood by it
const CAT_FEED_TICKS := 60
var friend = null  # the sparring friend (level 1's first screen), a fighter on his own side
var tutor = null  # his lessons (sim/tutor.gd)
var hero_tune: Dictionary

## The floor he's on, as the game and the tests read it
var world:
	get: return floors[on]["world"]
var enemies: Array:
	get: return floors[on]["enemies"]
var wave: int:
	get: return floors[on]["wave"]
var active_wave: int:
	get: return floors[on]["active_wave"]
var where: String:
	get: return floors[on]["name"]


func _init(level_data: Dictionary, tuning: Dictionary = {}, seed_value := 1) -> void:
	data = level_data
	plan = unfold(level_data)
	hero_tune = tuning if not tuning.is_empty() else Tuning.fresh()
	dice_seed = seed_value
	restart()


## Reads a level's layout (levels/levelN.json).
static func load_data(path: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


## The short form (one street, stairs at the end, the boss's room upstairs) as the full form.
static func unfold(d: Dictionary) -> Dictionary:
	if d.has("floors"):
		return d
	return {
		"name": d.get("name", ""),
		"floors": [
			{"name": "street", "length": d["length"], "obstacles": d.get("obstacles", []), "items": d.get("items", []),
				"waves": d.get("waves", [])},
			{"name": "upstairs", "length": d.get("upstairs_length", 1920.0), "obstacles": [], "items": [], "waves": []},
		],
		"links": [{"from": 0, "x": d["stairs"], "to": 1, "to_x": 200.0, "auto": true}],
		"switches": [],
		"boss": d.get("boss", {}).merged({"floor": 1, "x": 1200.0}),
	}


## The level from its start: what a save at the level's start restores (D-15).
func restart() -> void:
	tune = hero_tune  # the hero's own table, so the feel lab still reaches him
	floors = []
	for f in plan["floors"]:
		var w = StreetWorld.new()
		for o in f.get("obstacles", []):
			var obj: Dictionary = w.add(o[0], o[1], o[2], o[3], o[4], o[5], o[6], o[7])
			if o.size() > 8:
				obj["name"] = o[8]
			if o.size() > 9:
				obj["holds"] = o[9]  # a crate or a car with something inside: it falls out when it's smashed
		for it in f.get("items", []):  # food, first aid, a weapon lying ready; a 4th number: lying up high (a roof)
			w.drop(it[0], it[1], it[2], it[3] if it.size() > 3 else 0.0)
		floors.append({"name": f["name"], "length": f["length"], "world": w, "waves": f.get("waves", []), "wave": 0,
			"active_wave": -1, "enemies": [], "waiting": []})
	on = 0
	hero = Fighter.new(tune, 200.0, 80.0, world)
	if plan.get("start_weapon", "") != "":
		hero.take_weapon(plan["start_weapon"])  # (level 3: he walks in with the wrench from Big Mama)
	fight = Fight.new()
	flipped = {}
	boss_spawned = false
	arrived_x = -1.0e9
	lives = LIVES
	won = false
	lost = false
	tick = 0
	hero_down_for = 0
	events = []
	collected = []
	projectiles = Projectiles.new()
	held_guard = 0
	bass_at = -1
	wet = true
	mopped = false
	blocks_in_row = 0
	hug = {}
	tumbling = {}
	compound = false
	visited = {0: true}
	hint_until = -1
	hints_shown = {}
	hugs_thrown = false
	used_moves = {}
	rope_hit = {}
	crossing = {}
	live_until = -1
	crane = {}
	dice.seed = dice_seed * 7919 + 1
	climbing_back = {}
	early = []
	friend = null
	tutor = null
	cat_with = 0
	var c: Array = plan["floors"][0].get("cat", [])
	cat = Vector2(c[0], c[1]) if c.size() == 2 else Vector2(-1.0e9, 0.0)
	if cat_fed:
		cat = Vector2(hero.x - 90.0, 80.0)  # fed in an earlier level: it comes along
	var spar: Dictionary = plan["floors"][0].get("friend", {})
	if not spar.is_empty():
		var t := Tuning.fresh()
		t["health"] = 999.0
		friend = Fighter.new(t, spar["x"], 80.0, floors[0]["world"])
		friend.team = 2  # his own side: blows land between him and the hero, never the thugs'
		friend.soft = true
		friend.facing = -1
		tutor = Tutor.new(friend, hero)
	_maybe_boss()


## The fighters on this floor now, the hero first (and the sparring friend, on his floor).
func everyone() -> Array:
	var out := [hero] + enemies.filter(func(e): return not e["gone"]).map(func(e): return e["f"])
	if friend != null and on == 0:
		out.append(friend)
	return out


## A small hint the first time (the team's level 3: "perfect-block his throw"): once a level.
func _show_hint(h: String) -> void:
	if tick < hint_until and hint_text != h:
		return  # one hint at a time (the team's level 5): it comes the next time its moment does
	if h != "" and not hints_shown.has(h):
		hints_shown[h] = true
		hint_text = h
		hint_until = tick + HINT_TICKS


## Hints that come at the moment, not with a wave (the team's level 4, word for word): "glow" when a Mauler's gloves
## first light up, "caught" the first time he has the hero, "too_slow" the first time a slow weapon misses a Dancer.
func _moment_hints() -> void:
	var hs: Dictionary = plan.get("hints", {})
	if hs.is_empty():
		return
	if hs.has("glow") and enemies.any(func(e): return not e["gone"] and e["kind"] == "grabber" and e["f"].attack_phase() == "startup"):
		_show_hint(hs["glow"])
	if hs.has("caught") and hero.state == "held":
		_show_hint(hs["caught"])
	if hs.has("shield"):  # a blow of his first bounces off a Doorman's shield (level 5)
		for ev in events:
			if ev.get("attacker") == hero and ev.get("result", "") == "shielded":
				_show_hint(hs["shield"])
	if hs.has("bash") and enemies.any(func(e): return not e["gone"] and e["kind"] == "doorman" and e["f"].attack_phase() == "startup"):
		_show_hint(hs["bash"])  # a Doorman's first bash glint: that's when the low kick works (Boromir, level 5)
	if hs.has("parry"):  # Madame Chrome first parries a combo used twice in a row
		for ev in events:
			if ev.get("attacker") == hero and ev.get("result", "") == "parried" \
					and enemies.any(func(e): return e["f"] == ev.get("target") and e["kind"] == "chrome"):
				_show_hint(hs["parry"])
	if hs.has("cane") and enemies.any(func(e): return not e["gone"] and e["kind"] == "chrome" and e["f"].attack_phase() == "startup"):
		_show_hint(hs["cane"])
	if hs.has("gap") and enemies.any(func(e): return not e["gone"] and not e["f"].defeated() \
			and at_gap(e["f"]) and absf(e["f"].x - hero.x) < 400.0):
		_show_hint(hs["gap"])  # a goon first stands at the balcony's railing gap, the hero near (level 4)
	if hs.has("too_slow"):
		for ev in events:
			if ev.get("attacker") == hero and ev.get("result", "") == "dodged" and hero.weapon != "" \
					and enemies.any(func(e): return e["f"] == ev.get("target") and e["kind"] == "neon_dancer"):
				_show_hint(hs["too_slow"])


## The lesson's hint on screen, while the sparring friend is teaching ("" otherwise).
func hint() -> String:
	if tick < hint_until:
		return hint_text
	if tutor == null or on != 0 or (tutor.lesson == "done" and tutor.lesson_ticks > 150):
		return ""
	return tutor.hint()


## The enemies on this floor still on their feet (or down but not out).
func standing() -> Array:
	return enemies.filter(func(e): return not e["gone"] and not e["f"].defeated()).map(func(e): return e["f"])


## How far the hero may go along this floor right now: a wave being fought locks him near it.
## Where the fighters stop at the room's sides: a boxing ring's ropes stand RING_IN inside its walls (the team's level 4:
## "the ropes are the walls"), anywhere else just inside the edge.
func ropes() -> Vector2:
	var b := bounds()
	var m: float = RING_IN if plan["floors"][on].get("ring", false) else 40.0
	return Vector2(b.x + m, b.y - m)


func bounds() -> Vector2:
	var length: float = floors[on]["length"]
	if active_wave >= 0:
		var at: float = floors[on]["waves"][active_wave]["at"]
		return Vector2(maxf(0.0, at - LOCK_MARGIN), minf(length, at + LOCK_MARGIN))
	return Vector2(0.0, length)


## One tick: the hero on this input, every enemy on its own mind, the blows settled, the waves, switches and floors.
func step(inp: Dictionary) -> void:
	if won or lost:
		return
	tick += 1
	var b := bounds()
	tune["street_left"] = b.x
	tune["street_right"] = b.y
	hero.step(inp)
	_release(hero)
	_take_turns()
	_twins()
	if friend != null and on == 0:
		friend.step(tutor.think())
	for e in enemies:
		if not e["gone"] and not e.has("shoved") and not e.has("over_rail"):  # (the Crane Operator flying out of his cab, a goon
			# going over the balcony's railing: _out_of_the_cab and _over_the_rail carry them)
			e["was"] = [e["f"].x, e["f"].y, e["f"].z]  # where he stood, should the stairs be full
			var think: Dictionary = _crossing(e) if not crossing.is_empty() and (crossing["a"] == e or crossing["b"] == e) \
					else e["brain"].think()
			if e.get("arguing", false) and e["brain"].dormant_until_within > 0.0:
				think = _argue(e)
			# never more than two swinging at once, on every level, a boss's helpers included (the balance ruling)
			var swinging: Array = enemies.filter(func(o): return not o["gone"] and o["f"].attack_phase() != "")
			var kind: String = e.get("kind", "")
			var same_busy: bool = kind in ONE_AT_A_TIME and enemies.any(func(o): return o != e and not o["gone"] \
					and o.get("kind", "") == kind and (o["f"].attack_phase() != "" or o.get("dashing", false)))
			var held: bool = hero.state == "held" and not hug.is_empty() and hug["by"] != e  # (someone else has him)
			if held:
				for k in ["hurl", "records", "throw"]:
					think.erase(k)
			if e["f"].attack_phase() == "" and (swinging.size() >= SWINGING_MAX or same_busy or held):
				for k in ["punch", "kick", "sweep", "grab", "headbutt", "throw"]:
					think.erase(k)  # (and Enforcers, and Dancers, one at a time: the team's second and third rulings; and
					# nobody hits a held hero: the team's house rule, level 4)
			if same_busy and not e.get("dashing", false):
				think.erase("run")  # (a Dancer waits for the other's skate-in before her own)
			e["dashing"] = think.get("run", false) and kind == "neon_dancer"
			if think.get("records", false):
				e["volley"] = RECORDS.duplicate()  # his records go one after another
				e["volley_at"] = tick
			if think.get("hurl", false) and plan["floors"][on].get("one_throw", false) \
					and projectiles.flying.any(func(p): return p["alive"] and p["team"] == e["f"].team and p.get("catchable", false)):
				think.erase("hurl")  # one wrench in the air at a time here (the team's level 4: the balcony, Boromir)
			if think.get("hurl", false) and e["f"].weapon != "":
				# his throw winds up first: the wrench cranked back past his ear (the pose sheet's warning), then it flies
				think.erase("hurl")
				think["throw"] = true
				e["f"].hurling = true
			think = _coach(e, think)
			think = _chrome(e, think)
			think = _static(e, think)
			think = _rook(e, think)
			think = _crane_cab(e, think)
			_volley(e)
			e["f"].step(think)
			if active_wave >= 0 and e["wave"] == active_wave and e["f"].x < b.x:
				e["f"].x = b.x  # nobody walks back onto a screen the hero has cleared (the team's second ruling)
			_release(e["f"])
	var all := everyone()
	if plan["floors"][on].get("ring", false):  # inside the ropes, everyone
		var r := ropes()
		for f in all:
			f.x = clampf(f.x, r.x, r.y)
	used_moves[hero.state] = true
	for id in world.step_hits(all):  # something smashed: whatever was inside falls out
		var o: Dictionary = world.objects[id]
		if o.has("holds"):
			world.drop(o["holds"], (o["x0"] + o["x1"]) * 0.5, clampf((o["z0"] + o["z1"]) * 0.5, 0.0, tune["street_depth"]))
	_collect()
	# (he never blocks the street; and the twins crossing slip past each other, two lanes or one: the shop's counter)
	var crossers: Array = [] if crossing.is_empty() else [crossing["a"]["f"], crossing["b"]["f"]]
	Fight.separate(all.filter(func(f): return f != friend and not crossers.has(f)))
	events = fight.step(all, world)
	events.append_array(early)
	early = []
	events.append_array(projectiles.step(all, 0.0, floors[on]["length"]))
	_moment_hints()
	if tutor != null and on == 0:
		tutor.saw(events)
	_bass_drop()
	_kitchen()
	_cat()
	_roster_tricks()
	_chrome_after()
	_static_after()
	_rook_after()
	_godfather()
	_live_strips()
	_tank_push()
	_crane()
	_shoved_out()
	_out_of_the_cab()
	_through_the_gap()
	_over_the_rail()
	_vending()
	_stairs()
	_switches()
	_waves()
	_lift()
	_links()
	_downs()


## The nearest ATTACKERS enemies on their feet may attack; the others hang back until one of them goes down.
func _take_turns() -> void:
	var up := enemies.filter(func(e): return not e["gone"] and not e["f"].defeated())
	up.sort_custom(func(a, b): return absf(a["f"].x - hero.x) < absf(b["f"].x - hero.x))
	for i in up.size():
		up[i]["brain"].allowed = i < ATTACKERS


## A thrower's volley, one record every RECORD_GAP ticks, from his hand toward the hero.
func _volley(e: Dictionary) -> void:
	if not e.has("volley") or e["volley"].is_empty() or e["f"].defeated() or e["f"].state in Fighter.HURT_STATES:
		return
	if (tick - e["volley_at"]) % RECORD_GAP != 0:
		return
	var band: Array = e["volley"].pop_front()
	var f = e["f"]
	var dir := 1.0 if hero.x >= f.x else -1.0
	if e.get("kind", "") == "chrome":  # her cards
		projectiles.throw("card", f.x + dir * 40.0, f.z, band[0], band[1], dir * CARD_SPEED, CARD_DAMAGE, f.team)
		return
	projectiles.throw("record", f.x + dir * 40.0, f.z, band[0], band[1], dir * RECORD_SPEED, RECORD_DAMAGE, f.team)


## DJ Volt's Bass Drop: while either speaker stands, a guard held BASS_HOLD ticks brings the wave: it pushes the
## hero back. Smash both speakers and it's gone (the team's boss list: "smash them first").
func _bass_drop() -> void:
	var dj: Array = enemies.filter(func(e): return e.get("kind", "") == "dj_volt" and not e["f"].defeated())
	if dj.is_empty():
		return
	held_guard = held_guard + 1 if hero.blocking() != "" else 0
	var speakers: bool = world.objects.any(func(o): return o["kind"] == "speaker" and not o["broken"])
	if held_guard >= BASS_HOLD and speakers:
		held_guard = 0
		bass_at = tick
		hero._enter("idle")  # the wave tears his guard down
		hero.take_hit({"damage": 1.0, "effect": "push", "low": 0.0, "high": 300.0, "move": "bass"}, dj[0]["f"])
		events.append({"target": hero, "result": "bass", "kind": "bass"})


## A fighter's throw at its release frame: the weapon leaves his hand and flies (catchable, landing where its flight
## ends, or a step past whoever it meets), hurting a little more than a swing.
func _release(f) -> void:
	if f.state != "throw" or f.t != int(Moves.data("throw", f.tune)["startup"]) or f.weapon == "":
		return
	if f.hurling:  # (the Wrench Mechanic's hurl, after its wind-up: his own throw, as before)
		f.hurling = false
		_hurl(f)
		return
	var what: String = f.drop_weapon()
	var dir := float(f.facing)
	var p: Dictionary = projectiles.throw(what, f.x + dir * 40.0, f.z, 140.0, 230.0, dir * Weapons.THROW_SPEED,
		Weapons.TABLE[what]["damage"] + 1.0, f.team, "stagger")
	p["catchable"] = true
	p["range"] = Weapons.THROW_RANGE.get(what, Weapons.THROW_RANGE_DEFAULT)
	events.append({"target": f, "result": "thrown", "kind": what})


## The Wrench Mechanic hurls his weapon (the team's roster): it flies at the hero; a perfect block catches it (his
## now); landing on someone or flying past, it falls to the street.
func _hurl(f) -> void:
	var what: String = f.drop_weapon()
	var dir := 1.0 if hero.x >= f.x else -1.0
	var p: Dictionary = projectiles.throw(what, f.x + dir * 40.0, f.z, 120.0, 210.0, dir * 11.0, HURL_DAMAGE, f.team)
	p["catchable"] = true


## The roster's tricks that live in the level: a thrown weapon falls a step past where it landed (not under the
## hero's feet, where he'd pick it straight up); an enemy who ducked or parried strikes straight back; the Dancer
## knocked off her feet loses her skates and is on foot after; the lookout's whistle; the
## bear hug's squeeze and throw.
func _roster_tricks() -> void:
	for ev in events:
		var p = ev.get("projectile")
		if p != null and p.get("catchable", false) and ev["result"] in ["hit", "blocked", "evaded", "landed", "parried", "dodged", "shielded"]:
			world.drop(p["kind"], clampf(p["x"] + signf(p["vx"]) * Fight.FLY * (0.0 if ev["result"] == "landed" else 1.0), 0.0, floors[on]["length"]), p["z"])
		if ev.get("result", "") in ["dodged", "parried"]:
			for e in enemies:
				if e["f"] == ev.get("target"):
					e["brain"].wait = 0  # he ducked it (or caught it on his blade): straight back at you
					if e.get("kind", "") == "wrench_mechanic" and ev["result"] == "dodged":
						e["brain"].plan = ["headbutt"]  # the Mechanic pops up out of the duck with a headbutt
						e["brain"].wait = e["brain"].kind["wait_min"]  # one hit, never leading into more (the balance ruling)
		if ev.get("result", "") == "grabbed":
			for e in enemies:
				if e["f"] == ev.get("attacker"):
					hug = {"by": e, "at": tick}
					e["brain"].wait = 9999
	for e in enemies:
		var f = e["f"]
		if e["gone"] or f.defeated():
			continue
		if e.get("kind", "") == "neon_dancer" and f.state in ["launch", "knockdown", "down"] and f.too_quick:
			f.too_quick = false  # off her skates for good: on foot, slow
			f.tune["walk_speed"] = Tuning.DEFAULTS["walk_speed"] * 0.8
			f.tune["run_speed"] = Tuning.DEFAULTS["run_speed"] * 0.8
		if e.get("kind", "") == "lookout" and active_wave >= 0:  # he runs from the hero, but not off the locked screen:
			var b := bounds()  # cornered, one hit drops him (the team's level 3)
			f.x = clampf(f.x, b.x + 30.0, b.y - 30.0)
		if e.get("kind", "") == "lookout" and absf(hero.x - f.x) < WHISTLE_RANGE and tick >= e.get("next_whistle", 0) \
				and e.get("whistles", 99) > 0:
			e["next_whistle"] = tick + WHISTLE_EVERY
			e["whistles"] = e.get("whistles", 99) - 1  # (a layout can give him only so many: level 3's has two)
			for side in ["left", "right"]:
				if standing().size() < MAX_ON_SCREEN:
					if e.has("calls_x"):  # up the ladder where it comes out (the team's level 3: Mechanics climb at you)
						_arrive({"kind": e.get("calls", "glow_punk"), "dx": e["calls_x"] - hero.x + (0.0 if side == "left" else 50.0),
							"z": 30.0 if side == "left" else 70.0, "whistled": true}, hero.x, e["wave"])
					else:
						_arrive({"kind": e.get("calls", "glow_punk"), "from": side, "z": 80.0, "whistled": true}, hero.x, e["wave"])
			events.append({"target": f, "result": "whistle", "kind": "whistle"})
	hero.held_by = hug["by"]["f"] if not hug.is_empty() and hero.state == "held" else null
	if not hug.is_empty():
		var g = hug["by"]["f"]
		if hero.state != "held" or g.defeated():
			if hero.state != "held" and not g.defeated():
				g._enter("stagger")  # wriggled free: he's off balance
			hug["by"]["brain"].wait = 40
			hug = {}
		elif tick - hug["at"] >= HUG_TICKS:
			hero._enter("idle")
			# his very first grab is the lesson, not the punishment (the team's level 4): a plain knockdown's damage
			var gentle: bool = plan.get("gentle_first_grab", false) and not hugs_thrown
			hugs_thrown = true
			hero.take_hit({"damage": GENTLE_THROW if gentle else HURL_DAMAGE, "effect": "knockdown", "low": 0.0, "high": 300.0,
				"move": "bear_hug_throw"}, g)
			events.append({"attacker": g, "target": hero, "result": "hit", "move": "bear_hug_throw", "drop": "", "counter": false, "broke": "", "worn": ""})
			hug["by"]["brain"].wait = 60
			hug = {}


## The stairs: the knocked-down tumble to the foot (skittles on the way), and no more than ON_STAIRS_MAX enemies on the
## slope (one more stepping on is put back where he stood).
func _stairs() -> void:
	for ev in events:
		var d = ev.get("target")
		if d == null or ev.get("result", "") != "hit" or tumbling.has(d) or world == null:
			continue
		var st: Dictionary = world.stairs_under(d.x, d.z, d.y)
		if st.is_empty() or d.y < 1.0 or not StreetWorld.on_slope(st, d.x):
			continue
		if ev.get("move", "") == "push_kick" or d.state in ["knockdown", "launch"]:
			_tumble(d, st)
	for f in tumbling.keys():
		var st: Dictionary = tumbling[f]
		var nx: float = f.x - TUMBLE_SPEED
		for g in everyone():  # whoever he rolls into goes down with him (not the hero: only a knockdown on him rolls him)
			if g != f and g != hero and not tumbling.has(g) and g.hittable() and g.x < f.x and g.x >= nx - 2.0 * Fight.BODY_HALF_WIDTH \
					and world.stairs_under(g.x, g.z, g.y) == st and g.y >= 1.0:
				_tumble(g, st)
		if nx > st["x0"]:
			f.x = nx
			f.y = StreetWorld.step_height(st, nx)
			continue
		f.x = st["x0"] - 30.0
		f.y = 0.0
		if f != hero:  # the hero's tumble is gentler (the team's level 3): no more hurt than a knockdown, his normal get-up
			f.health = maxf(0.0, f.health - TUMBLE_DAMAGE)
		f._enter("ko" if f.health <= 0.0 else "down")
		if f != hero:
			f.t = -TUMBLE_DOWN_EXTRA
		tumbling.erase(f)
		climbing_back[f] = st
	var on_slope := []
	for e in enemies:
		var f = e["f"]
		if e["gone"] or tumbling.has(f) or f.y < 1.0 or world == null:
			continue
		var st: Dictionary = world.stairs_under(f.x, f.z, f.y)
		if not st.is_empty() and StreetWorld.on_slope(st, f.x):
			on_slope.append(e)
	# the Bruiser never sets foot on a flight (the team's roster v3: his slam can't be dodged there): he waits at the
	# foot or on the landing; and no more than ON_STAIRS_MAX of the rest
	var held_back: Array = on_slope.filter(func(e): return KINDS.get(e["kind"], {}).get("no_stairs", false))
	on_slope = on_slope.filter(func(e): return not KINDS.get(e["kind"], {}).get("no_stairs", false))
	for e in held_back + on_slope.slice(ON_STAIRS_MAX):
		var was: Array = e.get("was", [])
		var st_was: Dictionary = {} if was.is_empty() else world.stairs_under(was[0], was[2], was[1])
		if not was.is_empty() and (st_was.is_empty() or was[1] < 1.0 or not StreetWorld.on_slope(st_was, was[0])):
			e["f"].x = was[0]  # the flight's full: he waits where he was, at the foot or on the landing
			e["f"].y = was[1]
			e["f"].z = was[2]


func _tumble(f, st: Dictionary) -> void:
	f.queue.clear()
	f._enter("tumble")
	tumbling[f] = st
	if f == hero and not hug.is_empty():
		hug = {}


## Coach Crusher (the team's roster, level 4's boss): "ball" throws the medicine ball; "tackle" sends him running at
## the hero along his line of the street until he hits him (a knockdown) or, the hero stepped aside, he slams into the
## ropes at the room's edge and stands dazed, open for K K K; dizzied twice, he gives up.
func _coach(e: Dictionary, think: Dictionary) -> Dictionary:
	if e.get("kind", "") != "coach":
		return think
	var f = e["f"]
	if f.defeated():
		return think
	if f.state == "dizzy" and not e.get("was_dizzy", false):
		e["dizzies"] = e.get("dizzies", 0) + 1
		if e["dizzies"] >= 2:  # he's had enough
			f.health = 0.0
			f._enter("ko")
			early.append({"target": f, "result": "gives_up", "kind": "gives_up"})
	e["was_dizzy"] = f.state == "dizzy"
	if e.has("rebound"):  # off the ropes: carried back by them, easing, then he stands dazed (a blow of the hero's ends it)
		var rb: Dictionary = e["rebound"]
		rb["t"] += 1
		if f.state != "stagger" or rb["t"] > REBOUND_TICKS:
			e.erase("rebound")
			if f.state == "stagger":
				f.t = -ROPES_DAZE
				early.append({"target": f, "result": "rebound", "kind": "rebound"})
			return {}
		var r0 := ropes()
		f.x = clampf(f.x + rb["dir"] * REBOUND_SPEED * (1.0 - float(rb["t"]) / REBOUND_TICKS), r0.x, r0.y)
		f.t = 0  # (held in his stagger while the ropes carry him)
		return {}
	if think.get("ball", false) and world.objects.any(func(o): return o["kind"] == "ball_rack") \
			and world.objects.filter(func(o): return o["kind"] == "ball_rack").all(func(o): return o["broken"]):
		return {}  # his rack of medicine balls smashed: nothing to throw (the team's level 4)
	if think.get("ball", false):
		var dir := 1.0 if hero.x >= f.x else -1.0
		projectiles.throw("ball", f.x + dir * 40.0, f.z, 110.0, 190.0, dir * BALL_SPEED, BALL_DAMAGE, f.team)
		return {}
	if think.get("tackle", false):
		e["tackle_next"] = true  # (pressed as his last jab recovers: he goes once he's free)
	if e.get("tackle_next", false) and f.state in Fighter.GROUND_STATES:
		e.erase("tackle_next")
		e["tackle"] = 1.0 if hero.x >= f.x else -1.0
		e["tackle_t"] = 0
		early.append({"target": f, "result": "tackle", "kind": "tackle"})
	elif f.state in Fighter.HURT_STATES:
		e.erase("tackle_next")
	if not e.has("tackle"):
		return think
	f.charging = e.has("tackle")
	if f.state in Fighter.HURT_STATES:
		e.erase("tackle")
		f.charging = false
		return think
	var dir: float = e["tackle"]
	e["tackle_t"] += 1
	if e["tackle_t"] <= TACKLE_WINDUP:
		f.facing = int(dir)
		if not f._blocked(f.x - dir * 2.4, f.z):
			f.x = clampf(f.x - dir * 2.4, ropes().x, ropes().y)  # backing off for the run-up, facing him
		return {}
	if absf(hero.x - f.x) < TACKLE_REACH and absf(hero.z - f.z) <= f.tune["hit_depth"] and hero.hittable() and signf(hero.x - f.x) == dir:
		hero.take_hit({"damage": TACKLE_DAMAGE, "effect": "knockdown", "low": 0.0, "high": 300.0, "move": "tackle"}, f)
		e.erase("tackle")
		f.charging = false
		e["brain"].wait = 60
		early.append({"attacker": f, "target": hero, "result": "hit", "move": "tackle", "drop": "", "counter": false, "broke": "", "worn": ""})
		return {}
	var b := ropes()
	if (dir > 0.0 and f.x >= b.y) or (dir < 0.0 and f.x <= b.x):
		e.erase("tackle")
		f.charging = false
		f._enter("stagger")  # into the ropes: they give, and throw him back (then he's dazed, open)
		e["rebound"] = {"dir": -dir, "t": 0}
		rope_hit = {"side": dir, "z": f.z, "at": tick}
		early.append({"target": f, "result": "ropes", "kind": "ropes"})
		return {}
	return {"run": true, "mx": dir}


## Madame Chrome (the team's roster, level 5's boss): her cards, three in a row, then she's open a moment (no guard,
## no parry), then the low cane sweep and the cane jab; any combo the hero uses twice in a row she parries at its
## finisher (mix it up); three kicks into her cane's wind-up snap it, and then she's done.
func _chrome(e: Dictionary, think: Dictionary) -> Dictionary:
	if e.get("kind", "") != "chrome" and not (e.get("kind", "") == "godfather" and e.get("round", 1) == 3):
		return think
	var f = e["f"]
	if f.defeated():
		return think
	var open: bool = tick < e.get("open_until", 0)
	# the same combo again: its finisher she parries (a different finish after the same opening isn't a repeat: the
	# finisher reads the whole combo; his chain reads empty on it)
	var now: String = _combo_of(hero.state) if hero.chain == "" else ""
	var again: bool = e.get("last_combo", "") != "" and now == e["last_combo"]
	if e.get("kind", "") == "godfather":
		f.parries = [hero.state] if again else []  # (his third round: he blocks the last combo used on him)
		return think
	f.parries = [hero.state] if again and not open else []
	if open:
		e["brain"].block_left = 0
	if think.get("cards", false):
		e["volley"] = CARDS.duplicate()
		e["volley_at"] = tick
		e["open_until"] = tick + RECORD_GAP * CARDS.size() + CHROME_OPEN
		e["then"] = e["open_until"]  # then the sweep and the jab
		e["brain"].plan.clear()
		e["brain"].wait = 9999
		return {}
	if e.has("then") and tick >= e["then"]:
		e.erase("then")
		e["brain"].plan = ["sweep", "punch"]
		e["brain"].wait = 0
	return think


## The presses a combo finisher ends (power_punch: "PPP"; the armed smash and rising swing as the punches they
## stand for), or "" for a move that ends none.
static func _combo_of(move: String) -> String:
	var armed := {"smash": "PPP", "rising_swing": "PKP"}
	if armed.has(move):
		return armed[move]
	for seq in Moves.COMBOS:
		if Moves.COMBOS[seq] == move and seq.length() == Moves.FINISHER_LENGTH:
			return seq
	return ""


## Madame Chrome after the blows: the combo the hero just finished on her (for her parry), and the kicks into her
## cane's wind-up (three snap it).
func _chrome_after() -> void:
	for e in enemies:
		if not e.get("kind", "") in ["chrome", "godfather"] or e["f"].defeated():
			continue
		var f = e["f"]
		for ev in events:
			if ev.get("attacker") != hero or ev.get("target") != f:
				continue
			if Moves.is_finisher(ev.get("move", "")):
				e["last_combo"] = _combo_of(ev["move"])
			if e["kind"] != "chrome":
				continue
			if ev.get("counter", false) and (ev.get("move", "") in KICKS or ev.get("from_kick", false)) and f.weapon == "cane":
				e["cane_kicks"] = e.get("cane_kicks", 0) + 1
				if e["cane_kicks"] >= CANE_KICKS:
					f.weapon_snaps = true
					Fight._disarm(f, world, hero.x)  # it bends and snaps
					f.health = 0.0
					f._enter("ko")
					events.append({"target": f, "result": "cane_snaps", "kind": "cane_snaps"})


## Mr. Static (the team's roster, level 7's boss): "slam" makes the floor live a second; while it is, the hero on his
## feet on the floor is shocked (once a slam): jump it.
func _static(e: Dictionary, think: Dictionary) -> Dictionary:
	if e.get("kind", "") != "static" or e["f"].defeated():
		return think
	var f = e["f"]
	if think.get("slam", false) and not e.has("slam_at") and f.weapon == "baton":  # (no baton, no slam)
		e["slam_at"] = tick + SLAM_WINDUP
		early.append({"target": f, "result": "slam", "kind": "slam"})
	if e.has("slam_at"):
		if f.state in Fighter.HURT_STATES:
			e.erase("slam_at")  # hit out of it
			f.slam_in = -1
			return think
		f.slam_in = e["slam_at"] - tick
		if f.slam_in <= 0:
			e.erase("slam_at")
			f.slam_in = -1
			live_until = tick + LIVE_TICKS
			e["shocked_this"] = false
			early.append({"target": f, "result": "live", "kind": "live"})
		return {}  # (standing, baton raised)
	return think


## Mr. Static after the blows: a perfect block on his baton shocks the hero (unless he wears rubber gloves); P P K'd by
## the water tank he shorts out, dizzy at once; and the live floor bites whoever's on it.
func _static_after() -> void:
	for e in enemies:
		if e.get("kind", "") != "static" or e["f"].defeated():
			continue
		var f = e["f"]
		for ev in events:
			if ev.get("attacker") == f and ev.get("target") == hero and ev["result"] == "perfect" and f.weapon == "baton" and not hero.rubber:
				hero.health = maxf(0.0, hero.health - SHOCK_DAMAGE)
				hero._enter("hurt")
				events.append({"target": hero, "result": "shocked", "kind": "shock"})
			if ev.get("attacker") == hero and ev.get("target") == f and ev["result"] == "hit" and ev.get("move", "") == "push_kick":
				for o in world.objects:
					if o["kind"] == "tank" and absf((o["x0"] + o["x1"]) * 0.5 - f.x) < TANK_REACH:
						f.health = maxf(0.0, f.health - TANK_DAMAGE)
						f.dizzy_left = int(f.tune["dizzy_ticks"])
						f._enter("ko" if f.health <= 0.0 else "dizzy")
						events.append({"target": f, "result": "shorts_out", "kind": "shorts_out"})
						break
		var dry: bool = plan["floors"][on].get("dry", []).any(func(r): return hero.x >= r[0] and hero.x <= r[1])
		if tick < live_until and not e.get("shocked_this", true) and hero.y < 1.0 and hero.on_ground() and hero.hittable() and not dry:
			e["shocked_this"] = true
			hero.take_hit({"damage": SHOCK_DAMAGE, "effect": "push", "low": 0.0, "high": 300.0, "move": "live_floor"}, f)
			events.append({"target": hero, "result": "shocked", "kind": "live_floor"})


## The Godfather of Glow (the team's roster, level 10's boss), three rounds, each its own health: 1, armour (only the
## Lovelight cuts his coat; thrown, he catches it, and a perfect block on his next swing knocks it loose); 2, speed
## (the coat's off: only a blow into his wind-up lands); 3, rage (he blocks the last combo used on him; two combos make
## him dizzy, and the finisher landed while he's dazed saves your love). Lose a life and only the round restarts.
func _godfather() -> void:
	for e in enemies:
		if e.get("kind", "") != "godfather":
			continue
		var f = e["f"]
		if not e.has("round"):
			e["round"] = 1
			e["lives_seen"] = lives
		if lives < e["lives_seen"]:  # the hero lost a life: only this round starts again
			e["lives_seen"] = lives
			f.health = f.max_health
			events.append({"target": f, "result": "round_again", "kind": "round", "round": e["round"]})
		if e["round"] == 3:
			for ev in events:
				if ev.get("attacker") == hero and ev.get("target") == f and ev["result"] == "hit" and Moves.is_finisher(ev.get("move", "")) \
						and e.get("was_dizzy", false):
					f.health = 0.0  # the dizzy finisher: it's over
					f._enter("ko")
					e["saved"] = true
					events.append({"target": f, "result": "saved", "kind": "ending"})
			e["was_dizzy"] = f.state == "dizzy"
		if f.health > 0.0 or e["round"] >= 3:
			continue
		# a round won: up he gets for the next
		e["round"] += 1
		f.health = f.max_health
		f._enter("stagger")
		f.armour = false
		f.only_counters = e["round"] == 2
		f.min_health = 1.0 if e["round"] == 3 else 0.0  # worn down in the rage round he won't fall
		f.reads_combos = e["round"] == 3
		f.stays_up = e["round"] == 3
		if e["round"] == 2:
			f.tune["walk_speed"] = f.tune["walk_speed"] * 1.5  # the coat's off: fast
			f.tune["run_speed"] = f.tune["run_speed"] * 1.5
		else:
			f.tune["walk_speed"] = f.tune["walk_speed"] / 1.5
			f.tune["run_speed"] = f.tune["run_speed"] / 1.5
		e["brain"].kind = Brain.TYPES["GODFATHER_%d" % e["round"]]
		events.append({"target": f, "result": "round", "kind": "round", "round": e["round"]})


## Velvet Rook (the team's roster, level 8's boss): "Checkmate" calls his Enforcers through the doors, one for each
## door switch still standing (smash them and fewer come, none once all are smashed), not more often than
## CHECKMATE_EVERY.
func _rook(e: Dictionary, think: Dictionary) -> Dictionary:
	if e.get("kind", "") != "rook" or e["f"].defeated():
		return think
	if think.get("checkmate", false):
		if tick >= e.get("next_checkmate", 0):
			e["next_checkmate"] = tick + CHECKMATE_EVERY
			var doors: Array = world.objects.filter(func(o): return o["kind"] == "door_switch" and not o["broken"])
			for o in doors.slice(0, 2):
				if standing().size() < MAX_ON_SCREEN:
					_arrive({"kind": "enforcer", "from": "door", "dx": (o["x0"] + o["x1"]) * 0.5 - hero.x}, hero.x, e["wave"])
			early.append({"target": e["f"], "result": "checkmate", "kind": "checkmate", "called": mini(doors.size(), 2)})
		return {}
	return think


## Velvet Rook after the blows: a perfect block on his last cut (the third, the overhead) counts; the third breaks his
## sword, and he's only fists from then, slow and old.
func _rook_after() -> void:
	for e in enemies:
		if e.get("kind", "") != "rook" or e["f"].defeated():
			continue
		var f = e["f"]
		for ev in events:
			if ev.get("attacker") == f and ev.get("target") == hero and ev["result"] == "perfect" and ev.get("move", "") == "smash" \
					and f.weapon == "sword":
				e["sword_blocks"] = e.get("sword_blocks", 0) + 1
				if e["sword_blocks"] >= ROOK_BREAKS:
					f.weapon_snaps = true
					Fight._disarm(f, world, hero.x)
					f.tune["walk_speed"] = f.tune["walk_speed"] * 0.7
					e["brain"].kind = Brain.ROOK_OLD
					events.append({"target": f, "result": "sword_breaks", "kind": "sword_breaks"})


## The docks' crane (the team's roster, level 6's boss): while it runs and the hero is on one of its floors, every
## CRANE_EVERY a container swings along the floor, low (jump it, or be on another floor), then two crates drop near the
## hero (their shadows show first). A crane switch, once thrown, stays thrown: the container stops swinging along its
## floor for good (the team's roster v7); with every switch thrown the cab opens.
func _crane() -> void:
	var c: Dictionary = plan.get("crane", {})
	if c.is_empty():
		return
	if crane.is_empty():
		crane = {"next": tick + CRANE_EVERY, "container": {}, "crates": []}
	var on_its_floor: bool = c.get("floors", []).any(func(n): return int(n) == on)  # (numbers from a layout read as decimals)
	var running: bool = on_its_floor and not crane_stopped_here() and not plan_boss_down()
	var b := bounds()
	var box: Dictionary = crane["container"]
	if box.is_empty() and running and tick >= crane["next"] - CRANE_WARN and not crane.get("warned", false):
		crane["warned"] = true
		crane["from"] = -1.0 if hero.x > (b.x + b.y) * 0.5 else 1.0  # from the far side of him
		events.append({"target": hero, "result": "crane_warn", "kind": "crane"})
	if box.is_empty() and running and tick >= crane["next"]:
		var dir: float = -crane.get("from", 1.0)
		crane["container"] = {"x": b.x - CONTAINER_WIDTH if dir > 0.0 else b.y + CONTAINER_WIDTH, "dir": dir, "hit": false}
		box = crane["container"]
		crane["warned"] = false
	if not box.is_empty():
		var was_ahead: bool = (hero.x - box["x"]) * box["dir"] > 0.0
		box["x"] += box["dir"] * CONTAINER_SPEED
		if was_ahead and (hero.x - box["x"]) * box["dir"] <= 0.0 and not box["hit"]:
			events.append({"target": hero, "result": "container_under", "kind": "container"})  # it went under him
		var half := CONTAINER_WIDTH * 0.5 + Fight.BODY_HALF_WIDTH
		if not box["hit"] and absf(box["x"] - hero.x) < half and hero.y < CONTAINER_TOP and hero.hittable():
			box["hit"] = true
			hero.take_hit({"damage": CONTAINER_DAMAGE, "effect": "knockdown", "low": 0.0, "high": 300.0, "move": "container"}, {"x": box["x"] - box["dir"] * 10.0, "y": 0.0})
			events.append({"target": hero, "result": "hit", "kind": "container", "move": "container"})
		if (box["dir"] > 0.0 and box["x"] > b.y + CONTAINER_WIDTH) or (box["dir"] < 0.0 and box["x"] < b.x - CONTAINER_WIDTH):
			crane["container"] = {}
			crane["next"] = tick + CRANE_EVERY
			for k in 2:  # then the crates, near him
				crane["crates"].append({"x": clampf(hero.x + (k * 2 - 1) * dice.randf_range(20.0, 120.0), b.x + 40.0, b.y - 40.0),
					"z": hero.z, "at": tick + CRATE_WARN + k * 25})
	for cr in crane["crates"].duplicate():
		if tick >= cr["at"]:
			crane["crates"].erase(cr)
			if absf(cr["x"] - hero.x) < 55.0 and absf(cr["z"] - hero.z) < 40.0 and hero.y < 60.0 and hero.hittable():
				hero.take_hit({"damage": CRATE_DAMAGE, "effect": "knockdown", "low": 0.0, "high": 300.0, "move": "crate"}, {"x": cr["x"], "y": 0.0})
				events.append({"target": hero, "result": "hit", "kind": "crate", "move": "crate"})
			else:
				events.append({"target": hero, "result": "crate_smash", "kind": "crate"})
	hero.no_swing = plan["floors"][on].get("cab", false)


## Whether this floor's crane switch is thrown (then the container never swings along it again).
func crane_stopped_here() -> bool:
	var switches: Array = plan.get("switches", [])
	return range(switches.size()).any(func(i): return switches[i].get("crane", false) and int(switches[i]["floor"]) == on \
			and flipped.has(i))


func plan_boss_down() -> bool:
	return boss_spawned and enemies.filter(func(e): return e["boss"]).all(func(e): return e["f"].defeated())


## A glass lift (the team's levels page, level 5: "a fight in a moving glass lift", about six seconds): a floor
## ({"lift": {"to", "to_x", "ticks"}}) that rides while its fight goes on; once it has ridden its time and its fight
## is beaten, the doors open on the floor it was going to.
func _lift() -> void:
	var lift: Dictionary = plan["floors"][on].get("lift", {})
	if lift.is_empty():
		return
	var fl: Dictionary = floors[on]
	fl["ride"] = fl.get("ride", 0) + 1
	if fl["ride"] >= int(lift.get("ticks", 360)) and active_wave < 0 and cleared(on) and hero.on_ground():
		events.append({"target": hero, "result": "lift_arrives", "kind": "lift"})
		_go_to(int(lift["to"]), float(lift["to_x"]))


## How far the lift has ridden, 0 to 1 (0 when he's not in one): for the view's passing walls.
func lift_ride() -> float:
	var lift: Dictionary = plan["floors"][on].get("lift", {})
	if lift.is_empty():
		return 0.0
	return clampf(float(floors[on].get("ride", 0)) / float(lift.get("ticks", 360)), 0.0, 1.0)


## The Crane Operator push-kicked: shoved out of his cab onto a container, and that's it.
func _shoved_out() -> void:
	for ev in events:
		var d = ev.get("target")
		if ev.get("attacker") == hero and ev.get("result", "") == "hit" and ev.get("move", "") == "push_kick":
			for e in enemies:
				if e["f"] == d and e.get("kind", "") == "crane_operator" and not d.defeated() and not e.has("shoved"):
					d._enter("launch")  # out through the cab's open side, and down onto the container below
					e["shoved"] = {"dir": 1.0 if d.x >= hero.x else -1.0, "t": 0, "x0": d.x}
					events.append({"target": d, "result": "shoved_out", "kind": "shoved_out"})


## Level 5's vending machine (Pippin's joke, the team's page): the hero's first kick gives a snack, the second an
## apology note, the third tips it over, and it flattens whoever stands in front of it, a Doorman too (a knockdown
## from above, shield or no shield).
func _vending() -> void:
	for o in world.objects:
		if o["kind"] != "vending" or o["broken"] or o.get("hits", 0) == o.get("hits_read", 0):
			continue
		o["hits_read"] = o["hits"]
		if o.get("hit_team", -1) != hero.team or not (o.get("hit_move", "") in KICKS or o.get("hit_kick", false)):
			continue
		o["kicks"] = o.get("kicks", 0) + 1
		var x: float = (o["x0"] + o["x1"]) * 0.5
		var front: float = clampf(o["z1"] + 30.0, 0.0, tune["street_depth"])
		match o["kicks"]:
			1:
				world.drop("snack", x, front)
			2:
				world.drop("note", x, front)
			_:
				o["broken"] = true  # over it goes, onto whoever's in front
				events.append({"target": null, "result": "vending_tipped", "kind": "vending"})
				for f in everyone():
					if f.x > o["x0"] - VENDING_REACH and f.x < o["x1"] + VENDING_REACH and f.z > o["z1"] and f.z < o["z1"] + VENDING_FALL \
							and f.hittable():
						f.take_hit({"damage": VENDING_DAMAGE, "effect": "knockdown", "low": 0.0, "high": 300.0, "move": "vending",
							"from_above": true}, {"x": x, "y": 0.0})
						events.append({"target": f, "result": "hit", "kind": "vending", "move": "vending"})


## The Crane Operator flying out of his cab (push-kicked): an arc out through its open side, over the edge, gone.
func _out_of_the_cab() -> void:
	for e in enemies:
		if not e.has("shoved") or e["gone"]:
			continue
		var s: Dictionary = e["shoved"]
		var d = e["f"]
		s["t"] += 1
		var p: float = float(s["t"]) / SHOVE_TICKS
		d.x = s["x0"] + s["dir"] * SHOVE_DISTANCE * p
		d.y = SHOVE_HEIGHT * sin(PI * p) - SHOVE_DROP * p * p * p
		if s["t"] >= SHOVE_TICKS:
			d.health = 0.0
			d._enter("ko")
			e["gone"] = true  # out of the cab, down on the container below: out of the fight
			events.append({"target": d, "result": "out_of_cab", "kind": "out_of_cab"})


## The balcony's railing gap on this floor, [x0, x1] ([] if none).
func railing_gap() -> Array:
	return plan["floors"][on].get("railing_gap", [])


## Whether a fighter stands at the railing gap: inside it along the balcony, at its front edge.
func at_gap(f) -> bool:
	var g: Array = railing_gap()
	return not g.is_empty() and f.x >= float(g[0]) and f.x <= float(g[1]) and f.z >= tune["street_depth"] - GAP_REACH \
			and f.y < 1.0


## A goon at the gap push-kicked or knocked down by the hero: over the railing he goes.
func _through_the_gap() -> void:
	if railing_gap().is_empty():
		return
	for ev in events:
		var d = ev.get("target")
		if ev.get("attacker") != hero or ev.get("result", "") != "hit" or d == null:
			continue
		if not (ev.get("move", "") == "push_kick" or d.state in ["knockdown", "launch", "ko"]):  # (knocked out there: over too)
			continue
		for e in enemies:
			if e["f"] == d and not e["gone"] and not e["boss"] and not e.has("over_rail") and at_gap(d) and not (d.state == "ko" and e["dropped"]):
				e["over_rail"] = {"t": 0, "z0": d.z, "x0": d.x}
				e["dropped"] = true  # (nothing left behind: it all goes over with him)
				if ev.get("drop", "") != "":  # a weapon knocked loose by the same blow goes over too
					for i in range(world.items.size() - 1, -1, -1):
						if world.items[i]["kind"] == ev["drop"]:
							world.items.remove_at(i)
							break
				d._enter("launch")
				events.append({"target": d, "result": "over_the_rail", "kind": "over_the_rail"})


## Over the bar and down to the ring hall below, out of sight: out of the fight, counted as beaten.
func _over_the_rail() -> void:
	for e in enemies:
		if not e.has("over_rail") or e["gone"]:
			continue
		var s: Dictionary = e["over_rail"]
		var d = e["f"]
		s["t"] += 1
		var p: float = float(s["t"]) / GAP_TICKS
		d.x = s["x0"]
		d.z = s["z0"] + GAP_FORWARD * minf(p * 2.0, 1.0)
		d.y = 40.0 * sin(PI * minf(p * 2.0, 1.0)) - GAP_DROP * maxf(p - 0.4, 0.0) * maxf(p - 0.4, 0.0) / 0.36
		if s["t"] >= GAP_TICKS:
			d.health = 0.0
			d._enter("ko")
			e["gone"] = true
			events.append({"target": d, "result": "down_below", "kind": "over_the_rail"})


## When the bot should jump the crane's container: it's coming at him and about to reach him.
func crane_jump_cue() -> bool:
	var box: Dictionary = crane.get("container", {})
	if box.is_empty():
		return false
	var ahead: float = (hero.x - box["x"]) * box["dir"]  # how far it still has to come
	# (a jump needs about 15 frames to get above it: 4 crouching, 11 rising; at 16 px a frame that's 240 px of warning)
	return ahead > 0.0 and ahead < CONTAINER_WIDTH * 0.5 + Fight.BODY_HALF_WIDTH + 240.0


## The Crane Operator in his cab: "horn" blasts the hero back (a push, if he's close); P P K's push kick shoves him
## out of the cab, and that's it.
func _crane_cab(e: Dictionary, think: Dictionary) -> Dictionary:
	if e.get("kind", "") != "crane_operator" or e["f"].defeated():
		return think
	var f = e["f"]
	if think.get("horn", false):
		early.append({"target": f, "result": "horn", "kind": "horn"})
		if absf(hero.x - f.x) < HORN_REACH and hero.hittable():
			hero.take_hit({"damage": 1.0, "effect": "push", "low": 0.0, "high": 300.0, "move": "horn"}, f)
		return {}
	return think


## Live floor strips (the team's level 7: "sparking two seconds on, one off"): a floor's "live": [[x0, x1, on, off]]
## shocks whoever stands on it while it's on, once a beat, goons too, a Neon Dancer on her skates included (the balance
## ruling, 11-04: a Dancer on a live strip gets zapped).
func _live_strips() -> void:
	for strip in plan["floors"][on].get("live", []):
		var beat: int = int(strip[2]) + int(strip[3])
		var live: bool = tick % beat < int(strip[2])
		if tick % beat == 0:
			shocked_beat = {}
		if not live:
			continue
		for f in everyone():
			var who: Array = enemies.filter(func(e): return e["f"] == f)
			var kind: String = "hero" if f == hero else (who[0]["kind"] if not who.is_empty() else "")
			var dry: bool = strip.size() > 5 and (f.z < strip[4] or f.z > strip[5])  # (a dry path along it: the team's second ruling)
			if shocked_beat.has(f) or f.y >= 1.0 or not f.hittable() or f.x < strip[0] or f.x > strip[1] or dry:  # (a Dancer too)
				continue
			shocked_beat[f] = true
			f.take_hit({"damage": SHOCK_DAMAGE, "effect": "push", "low": 0.0, "high": 300.0, "move": "live_floor"}, {"x": f.x - f.facing * 10.0, "y": 0.0})
			events.append({"target": f, "result": "shocked", "kind": "live_floor"})


## Open water tanks below a catwalk (the team's level 7: "push a goon in and he's out"): on a floor with
## "tanks_knock_out", a push kick landing on a goon by a tank sends him in, out of the fight.
func _tank_push() -> void:
	if not plan["floors"][on].get("tanks_knock_out", false):
		return
	for ev in events:
		var d = ev.get("target")
		if ev.get("attacker") != hero or ev.get("result", "") != "hit" or ev.get("move", "") != "push_kick" or d == null:
			continue
		for o in world.objects:
			if o["kind"] == "tank" and absf((o["x0"] + o["x1"]) * 0.5 - d.x) < TANK_REACH and not enemies.any(func(e): return e["f"] == d and e["boss"]):
				d.health = 0.0
				d._enter("ko")
				events.append({"target": d, "result": "into_the_tank", "kind": "tank"})
				break


## Twin Loans (the team's roster, level 3's boss): while one brother attacks, the other holds his guard up and waits his
## turn; halfway through a combo they swap places ("Interest"), so an answer meant for the one swinging lands on the
## one guarding; at half their health together, both rush the hero at once ("Compound"). Knocked down a flight, a
## brother climbs back slowly.
func _twins() -> void:
	var twins: Array = enemies.filter(func(e): return not e["gone"] and KINDS.get(e["kind"], {}).get("twin", false))
	if twins.is_empty():
		return
	for e in twins:  # slow back up a flight he was knocked down; a pair: the one waiting his turn stays close, guard up
		var f = e["f"]
		e["brain"].close_guard = true
		if not e.has("walk"):
			e["walk"] = f.tune["walk_speed"]
		if climbing_back.has(f):
			var st: Dictionary = climbing_back[f]
			if f.y >= st["top"] - 1.0 or (f.flight().is_empty() and hero.flight().is_empty() and f.state in Fighter.GROUND_STATES):
				climbing_back.erase(f)  # back up top (or the fight's come down to the floor)
		f.tune["walk_speed"] = e["walk"] * (TWIN_CLIMB if climbing_back.has(f) and not f.flight().is_empty() else 1.0) \
				* (2.0 if not twins_opened and not compound and not climbing_back.has(f) and not f.flight().is_empty() else 1.0)  # (down the stairs in a hurry to open with his brother)
	var up: Array = twins.filter(func(e): return not e["f"].defeated())
	if up.size() < 2:
		return
	var hp: float = up.reduce(func(s, e): return s + e["f"].health, 0.0)
	var most: float = up.reduce(func(s, e): return s + e["f"].max_health, 0.0)
	# the opening (the team's third ruling): once both are up on one flight, near each other and he's coming, they open
	# with their swap, the brother nearer him starting a combo from where he stands; nothing rocks him till they've
	# swapped. After that a quick player can cut a combo short as before.
	if not twins_opened and not compound and up[0]["f"].flight() == up[1]["f"].flight() \
			and absf(up[0]["f"].x - up[1]["f"].x) < 500.0 and up.all(func(e): return e["brain"].dormant_until_within <= 0.0) \
			and up.any(func(e): return absf(e["f"].x - hero.x) < TWIN_OPEN_RANGE and e["f"].state in Fighter.GROUND_STATES + ["block"]):
		twins_opened = true
		var att: Dictionary = up[0] if absf(up[0]["f"].x - hero.x) <= absf(up[1]["f"].x - hero.x) else up[1]
		var other: Dictionary = up[1] if att == up[0] else up[0]
		att["brain"].plan = (Brain.TYPES["TWIN"]["combos"][0] as Array).duplicate()
		att["brain"].wait = 0
		att["brain"].block_left = 0
		att["f"].facing = 1 if hero.x >= att["f"].x else -1
		att["f"].unflinching = true
		other["swapped"] = false
		early.append({"target": att["f"], "result": "opening", "kind": "opening"})
	for e in up:
		if e["f"].unflinching and crossing.is_empty() and (e.get("swapped", false) or (e["brain"].plan.is_empty() and e["f"].attack_phase() == "")):
			e["f"].unflinching = false
	if not compound and hp <= most * 0.5:  # (roster v3: at half their health)
		compound = true
		early.append({"target": up[0]["f"], "result": "compound", "kind": "compound"})
	if compound:
		for e in up:
			e["brain"].allowed = true  # both at once
			e["f"].unflinching = false
		return
	if not crossing.is_empty():
		return  # (mid-crossing: _crossing has them)
	for i in 2:
		var me: Dictionary = up[i]
		var other: Dictionary = up[1 - i]
		var busy: bool = other["f"].attack_phase() != "" or not other["brain"].plan.is_empty()
		if busy:
			me["brain"].allowed = false  # his brother's turn
			if me["f"].state in Fighter.GROUND_STATES or me["f"].state == "block":
				me["brain"].block_left = maxi(me["brain"].block_left, 2)  # and his guard up meanwhile
		# Interest: the second press of his combo, and they've swapped places
		var b = other["brain"]
		if b.plan.is_empty() and other["f"].attack_phase() == "":
			other["swapped"] = false  # his combo's over: the next one may swap again
		if b.plan.size() == 1 and not other.get("swapped", false) \
				and (me["f"].state in Fighter.GROUND_STATES + ["block"] or other["f"].unflinching) and me["f"].flight() == other["f"].flight() \
				and absf(me["f"].x - other["f"].x) < 500.0:  # (both on the shop floor, or both on the same stairs)
			other["swapped"] = true  # once a combo
			# they cross: each walks to where the other stood, passing on different lanes, in their own steps (the
			# testers on cd9f7fe: "show them actually crossing", the team's "a second or two"); _crossing walks them
			if other["f"].unflinching:
				me["f"].unflinching = true  # (the opening's crossing: nothing rocks either of them till it's done)
			crossing = {"a": other, "b": me, "t": 0,
				"a_from": Vector2(other["f"].x, other["f"].z), "b_from": Vector2(me["f"].x, me["f"].z),
				"a_to": Vector2(me["f"].x, me["f"].z), "b_to": Vector2(other["f"].x, other["f"].z)}
			early.append({"target": other["f"], "result": "swap", "kind": "swap"})
	if not twins_opened:
		for e in up:
			e["brain"].allowed = false  # till they've opened together: they hang back, guards up, and nothing rocks them
			e["f"].unflinching = true


## Twin Loans crossing ("Interest"): each brother walks to where the other stood, the attacker passing in front and his
## brother behind, in their own steps; arrived, they turn to the hero and the attacker's combo goes on from there.
## A blow that rocks either one cuts it short where they stand (nothing rocks the opener: the team's opening).
func _crossing(e: Dictionary) -> Dictionary:
	var c: Dictionary = crossing
	var mine: String = "a" if c["a"] == e else "b"
	var f = e["f"]
	if mine == "a":
		c["t"] += 1
	if c["a"]["f"].state in Fighter.HURT_STATES or c["b"]["f"].state in Fighter.HURT_STATES or c["a"]["f"].defeated() \
			or c["b"]["f"].defeated() or c["t"] > SWAP_TICKS_MAX:
		_crossed(false)  # (rocked, down, or blocked too long: cut short where they stand)
		return {}
	var from: Vector2 = c[mine + "_from"]
	var to: Vector2 = c[mine + "_to"]
	var total: float = maxf(1.0, absf(to.x - from.x))
	var p: float = clampf(1.0 - absf(to.x - f.x) / total, 0.0, 1.0)
	var lane: float = (SWAP_LANE if mine == "a" else -SWAP_LANE) * sin(PI * p)  # (out to his lane mid-way, back at the end)
	var want_z: float = clampf(lerpf(from.y, to.y, p) + lane, 0.0, tune["street_depth"])
	var inp := {}
	if absf(to.x - f.x) > 6.0:
		inp["mx"] = signf(to.x - f.x)
	if absf(want_z - f.z) > 3.0:
		inp["mz"] = clampf((want_z - f.z) / 12.0, -1.0, 1.0)
	if mine == "b" and inp.is_empty() and absf(c["a_to"].x - c["a"]["f"].x) <= 6.0:
		_crossed(true)  # both there
	return inp


## The crossing over: where they stand, facing the hero; the opener rockable again. (false: cut short)
func _crossed(done: bool) -> void:
	var c: Dictionary = crossing
	crossing = {}
	for k in ["a", "b"]:
		var f = c[k]["f"]
		if not f.defeated():
			f.facing = 1 if hero.x >= f.x else -1
	c["a"]["f"].unflinching = false  # (the opening's done)
	c["b"]["f"].unflinching = false
	early.append({"target": c["a"]["f"], "result": "swapped" if done else "swap_cut", "kind": "swap"})


## Two of a wave squaring off (the team's level 3: two Snicks arguing over who gets the hero first): each faces the
## other and slashes now and then (they're on one side: the blows don't land), until the hero comes close.
func _argue(e: Dictionary) -> Dictionary:
	var f = e["f"]
	for o in enemies:
		if o != e and o.get("arguing", false) and o["wave"] == e["wave"] and not o["f"].defeated():
			f.facing = 1 if o["f"].x >= f.x else -1
			if f.state in Fighter.GROUND_STATES and (tick + int(f.x)) % 55 == 0:
				return {"punch": true}
			break
	return {}


## The stray cat (level 1, screen 7): stand by it a moment and it's fed; then it trots at his heels.
func _cat() -> void:
	if cat.x < -1.0e8:
		return
	if not cat_fed:
		if absf(hero.x - cat.x) < 70.0 and absf(hero.z - cat.y) < 50.0 and hero.state in ["idle", "stand"]:
			cat_with += 1
			if cat_with >= CAT_FEED_TICKS:
				cat_fed = true
				collected.append("cat")
				events.append({"target": hero, "result": "cat", "kind": "cat"})
		else:
			cat_with = 0
		return
	var want := Vector2(hero.x - hero.facing * 90.0, clampf(hero.z + 20.0, 0.0, tune["street_depth"]))
	cat = cat.lerp(want, 0.06)


## Big Mama Noodle's kitchen: the soup, the wet patch, the mop, the tap (the floor's "kitchen": {wet: [x0, x1], tap: x}).
func _kitchen() -> void:
	var room: Dictionary = plan["floors"][on].get("kitchen", {})
	if room.is_empty():
		return
	var mama: Array = enemies.filter(func(e): return e.get("kind", "") == "big_mama" and not e["f"].defeated())
	if mama.is_empty():
		return
	var m = mama[0]["f"]
	# her soup: the hero's third block in a row (a blow of his landing on her breaks the run)
	for e in events:
		if e.get("attacker") == m and e.get("target") == hero:
			blocks_in_row = blocks_in_row + 1 if e["result"] in ["blocked", "perfect"] else 0
		elif e.get("attacker") == hero and e.get("result") == "hit":
			blocks_in_row = 0
	if blocks_in_row >= SOUP_AFTER_BLOCKS:
		blocks_in_row = 0
		var dir := 1.0 if hero.x >= m.x else -1.0
		projectiles.throw("soup", m.x + dir * 40.0, m.z, 110.0, 200.0, dir * 10.0, SOUP_DAMAGE, m.team)
		events.append({"target": hero, "result": "soup", "kind": "soup"})
	# the wet patch: running onto it she slips and is dazed at once
	var patch: Array = room.get("wet", [])
	if wet and patch.size() == 2 and m.state == "run" and m.x >= patch[0] and m.x <= patch[1]:
		m.dizzy_left = SLIP_DAZE
		m._enter("dizzy")
		events.append({"target": m, "result": "slip", "kind": "slip"})
	# at half health she mops it dry; a blow on the tap floods it again
	if not mopped and m.health <= m.max_health * 0.5:
		mopped = true
		wet = false
		events.append({"target": m, "result": "mopped", "kind": "mopped"})
	var box: Dictionary = hero.hit_box()
	if not wet and not box.is_empty() and room.has("tap") and box["x0"] - 30.0 <= room["tap"] and room["tap"] <= box["x1"] + 30.0:
		wet = true
		events.append({"target": hero, "result": "flooded", "kind": "tap"})


## Walking over a collectible (a matchbook, the torn photo) keeps it.
const COLLECTIBLES := ["matchbook", "photo", "trophy", "glove", "whistle", "coins", "note", "key"]  # (for score: level 3's trophy, level 4's
# signed boxing glove and Coach's whistle; level 5's slot coins, the vending machine's note, the casino key)


func _collect() -> void:
	for it in world.items.duplicate():
		if it["kind"] in COLLECTIBLES and absf(it["x"] - hero.x) <= 40.0 and absf(it["z"] - hero.z) <= 40.0 \
				and absf(it.get("y", 0.0) - hero.y) < 20.0:
			world.items.erase(it)
			collected.append(it["kind"])


func _spawn(kind: String, x: float, z: float, weapon := "", health := -1.0, wave_index := -1) -> void:
	var t := Tuning.fresh()
	t["health"] = health if health > 0.0 else KINDS[kind]["health"]
	t["street_right"] = floors[on]["length"] + 2000.0  # enemies walk in from beyond the lock
	t["street_left"] = -2000.0
	t["flat_line"] = tune.get("flat_line", false)
	var f = Fighter.new(t, x, z, world)
	f.team = 1
	var st: Dictionary = world.stairs_under(x, z, StreetWorld.step_height_at(world, x, z))
	if not st.is_empty():
		f.y = StreetWorld.step_height(st, x)  # placed on a flight of stairs (the team's Snick on the top step)
	f.can_climb = false  # enemies don't climb ladders (level 2)
	f.facing = -1 if x > hero.x else 1
	if weapon != "":
		f.take_weapon(weapon)
	f.shrugs = KINDS[kind].get("shrugs", [])
	if weapon == "" and KINDS[kind].has("weapon"):
		f.take_weapon(KINDS[kind]["weapon"])  # an enemy type's own weapon (Snick's knife)
	# a pipe Bruiser's pipe bends and breaks till Madame Chrome is beaten; after her it's yours to keep (roster v6)
	f.weapon_snaps = KINDS[kind].get("snaps", false) and not plan.get("after_chrome", false)
	f.dodges = KINDS[kind].get("dodges", [])
	f.parries = KINDS[kind].get("parries", [])
	f.gloves = KINDS[kind].get("gloves", [])
	f.grip = KINDS[kind].get("grip", false)
	f.hit_scale = KINDS[kind].get("hit_scale", 1.0)
	f.keeps_weapon = KINDS[kind].get("keeps_weapon", false)
	f.catches = KINDS[kind].get("catches", false)
	f.armour = kind == "godfather"  # (round one)
	f.reads_combos = KINDS[kind].get("reads", false)
	f.too_quick = KINDS[kind].get("too_quick", false)
	for k in ["walk_speed", "run_speed"]:
		f.tune[k] = f.tune[k] * KINDS[kind].get("speed", 1.0)
	var how: Dictionary = Brain.TYPES[KINDS[kind]["brain"]]
	enemies.append({"f": f, "brain": Brain.new(f, hero, dice_seed * 100 + tick + enemies.size(), how), "gone": false,
		"down_for": 0, "boss": false, "wave": wave_index, "kind": kind, "dropped": false})


## Where an enemy of a wave comes in: walking in from off screen left or right, out of a door at the back of the
## street, or already there (hidden: he waits, still, until the hero comes close, then jumps out).
func _arrive(e: Dictionary, at: float, wave_index: int) -> void:
	var from: String = e.get("from", "here")
	var x: float = at + e.get("dx", 0.0)
	var z: float = e.get("z", 80.0)
	match from:
		"left":
			x = at - LOCK_MARGIN + 40.0  # from behind, at the fight's own screen edge: never back across a cleared one
		"right":
			x = at + OFF_SCREEN
		"door":
			z = 0.0
	if from in ["left", "right"]:  # never from behind a wall or a shut door across the whole street: the near side of it
		for o in world.objects:
			if o["solid"] and not o["broken"] and o["z0"] <= 2.0 and o["z1"] >= tune["street_depth"] - 2.0 and o["top"] > 200.0:
				if from == "right" and o["x0"] > at and x > o["x0"] - 60.0:
					x = o["x0"] - 60.0
				elif from == "left" and o["x1"] < at and x < o["x1"] + 60.0:
					x = o["x1"] + 60.0
	_spawn(e["kind"], x, z, e.get("weapon", ""), -1.0, wave_index)
	for k in ["calls", "whistles", "hard", "whistled"]:  # the lookout's: who he whistles in, and how many times; a hard
		# version's tag; a goon he whistled in (the robot's numbers name him apart, the team's ask 11-05)
		if e.has(k):
			enemies[-1][k] = e[k]
	if e.get("hidden", false):
		enemies[-1]["brain"].dormant_until_within = AMBUSH
	if e.get("arguing", false):  # squaring off with another of his wave, slashing at him, till the hero comes close
		enemies[-1]["arguing"] = true
		enemies[-1]["brain"].dormant_until_within = e.get("wake", 420.0)
	if e.has("calls_x"):
		enemies[-1]["calls_x"] = e["calls_x"]
	if e.has("drops"):
		enemies[-1]["drops"] = e["drops"]


func _waves() -> void:
	var fl: Dictionary = floors[on]
	var waves: Array = fl["waves"]
	if fl["active_wave"] < 0 and fl["wave"] < waves.size() and hero.x >= waves[fl["wave"]]["at"] - 300.0:
		fl["active_wave"] = fl["wave"]
		fl["wave"] += 1
		fl["waiting"] = (waves[fl["active_wave"]]["enemies"] as Array).duplicate()
		var h: String = waves[fl["active_wave"]].get("hint", "")
		if not used_moves.has(waves[fl["active_wave"]].get("unless_used", "-")):
			_show_hint(h)  # (unless he's already used the move it teaches: level 5's escalator, the push kick)
	# a wave's enemies come in as they may: those with "after_down" once that many of the wave are down, and never more
	# than MAX_ON_SCREEN standing at once (the rest wait off screen)
	if fl["active_wave"] >= 0 and not fl["waiting"].is_empty():
		var at: float = waves[fl["active_wave"]]["at"]
		var down: int = enemies.filter(func(e): return e["wave"] == fl["active_wave"] and e["f"].defeated()).size()
		for e in (fl["waiting"] as Array).duplicate():
			if standing().size() >= MAX_ON_SCREEN:
				break
			if int(e.get("after_down", 0)) <= down:
				fl["waiting"].erase(e)
				_arrive(e, at, fl["active_wave"])
	# what the put-down leave behind (the Glow Punk his food, the Bruiser his bat)
	for e in enemies:
		if e["f"].defeated() and not e["dropped"]:
			e["dropped"] = true
			var drop: String = e.get("drops", KINDS.get(e["kind"], {}).get("drops", ""))  # (a layout can say: level 10's kit)
			if drop != "":
				world.drop(drop, e["f"].x, e["f"].z)
			if e.get("also_drops", "") != "":
				world.drop(e["also_drops"], e["f"].x + 50.0, e["f"].z)  # (a boss's second prize: Coach's whistle)
	if fl["active_wave"] >= 0 and fl["waiting"].is_empty() and not enemies.any(func(e): return e["wave"] == fl["active_wave"] and not e["gone"] and not e["f"].defeated()):
		# a locker that swings open by itself when its wave falls (the team's level 4: food before the Mauler)
		for op in plan["floors"][on].get("opens", []):
			if int(op[0]) == fl["active_wave"]:
				for o in world.objects:
					if o.get("name", "") == op[1] and not o["broken"]:
						o["broken"] = true
						if o.has("holds"):
							world.drop(o["holds"], (o["x0"] + o["x1"]) * 0.5, clampf(o["z1"] + 20.0, 0.0, tune["street_depth"]))
		fl["active_wave"] = -1  # its thugs beaten: the floor opens on (a boss waiting further on doesn't hold it)
	var bosses: Array = enemies.filter(func(e): return e["boss"])
	var boss_down: bool = boss_spawned and not bosses.is_empty() and bosses.all(func(e): return e["f"].defeated())
	if boss_down:
		won = true
	var win: Dictionary = plan.get("win", {})  # a level with no boss (level 9): won when he takes what it's for
	if not win.is_empty() and on == int(win.get("floor", on)) and hero.weapon == win.get("weapon", "-"):
		won = true


## Where the way on is, for a bot: the x of a doorway or ladder on this floor once its waves are beaten, or -1.
var goal_is_switch := false  # next_door() points at a switch to hit, not a way to walk through


func next_door() -> float:
	goal_is_switch = false
	if active_wave >= 0:
		return -1.0
	var switches: Array = plan.get("switches", [])
	for i in switches.size():  # a switch on this floor still to throw first: it opens the way (a door, the crane's cab)
		if int(switches[i]["floor"]) == on and not flipped.has(i) and _waves_done_before(switches[i]["x"]):
			goal_is_switch = true
			return float(switches[i]["x"])
	for l in plan.get("links", []):  # (a way to a floor he hasn't been on; back down a ladder or a cable too)
		if int(l["from"]) == on and not l.get("auto", false) and int(l["to"]) < on and not visited.has(int(l["to"])) and _waves_done_before(l["x"]) \
				and not plan.get("links", []).any(func(u): return int(u["from"]) == on and int(u["to"]) > on and not visited.has(int(u["to"]))):
			return float(l["x"])
		if int(l["from"]) == on and int(l["to"]) < on and not l.get("auto", false) and visited.has(int(l["to"])) and _floor_done_here() \
				and cleared(on):
			return float(l["x"])  # all done up here: back down the way he came (the switch thrown)
	for l in plan.get("links", []):
		if not _waves_done_before(l["x"]):
			continue  # (a fight before the way on: that first)
		if int(l["from"]) == on and l.get("kind", "") == "stairs" and int(l["to"]) > on:
			var st: Dictionary = stairs_of(l)
			# up the flight: first onto its bottom step, then on up to the landing's end
			var on_its_line: bool = hero.z <= st["z1"] + 2.0 and hero.x >= st["x0"] - 40.0
			return st["x1"] if not hero.flight().is_empty() or on_its_line else st["x0"] + 30.0
		if int(l["from"]) == on and not l.get("auto", false) and int(l["to"]) > on and not visited.has(int(l["to"])):
			return float(l["x"])
	return -1.0


## Every fight on this floor that comes before x (by where it starts) beaten: the way at x is his to take.
func _waves_done_before(x: float) -> bool:
	var fl: Dictionary = floors[on]
	var waves: Array = fl["waves"]
	for i in waves.size():
		if waves[i]["at"] - 300.0 < x and (i >= fl["wave"] or i == fl["active_wave"]):
			return false
	return true


## Nothing left to do on this floor (no switch to throw, no floor further on from here): the way back is the way on.
func _floor_done_here() -> bool:
	if plan.get("links", []).any(func(u): return int(u["from"]) == on and int(u["to"]) > on and not visited.has(int(u["to"]))):
		return false
	return not plan.get("links", []).any(func(u): return int(u["from"]) == on and u.get("auto", false))


## The flight a stairs link stands on (its landing at the link's x).
func stairs_of(l: Dictionary) -> Dictionary:
	for o in floors[int(l["from"])]["world"].objects:
		if o["kind"] == "stairs" and l["x"] >= o["x0"] and l["x"] <= o["x1"]:
			return o
	return {}


## A floor's waves all beaten?
func cleared(floor_index: int) -> bool:
	var fl: Dictionary = floors[floor_index]
	return fl["active_wave"] < 0 and fl["wave"] >= fl["waves"].size()


## The stairs: walking into a doorway at the back of the street (or, for the last stairs of a short layout, just
## reaching them) takes him to the floor it leads to, once this floor's waves are beaten.
func _links() -> void:
	if active_wave >= 0:
		return
	if arrived_x > -1.0e8:
		if absf(hero.x - arrived_x) > DOORWAY or hero.z > DOORWAY_Z + 30.0:
			arrived_x = -1.0e9  # he's stepped away from the doorway he came through
		else:
			return
	for l in plan.get("links", []):
		if int(l["from"]) != on:
			continue
		if l.get("kind", "") == "stairs":  # up a flight inside the screen: the landing's end leads on to the floor above
			if not hero.flight().is_empty() and hero.x >= l["x"] and hero.on_ground():
				_go_to(int(l["to"]), l["to_x"])
				return
			continue
		var auto: bool = l.get("auto", false)
		var at_door: bool = absf(hero.x - l["x"]) <= DOORWAY and hero.z <= DOORWAY_Z
		if (auto and hero.x >= l["x"] and cleared(on)) or (not auto and at_door and hero.on_ground() \
				and (not l.get("requires_clear", false) or cleared(on))):  # (a way down only once its fight is won)
			_go_to(int(l["to"]), l["to_x"], l.get("to_y", 0.0), l.get("to_z", 80.0))  # (to_y, to_z: back onto a landing)
			return


func _go_to(floor_index: int, x: float, at_y := 0.0, at_z := 80.0) -> void:
	on = floor_index
	visited[floor_index] = true
	hero.world = world
	hero.x = x
	hero.y = at_y
	hero.z = at_z
	hero._enter("idle")
	arrived_x = x
	_maybe_boss()


## The boss waits on his floor: he steps out the first time the hero arrives there.
func _maybe_boss() -> void:
	var boss: Dictionary = plan.get("boss", {})
	if boss_spawned or boss.is_empty() or int(boss.get("floor", 0)) != on:
		return
	boss_spawned = true
	# the boss, and any who fight with him (Twin Loans: two brothers, each where the layout puts him, up a flight or not)
	for b in [boss] + boss.get("with", []):
		_spawn(b.get("kind", "boss"), b.get("x", 1200.0), b.get("z", 80.0), b.get("weapon", ""), b.get("health", -1.0))
		enemies[-1]["boss"] = true
		for k in ["drops", "also_drops"]:  # (a layout's prize for him: Coach's first-aid kit and his whistle)
			if b.has(k):
				enemies[-1][k] = b[k]


## A blow that reaches a switch flips it, once: the door it names opens, on whatever floor it stands.
func _switches() -> void:
	var box: Dictionary = hero.hit_box()
	if box.is_empty():
		return
	var switches: Array = plan.get("switches", [])
	for i in switches.size():
		var s: Dictionary = switches[i]
		if flipped.has(i) or int(s["floor"]) != on:
			continue
		if box["x0"] - SWITCH_REACH <= s["x"] and s["x"] <= box["x1"] + SWITCH_REACH:
			flipped[i] = true
			if s.get("crane", false):  # a crane switch: thrown for good, the container stops along this floor; all of them
				# thrown open the cab
				events.append({"target": hero, "result": "crane_stopped", "kind": "switch"})
				var all_crane: Array = range(switches.size()).filter(func(k): return switches[k].get("crane", false))
				if all_crane.all(func(k): return flipped.has(k)):
					for fl in floors:
						for o in fl["world"].objects:
							if o.get("name", "") == "cab":
								o["broken"] = true
					events.append({"target": hero, "result": "cab_open", "kind": "switch"})
			for fl in floors:
				for o in fl["world"].objects:
					if o.get("name", "") == s["opens"]:
						o["broken"] = true  # an open door no longer blocks


func _downs() -> void:
	for e in enemies:
		if not e["gone"] and e["f"].defeated() and not e["boss"]:
			e["down_for"] += 1
			if e["down_for"] >= DOWN_TICKS:
				e["gone"] = true  # he's out of the fight; his weapon, if any, already lies on the street
	if hero.defeated():
		hero_down_for += 1
		if hero_down_for >= DOWN_TICKS:
			hero_down_for = 0
			lives -= 1
			if lives <= 0:
				lost = true
				return
			hero.health = hero.max_health  # a life lost: up again, the fight goes on where it was
			hero._enter("get_up")
