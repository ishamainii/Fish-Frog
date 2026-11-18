class_name TurtleEgg
extends Grabbable
## A sea turtle egg, round and about the size of a ping-pong ball, that a
## GrabCrab can carry like any other prop. One left lying in the sea for
## tide_time is washed back to where it started, and says so (washed_away).
## A Nest buries it, after which it's no longer a prop: no crab can pick it
## up and the player's rally leaves it where it is.
##
## The sea is wherever the terrain under it is below the water's resting
## height; without a terrain, anywhere below the water.

signal washed_away

## Seconds in the sea before the tide takes it.
@export_range(0.1, 10.0, 0.1) var tide_time := 1.5
## Whether a faint column of light stands over it, so it can be found from
## across the beach.
@export var show_beacon := true
@export var beacon_color := Color(1.0, 0.86, 0.55, 0.35)
## Set by the level.
@export var water: Node3D
@export var terrain: Node3D

var buried := false

var _in_sea := 0.0
var _beacon: MeshInstance3D


func _ready() -> void:
	super()
	if show_beacon:
		_beacon = _make_beacon()
		add_child(_beacon)


func _physics_process(delta: float) -> void:
	if buried or is_instance_valid(carrier) or not _is_in_sea():
		_in_sea = 0.0
		return
	_in_sea += delta
	if _in_sea >= tide_time:
		_in_sea = 0.0
		reset()
		washed_away.emit()


func _process(_delta: float) -> void:
	if _beacon:
		# Stays upright and above the egg however it rolls.
		_beacon.global_transform = Transform3D(Basis(), global_position + Vector3.UP * 1.5)
		_beacon.visible = not is_instance_valid(carrier)


## Settles it into the sand at `at`, for good.
func bury(at: Vector3) -> void:
	buried = true
	remove_from_group(GROUP)
	freeze = true
	collision_layer = 0
	collision_mask = 0
	if _beacon:
		_beacon.queue_free()
		_beacon = null
	var tween := create_tween()
	tween.tween_property(self, "global_position", at + Vector3.UP * get_half_height(), 0.4)
	tween.tween_property(self, "global_position", at, 0.8).set_trans(Tween.TRANS_SINE)


func _is_in_sea() -> bool:
	if not water:
		return false
	var sea_level := water.global_position.y
	if terrain and terrain.get("data"):
		var ground: float = terrain.data.get_height(global_position)
		return not is_nan(ground) and ground < sea_level and global_position.y < sea_level + 0.3
	return global_position.y < sea_level


func _make_beacon() -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = beacon_color
	var column := CylinderMesh.new()
	column.top_radius = 0.01
	column.bottom_radius = 0.025
	column.height = 3.0
	column.radial_segments = 8
	column.rings = 1
	column.cap_top = false
	column.cap_bottom = false
	column.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = column
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.top_level = true
	return mi
