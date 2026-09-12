# tests/test_runner.gd — Base test framework for the CyberSnake project.
#
# Provides assertion helpers, pass/fail result collection, a summary report,
# and a deterministic process exit code (0 = pass, 1 = fail) for CI.
#
# Design:
#   - Suites extend this base class and override _ready() to run tests then
#     call _finish().
#   - Assertions carry a human-readable test name so failures are greppable.
#   - Signal-assertion helper wires a lambda, triggers, then disconnects so
#     suites never leak observers into the scene tree.
extends Node

var _pass_count: int = 0
var _fail_count: int = 0
var _failures: Array[String] = []


# ── reporting ────────────────────────────────────────────────────────
func _report_success(name: String) -> void:
	_pass_count += 1
	print("PASS  %s" % name)

func _report_failure(name: String, detail: String) -> void:
	_fail_count += 1
	_failures.append("%s :: %s" % [name, detail])
	print("FAIL  %s :: %s" % [name, detail])

func _finish() -> void:
	print("")
	print("=".repeat(56))
	print("SUITE %s" % name)
	print("PASS %d   FAIL %d" % [_pass_count, _fail_count])
	if _fail_count > 0:
		print("FAILURES:")
		for f in _failures:
			print("  - %s" % f)
	print("=".repeat(56))
	var code := 0 if _fail_count == 0 else 1
	get_tree().quit(code)


# ── assertions ───────────────────────────────────────────────────────
func assert_true(cond: bool, name: String) -> void:
	if cond:
		_report_success(name)
	else:
		_report_failure(name, "expected true, got false")

func assert_false(cond: bool, name: String) -> void:
	if not cond:
		_report_success(name)
	else:
		_report_failure(name, "expected false, got true")

func assert_eq(actual, expected, name: String) -> void:
	if actual == expected:
		_report_success(name)
	else:
		_report_failure(name, "expected %s, got %s" % [str(expected), str(actual)])

func assert_gt(actual, expected, name: String) -> void:
	if actual > expected:
		_report_success(name)
	else:
		_report_failure(name, "expected > %s, got %s" % [str(expected), str(actual)])

func assert_lt(actual, expected, name: String) -> void:
	if actual < expected:
		_report_success(name)
	else:
		_report_failure(name, "expected < %s, got %s" % [str(expected), str(actual)])

func assert_not_null(node: Node, name: String) -> void:
	if node != null:
		_report_success(name)
	else:
		_report_failure(name, "expected non-null node")

func assert_signal_emitted(node: Node, signal_name: String, name: String, trigger: Callable) -> void:
	var fired := false
	var cb := func(): fired = true
	node.connect(signal_name, cb)
	trigger.call()
	node.disconnect(signal_name, cb)
	if fired:
		_report_success(name)
	else:
		_report_failure(name, "signal '%s' was not emitted" % signal_name)
