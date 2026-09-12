# hud.gd — HUD overlay (reused from 2D, works on CanvasLayer in 3D)
extends CanvasLayer

@onready var score_label: Label = $ScoreLabel
@onready var wave_label: Label = $WaveLabel
@onready var length_label: Label = $LengthLabel
@onready var death_screen: ColorRect = $DeathScreen
@onready var wave_announce: Label = $WaveAnnounce

var announce_timer: float = 0.0

var lvl_bar: ProgressBar
var evo_bar: ProgressBar
var flash_rect: ColorRect
var evo_tween: Tween

func _ready() -> void:
	death_screen.visible = false
	wave_announce.visible = false
	
	# Add Flash Rect
	flash_rect = ColorRect.new()
	flash_rect.color = Color(1.0, 1.0, 1.0, 0.0)
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash_rect)

	# Add Progress Bars
	var style_bg = StyleBoxFlat.new()
	style_bg.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	
	var style_lvl = StyleBoxFlat.new()
	style_lvl.bg_color = Color(0.0, 1.0, 0.5, 1.0)
	
	var style_evo = StyleBoxFlat.new()
	style_evo.bg_color = Color(1.0, 0.8, 0.0, 1.0)

	lvl_bar = ProgressBar.new()
	lvl_bar.position = Vector2(20, 100)
	lvl_bar.size = Vector2(200, 15)
	lvl_bar.show_percentage = false
	lvl_bar.add_theme_stylebox_override("background", style_bg)
	lvl_bar.add_theme_stylebox_override("fill", style_lvl)
	lvl_bar.max_value = 50.0
	lvl_bar.value = 0.0
	add_child(lvl_bar)

	evo_bar = ProgressBar.new()
	evo_bar.position = Vector2(20, 120)
	evo_bar.size = Vector2(300, 20)
	evo_bar.show_percentage = false
	evo_bar.add_theme_stylebox_override("background", style_bg)
	evo_bar.add_theme_stylebox_override("fill", style_evo)
	evo_bar.max_value = 200.0
	evo_bar.value = 0.0
	add_child(evo_bar)
	
	call_deferred("_connect_signals")
	update_hud(0, 1, 3)

func _connect_signals() -> void:
	var snake := get_node_or_null("../Snake")
	if snake:
		if snake.has_signal("score_changed"):
			snake.score_changed.connect(_on_score_changed)
		if snake.has_signal("died"):
			snake.died.connect(_on_snake_died)
		if snake.has_signal("ate_shard"):
			snake.ate_shard.connect(_on_ate_shard)
		if snake.has_signal("evolved"):
			snake.evolved.connect(_on_evolved)
		if snake.has_signal("xp_changed"):
			snake.xp_changed.connect(_on_xp_changed)

func _process(delta: float) -> void:
	if wave_announce.visible:
		announce_timer -= delta
		if announce_timer <= 0.0:
			wave_announce.visible = false
		else:
			wave_announce.modulate.a = clampf(announce_timer / 0.5, 0.0, 1.0)

	if death_screen.visible and Input.is_action_just_pressed("ui_accept"):
		get_tree().reload_current_scene()

func update_hud(p_score: int, wave: int, length: int) -> void:
	score_label.text = "SCORE: %d" % p_score
	wave_label.text = "WAVE: %d" % wave
	length_label.text = "LEN: %d" % length

func show_wave_announce(wave: int) -> void:
	if not wave_announce:
		return
	wave_announce.text = ">>> WAVE %d <<<" % wave
	wave_announce.visible = true
	announce_timer = 2.0
	wave_announce.modulate.a = 1.0

func _on_score_changed(new_score: int) -> void:
	var snake := get_node_or_null("../Snake")
	var length: int = snake.body.size() if snake else 0
	update_hud(new_score, 1, length)

func _on_ate_shard() -> void:
	var snake := get_node_or_null("../Snake")
	var length: int = snake.body.size() if snake else 0
	var sc: int = snake.score if snake else 0
	update_hud(sc, 1, length)

func _on_snake_died() -> void:
	death_screen.visible = true

func _on_evolved(_stage: int) -> void:
	if evo_tween:
		evo_tween.kill()
	evo_tween = create_tween()
	flash_rect.color = Color(1.0, 1.0, 1.0, 0.8)
	evo_tween.tween_property(flash_rect, "color", Color(1.0, 1.0, 1.0, 0.0), 1.0)

func _on_xp_changed(xp: int, _level: int, evo: int) -> void:
	lvl_bar.value = xp % 50

	var thresholds := [0, 200, 500, 1000, 2000]
	var current_thresh: int = thresholds[evo - 1] if (evo - 1) >= 0 and (evo - 1) < thresholds.size() else 2000
	var next_thresh: int = thresholds[evo] if evo < thresholds.size() else 2000
	
	evo_bar.min_value = current_thresh
	evo_bar.max_value = next_thresh
	evo_bar.value = clampf(xp, current_thresh, next_thresh)
