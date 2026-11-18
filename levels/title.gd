class_name TitleScreen
extends Node3D
## The title screen: the island turning slowly behind the game's name, how
## healthy the ocean is so far, and a card for each level (see
## GameProgress.LEVELS) with its best result and a button to play it.
##
## The world is the main scene with the player switched off, so the crabs
## stand on the beach while the camera circles.

## What the camera circles, how far out and how high (m), and how fast
## (radians per second).
@export var orbit_center := Vector3(8.0, 1.0, 6.0)
@export var orbit_radius := 15.0
@export var orbit_height := 9.0
@export var orbit_speed := 0.04

var _angle := 0.6
var _ui: Control
var _reset_armed := false

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	get_tree().paused = false
	var player := $World.get_node_or_null("Player") as Player
	if player:
		player.active = false
		var controls := player.get_node_or_null("ControlsHud") as CanvasLayer
		if controls:
			controls.visible = false
	camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_ui()


func _process(delta: float) -> void:
	_angle += orbit_speed * delta
	camera.global_position = orbit_center + Vector3(cos(_angle) * orbit_radius, orbit_height, sin(_angle) * orbit_radius)
	camera.look_at(orbit_center, Vector3.UP)


func _build_ui() -> void:
	if is_instance_valid(_ui):
		_ui.queue_free()
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Ui.add_child(_ui)

	# A soft shade down the left, so the title reads over the bright beach.
	var shade := TextureRect.new()
	var gradient := GradientTexture2D.new()
	gradient.gradient = Gradient.new()
	gradient.gradient.set_color(0, Color(0.01, 0.06, 0.1, 0.75))
	gradient.gradient.set_color(1, Color(0.01, 0.06, 0.1, 0.0))
	gradient.fill_to = Vector2(1, 0)
	shade.texture = gradient
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(shade)

	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 40)
	layout.add_theme_constant_override("separation", 18)
	_ui.add_child(layout)

	layout.add_child(UiStyle.label("Fish Frog", 64, UiStyle.SAND))
	layout.add_child(UiStyle.paragraph("The Earth used to be a much better place to live. Bring it back, one animal and one level at a time.", 460, 19, UiStyle.TEXT))

	var health := UiStyle.panel(UiStyle.PANEL, 12, 14)
	var health_box := VBoxContainer.new()
	health_box.add_theme_constant_override("separation", 6)
	var value := GameProgress.get_health()
	health_box.add_child(UiStyle.label("Ocean health  %d%%" % roundi(value * 100.0), 18))
	var bar := UiStyle.health_bar(300)
	bar.value = value
	health_box.add_child(bar)
	health_box.add_child(UiStyle.label("Stars earned  %d / %d" % [GameProgress.get_total_stars(),
			GameProgress.LEVELS.size() * GameProgress.MAX_STARS], 15, UiStyle.MUTED))
	health.add_child(health_box)
	var health_row := HBoxContainer.new()
	health_row.add_child(health)
	layout.add_child(health_row)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(spacer)

	layout.add_child(UiStyle.label("Levels", 22, UiStyle.SAND))
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 16)
	for i in GameProgress.LEVELS.size():
		cards.add_child(_level_card(GameProgress.LEVELS[i], i + 1))
	layout.add_child(cards)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	var reset := UiStyle.button("Reset progress", false)
	reset.pressed.connect(_on_reset_pressed.bind(reset))
	var quit := UiStyle.button("Quit", false)
	quit.pressed.connect(get_tree().quit)
	footer.add_child(reset)
	footer.add_child(quit)
	layout.add_child(footer)


func _level_card(level: Dictionary, number: int) -> Control:
	var playable: bool = level.scene != ""
	var card := UiStyle.panel(UiStyle.PANEL if playable else Color(0.05, 0.1, 0.14, 0.7), 14, 16)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(250, 220)
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	box.add_child(UiStyle.label("LEVEL %d  ·  %s" % [number, level.animal.to_upper()], 13, UiStyle.TEAL if playable else UiStyle.MUTED))
	box.add_child(UiStyle.label(level.title, 24, UiStyle.SAND if playable else UiStyle.MUTED))
	var blurb := UiStyle.paragraph(level.blurb, 250, 15)
	blurb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(blurb)

	var best := GameProgress.get_best(level.id)
	var stars := StarRow.new()
	stars.star_size = 22
	stars.got = int(best.get("stars", 0))
	var best_row := HBoxContainer.new()
	best_row.add_theme_constant_override("separation", 10)
	best_row.add_child(stars)
	var best_text := ""
	if not best.is_empty():
		best_text = "Best  " + GameProgress.format_time(best.time)
	elif playable:
		best_text = "Not played yet"
	best_row.add_child(UiStyle.label(best_text, 15, UiStyle.MUTED))
	box.add_child(best_row)

	var play := UiStyle.button("Play" if playable else "Coming soon", playable)
	play.disabled = not playable
	play.size_flags_horizontal = Control.SIZE_FILL
	if playable:
		play.pressed.connect(get_tree().change_scene_to_file.bind(level.scene))
	box.add_child(play)
	return card


func _on_reset_pressed(button: Button) -> void:
	if not _reset_armed:
		_reset_armed = true
		button.text = "Sure? Click again"
		return
	_reset_armed = false
	GameProgress.reset()
	_build_ui()
