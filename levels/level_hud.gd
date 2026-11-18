class_name LevelHud
extends CanvasLayer
## What a level shows over the game: its goal and progress in the top left,
## the clock in the top right, short messages along the top, and the cards
## that cover the game: the story before it starts, the pause menu (Esc), and
## the results at the end. It keeps working while the game is paused.
##
## The level tells it what to show; the buttons on the cards come back as
## the signals below.

signal started
signal resumed
signal restart_requested
signal quit_requested

const MARGIN := 16
## Seconds a message stays up before fading.
const TOAST_TIME := 3.5

var _title: Label
var _objective: Label
var _count: Label
var _bar: ProgressBar
var _clock: Label
var _toast: PanelContainer
var _toast_label: Label
var _toast_tween: Tween
var _card: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 5

	var goal := UiStyle.panel(UiStyle.PANEL, 14, 14)
	add_child(goal)
	goal.position = Vector2(MARGIN, MARGIN)
	var goal_box := VBoxContainer.new()
	goal_box.add_theme_constant_override("separation", 6)
	goal.add_child(goal_box)
	_title = UiStyle.label("", 22, UiStyle.SAND)
	goal_box.add_child(_title)
	_objective = UiStyle.paragraph("", 300, 16)
	goal_box.add_child(_objective)
	var progress := HBoxContainer.new()
	progress.add_theme_constant_override("separation", 10)
	goal_box.add_child(progress)
	_bar = UiStyle.health_bar(200)
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	progress.add_child(_bar)
	_count = UiStyle.label("", 18)
	progress.add_child(_count)

	var clock := UiStyle.panel(UiStyle.PANEL, 14, 12)
	add_child(clock)
	clock.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, MARGIN)
	clock.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_clock = UiStyle.label("0:00", 24)
	_clock.custom_minimum_size.x = 64
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock.add_child(_clock)

	_toast = UiStyle.panel(UiStyle.PANEL_LIGHT, 12, 12)
	add_child(_toast)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, MARGIN)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_label = UiStyle.label("", 18)
	_toast.add_child(_toast_label)
	_toast.modulate.a = 0.0


## The level's name and what to do in it.
func set_goal(title: String, objective: String) -> void:
	_title.text = title
	_objective.text = objective


func set_progress(done: int, total: int, noun: String) -> void:
	_count.text = "%d / %d %s" % [done, total, noun]
	_bar.value = float(done) / maxf(total, 1)


func set_time(seconds: float) -> void:
	_clock.text = GameProgress.format_time(seconds)


## Shows `text` along the top for a few seconds.
func toast(text: String, color := UiStyle.TEXT) -> void:
	_toast_label.text = text
	_toast_label.add_theme_color_override("font_color", color)
	# The panel shrinks back to fit shorter text.
	_toast.reset_size()
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, MARGIN)
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(TOAST_TIME)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.6)


## The card before the level starts: its story, a few tips, and a start
## button that says `started`.
func show_intro(title: String, story: String, tips: Array[String]) -> void:
	var box := _card_box(560)
	box.add_child(UiStyle.label(title, 32, UiStyle.SAND))
	box.add_child(UiStyle.paragraph(story, 520, 18, UiStyle.TEXT))
	var tip_box := VBoxContainer.new()
	tip_box.add_theme_constant_override("separation", 4)
	for tip in tips:
		tip_box.add_child(UiStyle.paragraph("•  " + tip, 520, 16))
	box.add_child(tip_box)
	var start := UiStyle.button("Start")
	start.pressed.connect(func(): _close_card(); started.emit())
	box.add_child(_centered(start))
	_open_card(box)


func show_pause() -> void:
	var box := _card_box(300)
	box.add_child(UiStyle.label("Paused", 30, UiStyle.SAND))
	var resume := UiStyle.button("Resume")
	resume.pressed.connect(func(): _close_card(); resumed.emit())
	var restart := UiStyle.button("Restart level", false)
	restart.pressed.connect(restart_requested.emit)
	var quit := UiStyle.button("Back to title", false)
	quit.pressed.connect(quit_requested.emit)
	for b in [resume, restart, quit]:
		b.custom_minimum_size.x = 240
		box.add_child(_centered(b))
	_open_card(box)


func hide_card() -> void:
	_close_card()


func is_card_open() -> bool:
	return is_instance_valid(_card)


## The card at the end. `result` has:
##   heading, stars (0 to 3), new_best (bool),
##   rows: [[name, value], ...], the numbers from the run,
##   health_from and health_to: the ocean's health before and after (0 to 1),
##   discovery_title and discovery: what the player learned.
func show_results(result: Dictionary) -> void:
	var box := _card_box(560)
	box.add_child(_centered(UiStyle.label(result.heading, 32, UiStyle.SAND)))
	var stars := StarRow.new()
	stars.star_size = 44
	stars.got = 0
	box.add_child(_centered(stars))
	if result.get("new_best", false):
		box.add_child(_centered(UiStyle.label("New best!", 16, UiStyle.TEAL)))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 6)
	for row in result.rows:
		grid.add_child(UiStyle.label(row[0], 18, UiStyle.MUTED))
		var value := UiStyle.label(str(row[1]), 18)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(value)
	var grid_panel := UiStyle.panel(UiStyle.PANEL_LIGHT, 10, 14)
	grid_panel.add_child(grid)
	box.add_child(grid_panel)

	var health_label := UiStyle.label("", 16, UiStyle.MUTED)
	var health := UiStyle.health_bar(520)
	health.value = result.health_from
	box.add_child(health_label)
	box.add_child(health)

	var mural := UiStyle.panel(Color(0.2, 0.16, 0.1, 0.9), 10, 14)
	var mural_box := VBoxContainer.new()
	mural_box.add_theme_constant_override("separation", 4)
	mural_box.add_child(UiStyle.label(result.discovery_title, 18, UiStyle.SAND))
	mural_box.add_child(UiStyle.paragraph(result.discovery, 500, 16, UiStyle.TEXT))
	mural.add_child(mural_box)
	box.add_child(mural)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	var again := UiStyle.button("Play again", false)
	again.pressed.connect(restart_requested.emit)
	var quit := UiStyle.button("Back to title")
	quit.pressed.connect(quit_requested.emit)
	buttons.add_child(again)
	buttons.add_child(quit)
	box.add_child(buttons)
	_open_card(box)

	# The stars pop in one by one, then the ocean's health fills up.
	var tween := create_tween()
	for i in result.stars:
		tween.tween_interval(0.35)
		tween.tween_callback(func(): stars.got = i + 1)
	_show_health(result.health_from, health, health_label)
	tween.tween_interval(0.3)
	tween.tween_method(_show_health.bind(health, health_label),
			result.health_from, result.health_to, 1.2).set_trans(Tween.TRANS_SINE)


func _show_health(value: float, bar: ProgressBar, label: Label) -> void:
	bar.value = value
	label.text = "Ocean health  %d%%" % roundi(value * 100.0)


func _card_box(width: float) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = width
	box.add_theme_constant_override("separation", 14)
	return box


func _open_card(content: Control) -> void:
	_close_card()
	var p := UiStyle.panel(UiStyle.PANEL, 18, 28)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.add_child(content)
	_card = UiStyle.overlay(p)
	add_child(_card)
	_card.modulate.a = 0.0
	create_tween().tween_property(_card, "modulate:a", 1.0, 0.2)


func _close_card() -> void:
	if is_instance_valid(_card):
		_card.queue_free()
	_card = null


func _centered(control: Control) -> CenterContainer:
	var c := CenterContainer.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(control)
	return c
