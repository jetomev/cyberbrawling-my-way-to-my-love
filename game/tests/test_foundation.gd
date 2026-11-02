extends "res://tests/test_case.gd"
## The ground everything else stands on: the project's settings, every script compiles, the first scene runs,
## and the test base itself reports a failure when it should.

const Version := preload("res://scripts/sim/version.gd")


func test_project_settings() -> void:
	eq(ProjectSettings.get_setting("application/config/name"), Version.TITLE, "project name matches the title (D-7)")
	eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 1920, "viewport width")
	eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 1080, "viewport height")
	check(not Version.TITLE.to_lower().contains("cyberpunk"), "no 'Cyberpunk' in the title (D-7)")


func test_every_script_compiles() -> void:
	var paths := gd_files("res://scripts") + gd_files("res://tests")
	check(paths.size() >= 4, "found the game's scripts (%d)" % paths.size())
	for p in paths:
		var s = load(p)
		check(s != null and s.can_instantiate(), "%s compiles" % p)


func test_main_scene_runs() -> void:
	var path: String = ProjectSettings.get_setting("application/run/main_scene")
	check(ResourceLoader.exists(path), "main scene %s exists" % path)
	var packed = load(path)
	check(packed is PackedScene, "main scene loads")
	if not packed is PackedScene:
		return
	var scene: Node = packed.instantiate()
	check(scene is Node2D, "main scene root is a Node2D")
	var title := scene.get_node_or_null("Title") as Label
	check(title != null, "main scene has its title label")
	scene.free()


func test_the_test_base_catches_a_failure() -> void:
	# Failing direction: a guard that never fails proves nothing. Feed the base known-bad input.
	var probe = load("res://tests/test_case.gd").new()
	probe.current = "probe"
	probe.check(false, "deliberate")
	probe.eq(1, 2, "deliberate")
	probe.eq(3, 3, "fine")
	eq(probe.checks, 3, "the base counts every check")
	eq(probe.failures.size(), 2, "the base records both failures and not the pass")


func gd_files(dir: String) -> Array[String]:
	var out: Array[String] = []
	for name in DirAccess.get_files_at(dir):
		if name.ends_with(".gd"):
			out.append(dir + "/" + name)
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(gd_files(dir + "/" + sub))
	return out
