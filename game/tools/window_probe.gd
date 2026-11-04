extends SceneTree
## Measures the timing edges for the testers: the last frame after a blow ends that a press still continues the combo,
## the perfect block's frames, the roll's untouchable frames. Prints plain lines. Not a test.

const Fighter := preload("res://scripts/sim/fighter.gd")
const Tuning := preload("res://scripts/sim/tuning.gd")


func _initialize() -> void:
	var t := Tuning.fresh()
	# combo: jab, then wait k free frames after the jab ends, then press again: cross (chain) or jab (new chain)?
	var last_ok := -1
	for k in range(0, 40):
		var f = Fighter.new(t)
		f.step({"punch": true})
		while f.state == "punch":
			f.step({})
		for i in k:
			f.step({})
		f.step({"punch": true})
		if f.state == "cross":
			last_ok = k
	# k empty frames, then the press: the press comes k + 1 frames after the frame the blow ended on
	print("combo: a press up to %d frames after a blow ends continues the chain; at %d it starts a new one" % [last_ok + 1, last_ok + 2])
	# early press: how many frames before a blow ends a press is kept
	var early := -1
	for k in range(1, 20):
		var f = Fighter.new(t)
		f.step({"punch": true})
		var n: int = f.attack_length("punch")
		for i in n - k - 1:
			f.step({})
		f.step({"punch": true})
		for i in k + 2:
			f.step({})
		if f.state == "cross" or f.chain == "PP":
			early = k
	print("buffer: a press up to %d frames before the blow ends is kept and fires as it ends" % early)
	var f = Fighter.new(t)
	f.step({"block": true})
	var perfect := 0
	while f.blocking() == "perfect":
		perfect += 1
		f.step({"block": true})
	print("block: perfect for its first %d frames from the press, then plain" % perfect)
	var r = Fighter.new(t)
	r.step({"roll": true})
	var frames := []
	var n := 0
	while r.state == "roll":
		if r.evading():
			frames.append(r.t)
		r.step({})
		n += 1
	print("roll: lasts %d frames; untouchable on its frames %d to %d (%d frames)" % [n, frames[0], frames[-1], frames.size()])
	quit()
