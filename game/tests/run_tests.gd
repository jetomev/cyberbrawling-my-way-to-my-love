extends SceneTree
## Headless test suite: godot --headless --path game -s res://tests/run_tests.gd   (use scripts/test.sh: fenced, timed)
## Runs every test_*() in every tests/test_*.gd. One line per test, then "OK <n> tests (<m> checks)" or "FAILED ...".
## Exit code 0 = pass. A test file that does not load, or a test that makes no check, is a failure, never a skip.

const TestCase := preload("res://tests/test_case.gd")

var tests := 0
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	var files := test_files()
	if files.is_empty():
		failures.append("no test files found in res://tests/")
	for path in files:
		run_file(path)
	if failures.is_empty():
		print("OK %d tests (%d checks)" % [tests, checks])
		quit(0)
	else:
		for f in failures:
			print("  - " + f)
		print("FAILED %d problem(s) in %d tests (%d checks)" % [failures.size(), tests, checks])
		quit(1)


func test_files() -> Array[String]:
	var out: Array[String] = []
	for name in DirAccess.get_files_at("res://tests"):
		if name.begins_with("test_") and name.ends_with(".gd") and name != "test_case.gd":
			out.append("res://tests/" + name)
	out.sort()
	return out


func run_file(path: String) -> void:
	var script = load(path)
	if script == null or not script.can_instantiate():
		failures.append("%s did not load (a parse error?)" % path)
		return
	var suite = script.new()
	if not suite is TestCase:
		failures.append("%s does not extend tests/test_case.gd" % path)
		return
	var names: Array[String] = []
	for m in suite.get_method_list():
		var n: String = m["name"]
		if n.begins_with("test_") and not names.has(n):
			names.append(n)
	names.sort()
	if names.is_empty():
		failures.append("%s holds no test_ methods" % path)
	for n in names:
		suite.current = "%s %s" % [path.get_file().get_basename(), n]
		var checks_before: int = suite.checks
		var fails_before: int = suite.failures.size()
		var t0 := Time.get_ticks_msec()
		suite.call(n)
		if suite.checks == checks_before:
			suite.failures.append("%s: made no checks" % suite.current)
		var ok: bool = suite.failures.size() == fails_before
		print("%s %s (%d ms)" % ["PASS" if ok else "FAIL", suite.current, Time.get_ticks_msec() - t0])
		tests += 1
	checks += suite.checks
	failures.append_array(suite.failures)
