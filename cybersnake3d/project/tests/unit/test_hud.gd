# tests/unit/test_hud.gd — Unit suite for hud.gd overcharge-bar logic.
#
# Builds an isolated HUD harness: a mock Snake sibling (with the vars the HUD
# reads) plus the @onready children the HUD script expects, then drives
# _update_overcharge_bar() directly so every assertion is deterministic
# (no auto-processing).
extends "res://tests/test_runner.gd"

const HudScript = preload("res://scripts/hud.gd")

# The overcharge bar contract: it unlocks at evolution stage 3 and its max
# value must track the live cooldown formula `maxf(3.0, 8.0 - stage)` so the
# meter reads correctly at stages 3–5. This test pins that contract.
const COOLDOWN_STAGE_3: float = 5.0   # 8 - 3
const COOLDOWN_STAGE_5: float = 3.0   # floored at 3

var _snake: Node
var _hud: CanvasLayer
var _score_label: Label
var _wave_label: Label
var _length_label: Label
var _death_screen: ColorRect
var _wave_announce: Label


func _ready() -> void:
	_build_harness()
	_run_all()
	_teardown()
	_finish()

func _build_harness() -> void:
	# Mock Snake sibling. The HUD reads these vars from ../Snake; the signals
	# are declared so _connect_signals() (deferred from _ready) doesn't warn.
	var sp := GDScript.new()
	sp.source_code = "extends Node
signal hurt
signal score_changed(new_score: int)
signal died
signal ate_shard
signal evolved(stage: int)
signal xp_changed(current_xp: int, current_level: int, current_evo: int)
signal boss_slain(value: int)
var evolution_stage: int = 3
var overcharge_timer: float = 4.0
var overcharge_active: bool = false
var score: int = 0
var body: Array = []
var hp: int = 3
var max_hp: int = 3
var combo: int = 0
var combo_timer: float = 0.0
var combo_window: float = 2.0
var last_gain: int = 0
var level: int = 1
var xp: int = 0
var paused: bool = false
var is_alive: bool = true"
	sp.reload()
	_snake = Node.new()
	_snake.set_script(sp)
	_snake.name = "Snake"
	add_child(_snake)

	# HUD node with the @onready children present *before* it enters the tree
	# so the @onready vars resolve when _ready() runs.
	_hud = CanvasLayer.new()
	_hud.set_script(HudScript)
	_hud.name = "HUD"
	_score_label = Label.new()
	_score_label.name = "ScoreLabel"
	_hud.add_child(_score_label)
	_wave_label = Label.new()
	_wave_label.name = "WaveLabel"
	_hud.add_child(_wave_label)
	_length_label = Label.new()
	_length_label.name = "LengthLabel"
	_hud.add_child(_length_label)
	_wave_announce = Label.new()
	_wave_announce.name = "WaveAnnounce"
	_hud.add_child(_wave_announce)
	_death_screen = ColorRect.new()
	_death_screen.name = "DeathScreen"
	_hud.add_child(_death_screen)
	var death_label := Label.new()
	death_label.name = "DeathLabel"
	_death_screen.add_child(death_label)
	var restart_label := Label.new()
	restart_label.name = "RestartLabel"
	_death_screen.add_child(restart_label)
	# Entering the tree triggers _ready(), which creates the dynamic children
	# (overcharge_bar, hp_bar, ...) and schedules _connect_signals().
	add_child(_hud)

func _run_all() -> void:
	_test_bar_hidden_below_stage_3()
	_test_bar_max_tracks_stage_3()
	_test_bar_max_floors_at_stage_5()
	_test_format_score_groups_thousands()
	_test_wave_label_zero_pads()
	_test_combo_display_shows_only_live_window()
	_test_combo_tier_color_matches_streak()
	_test_countdown_text_hides_when_elapsed()
	_test_gain_text_formats_gain()
	_test_is_boss_wave()
	_test_hp_ratio_clamps()
	_test_evolution_bar_fill_clamps()
	_test_wave_announce_time_persists()
	_test_game_over_text_formats_scores()

func _set_stage(stage: int) -> void:
	_snake.evolution_stage = stage

