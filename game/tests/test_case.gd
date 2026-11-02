extends RefCounted
## Base for every test file. A test file is tests/test_<topic>.gd, extends this, and holds test_<name>() methods;
## the runner finds both by name, so a new test needs no list edit anywhere.

var checks := 0
var failures: Array[String] = []
var current := ""


func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures.append("%s: %s" % [current, msg])


func eq(got, want, msg: String) -> void:
	check(got == want, "%s (got %s, want %s)" % [msg, str(got), str(want)])
