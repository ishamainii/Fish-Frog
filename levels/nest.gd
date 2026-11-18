class_name Nest
extends Area3D
## A dip in the sand ringed by a low mound, where turtle eggs are buried. An
## egg that comes to rest inside it, with no crab holding it, is buried in
## the next free spot (see TurtleEgg.bury()), and egg_buried says so. A tall
## column of light marks it from anywhere on the beach.

signal egg_buried(egg: TurtleEgg)

## Of the hollow, out to the top of the mound (m).
@export_range(0.1, 3.0, 0.01) var radius := 0.45
## An egg slower than this counts as resting (m/s).
@export_range(0.01, 2.0, 0.01) var rest_speed := 0.4
@export var sand_color := Color(0.86, 0.74, 0.52)
@export var beacon_color := Color(0.45, 0.9, 0.75, 0.3)

var buried: Array[TurtleEgg] = []


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4
	monitorable = false
	var shape := CollisionShape3D.new()
	shape.shape = CylinderShape3D.new()
	shape.shape.radius = radius
	shape.shape.height = 0.6
	add_child(shape)

	var sand := StandardMaterial3D.new()
	sand.albedo_color = sand_color
	sand.roughness = 1.0
	var mound := TorusMesh.new()
	mound.inner_radius = radius * 0.7
	mound.outer_radius = radius
	mound.rings = 32
	mound.ring_segments = 8
	mound.material = sand
	var mound_mi := _add_mesh(mound, Transform3D(Basis().scaled(Vector3(1.0, 0.5, 1.0)), Vector3.ZERO))
	mound_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var hollow_mat := sand.duplicate() as StandardMaterial3D
	hollow_mat.albedo_color = sand_color.darkened(0.25)
	var hollow := CylinderMesh.new()
	hollow.top_radius = radius * 0.75
	hollow.bottom_radius = radius * 0.75
	hollow.height = 0.01
	hollow.radial_segments = 32
	hollow.rings = 1
	hollow.material = hollow_mat
	_add_mesh(hollow, Transform3D(Basis(), Vector3.UP * 0.005))

	var light := StandardMaterial3D.new()
	light.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	light.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	light.cull_mode = BaseMaterial3D.CULL_DISABLED
	light.albedo_color = beacon_color
	var column := CylinderMesh.new()
	column.top_radius = radius * 0.1
	column.bottom_radius = radius * 0.6
	column.height = 6.0
	column.radial_segments = 16
	column.rings = 1
	column.cap_top = false
	column.cap_bottom = false
	column.material = light
	var column_mi := _add_mesh(column, Transform3D(Basis(), Vector3.UP * 3.0))
	column_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _physics_process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		var egg := body as TurtleEgg
		if egg and not egg.buried and not is_instance_valid(egg.carrier) \
				and egg.linear_velocity.length() < rest_speed:
			egg.bury(_next_spot())
			buried.append(egg)
			egg_buried.emit(egg)


## Where the next egg goes: the first in the middle, the rest round it.
func _next_spot() -> Vector3:
	var i := buried.size()
	if i == 0:
		return global_position
	var angle := TAU * (i - 1) / 6.0
	return global_position + Vector3(cos(angle), 0.0, sin(angle)) * radius * 0.4


func _add_mesh(mesh: Mesh, at: Transform3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = at
	add_child(mi)
	return mi
