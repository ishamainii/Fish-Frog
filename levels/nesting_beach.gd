class_name NestingBeach
extends Node3D
## The first level. The world is the main scene, as it is; this adds turtle
## eggs to the cove on the far side of the mountain, a nest on the crabs'
## beach, and the HUD. The crabs carry the eggs home and the nest buries
## them. An egg left in the sea washes back to the cove.
##
## Stars: one for every egg home, one if the tide took none, and one for
## finishing within par_time.

const TITLE_SCENE := "res://levels/title.tscn"
const LEVEL_ID := "nesting_beach"

## Seconds to finish in for the time star.
@export var par_time := 300.0

var eggs: Array[TurtleEgg] = []
var buried := 0
var lost_to_tide := 0
var switches := 0
var rallies := 0
var time := 0.0
var running := false

@onready var world: Node3D = $World
@onready var nest: Nest = $Nest
@onready var hud: LevelHud = $Hud


func _ready() -> void:
	for egg in $Eggs.get_children():
		if egg is TurtleEgg:
			egg.terrain = world.get_node_or_null("Terrain3D")
			egg.water = world.get_node_or_null("Water")
			egg.washed_away.connect(_on_egg_washed_away)
			eggs.append(egg)
	nest.egg_buried.connect(_on_egg_buried)

	hud.started.connect(_start)
	hud.resumed.connect(_resume)
	hud.restart_requested.connect(_restart)
	hud.quit_requested.connect(_quit)
	hud.set_goal("Nesting Beach",
			"Carry the turtle eggs from the cove past the mountain to the nest on your beach.")
	hud.set_progress(0, eggs.size(), "eggs home")

	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var tips: Array[String] = [
		"The eggs glow faintly. The nest is the tall green light.",
		"Only the grab crab can carry an egg (Shift). It can ride a barnacle crab up the barnacle trails while it holds one.",
		"Eggs float. Leave one in the sea and the tide takes it back to the cove.",
		"U rallies the crabs to the flag, but it also sends every egg not yet buried back to the cove.",
	]
	hud.show_intro("Nesting Beach",
			"A sea turtle came ashore in the night and laid her eggs in a cove on the far side of the mountain, where the tide is rising. The crabs have seen it happen before. If the eggs are going to hatch, they have to be moved up the beach, to the nest the crabs dug on their side.",
			tips)


func _process(delta: float) -> void:
	if running:
		time += delta
		hud.set_time(time)


func _input(event: InputEvent) -> void:
	if not running:
		return
	# Not marked as handled: the camera still frees the mouse on Esc, and the
	# player still gets the rest.
	if event.is_action_pressed("ui_cancel") and not hud.is_card_open():
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		hud.show_pause()
	elif event.is_action_pressed("rally"):
		rallies += 1
	elif event.is_action_pressed("control_next") or event.is_action_pressed("control_previous"):
		switches += 1


func _start() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	running = true
	hud.toast("The cove is to the west, past the mountain.")


func _resume() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _quit() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCENE)


func _on_egg_buried(_egg: TurtleEgg) -> void:
	buried += 1
	hud.set_progress(buried, eggs.size(), "eggs home")
	var left := eggs.size() - buried
	if left > 0:
		hud.toast("Egg buried. %d to go." % left, UiStyle.TEAL)
	else:
		hud.toast("Every egg is safe in the nest!", UiStyle.TEAL)
		_finish()


func _on_egg_washed_away() -> void:
	lost_to_tide += 1
	hud.toast("The tide took an egg back to the cove.", UiStyle.CORAL)


func _finish() -> void:
	running = false
	await get_tree().create_timer(2.0).timeout
	var stars := 1
	if lost_to_tide == 0:
		stars += 1
	if time <= par_time:
		stars += 1
	var health_from := GameProgress.get_health()
	var best_before := GameProgress.get_best(LEVEL_ID)
	var new_best := GameProgress.record(LEVEL_ID, {"stars": stars, "time": time, "eggs": buried})
	var best_time: float = time if new_best else best_before.time

	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_results({
		"heading": "The eggs are home",
		"stars": stars,
		"new_best": new_best and not best_before.is_empty(),
		"rows": [
			["Time", GameProgress.format_time(time)],
			["Par time", GameProgress.format_time(par_time)],
			["Eggs home", "%d / %d" % [buried, eggs.size()]],
			["Eggs lost to the tide", lost_to_tide],
			["Crab switches", switches],
			["Rallies", rallies],
			["Best time", GameProgress.format_time(best_time)],
		],
		"health_from": health_from,
		"health_to": GameProgress.get_health(),
		"discovery_title": "Mural found: the old beach",
		"discovery": "The mural shows a beach crowded with turtle tracks, all running down to the water. The temperature of the sand decides whether a hatchling is male or female, and the warmer it gets, the more of them hatch female. As beaches warmed, filled with lights and litter, and were eaten away by the sea, fewer nests made it. Most kinds of sea turtle are now threatened.",
	})