func _update_bar() -> void:
	_hud._update_overcharge_bar()

func _test_bar_hidden_below_stage_3() -> void:
	_set_stage(1)
	_update_bar()
	assert_false(_hud.overcharge_bar.visible, "overcharge bar hidden below stage 3")

func _test_bar_max_tracks_stage_3() -> void:
	_set_stage(3)
	_update_bar()
	assert_true(_hud.overcharge_bar.visible, "overcharge bar visible at stage 3")
	assert_eq(_hud.overcharge_bar.max_value, COOLDOWN_STAGE_3, "max_value = 8 - stage at stage 3")

func _test_bar_max_floors_at_stage_5() -> void:
	_set_stage(5)
	_update_bar()
	assert_eq(_hud.overcharge_bar.max_value, COOLDOWN_STAGE_5, "max_value floored at 3.0 at stage 5")

func _test_format_score_groups_thousands() -> void:
	var hud := _hud
	assert_eq(hud.format_score(0), "0", "score 0 formats as 0")
	assert_eq(hud.format_score(12345), "12,345", "score groups thousands")
	assert_eq(hud.format_score(999), "999", "sub-thousand stays plain")
	assert_eq(hud.format_score(-1234), "-1,234", "negative score formats with minus")

func _test_wave_label_zero_pads() -> void:
	var hud := _hud
	assert_eq(hud.wave_label_text(3), "WAVE: 03", "wave 3 zero-pads")
	assert_eq(hud.wave_label_text(12), "WAVE: 12", "wave 12 stays two digits")

func _test_combo_display_shows_only_live_window() -> void:
	var hud := _hud
	assert_eq(hud.combo_display_text(3, 0.0), "", "expired window shows empty")
	assert_eq(hud.combo_display_text(3, 0.5), "COMBO x3", "live window shows multiplier")

func _test_combo_tier_color_matches_streak() -> void:
	var hud := _hud
	assert_eq(hud.combo_tier_color(3), Color(0.3, 1.0, 0.9), "x3 combo is cyan")
	assert_eq(hud.combo_tier_color(5), Color(1, 0.85, 0.2), "x5 combo is gold")
	assert_eq(hud.combo_tier_color(8), Color(1, 0.25, 0.25), "x8 combo is red-hot")

func _test_countdown_text_hides_when_elapsed() -> void:
	var hud := _hud
	assert_eq(hud.countdown_text(5), "NEXT WAVE IN 5", "live countdown shows seconds")
	assert_eq(hud.countdown_text(0), "", "elapsed countdown hides")

func _test_gain_text_formats_gain() -> void:
	var hud := _hud
	assert_eq(hud.gain_text(150), "+150", "gain popup shows plus sign")
	assert_eq(hud.gain_text(0), "", "no gain hides popup")

func _teardown() -> void:
	_hud.queue_free()
	_snake.queue_free()

func _test_is_boss_wave() -> void:
	assert_eq(_hud.is_boss_wave(9), false, "wave 9 is not a boss wave")
	assert_eq(_hud.is_boss_wave(10), true, "wave 10 is a boss wave")

func _test_hp_ratio_clamps() -> void:
	assert_eq(_hud.hp_ratio(50.0, 100.0), 0.5, "half hp fills bar at 50%")
	assert_eq(_hud.hp_ratio(120.0, 100.0), 1.0, "over-full hp clamps to 1.0")

func _test_evolution_bar_fill_clamps() -> void:
	assert_eq(_hud.evolution_bar_fill(250.0, 200.0, 500.0), 250.0, "fill shows xp within stage range")
	assert_eq(_hud.evolution_bar_fill(600.0, 200.0, 500.0), 500.0, "fill clamps at next threshold")

func _test_wave_announce_time_persists() -> void:
	assert_eq(_hud.wave_announce_time(), 2.0, "wave announce persists 2 seconds")

func _test_game_over_text_formats_scores() -> void:
	assert_eq(_hud.game_over_text(1200, 1500), "GAME OVER — SCORE: 1200 — BEST: 1500", "death screen shows both scores")
