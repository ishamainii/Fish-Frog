extends Node3D
## Physics-based carry for the bird. Mark eligible RigidBody3D nodes
## with the "grabbable" group; they remain collidable with the world.

@export_range(0.1, 5.0, 0.1) var grab_radius: float = 1.5
@export var grip_offset := Vector3(0.0, -0.7, -1.0)
@export_range(0.1, 100.0, 0.1) var maximum_mass: float = 5.0
@export_range(1.0, 200.0, 1.0) var carry_stiffness: float = 80.0
@export_range(1.0, 50.0, 1.0) var carry_damping: float = 18.0
@export_range(1.0, 1000.0, 1.0) var maximum_carry_force: float = 200.0
@export_range(0.5, 10.0, 0.1) var release_distance: float = 3.0
@export var show_grab_hint: bool = true

@onready var bird: RigidBody3D = get_parent() as RigidBody3D
@onready var visuals: Node3D = bird.get_node_or_null("Visuals")

var held_body: RigidBody3D
var _grab_requested := false
var _added_bird_exception := false
var _added_object_exception := false
var _hint := Label.new()
var _query_shape := SphereShape3D.new()


func _ready() -> void:
	var hud := CanvasLayer.new()
	hud.name = "GrabHint"
	add_child(hud)
	hud.add_child(_hint)
	_hint.position = Vector2(16, 44)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and event.is_action_pressed("grab") and not event.is_echo():
		# Space queries run in the physics tick rather than the input callback.
		_grab_requested = true
		get_viewport().set_input_as_handled()


func get_grip_position() -> Vector3:
	var grip_basis := visuals.global_basis.orthonormalized() if visuals else bird.global_basis.orthonormalized()
	return bird.global_position + grip_basis * grip_offset


func find_grab_target() -> RigidBody3D:
	_query_shape.radius = grab_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _query_shape
	query.transform = Transform3D(Basis.IDENTITY, get_grip_position())
	query.collision_mask = bird.collision_mask
	query.exclude = [bird.get_rid()]
	var nearest: RigidBody3D
	var nearest_distance := INF
	var space := get_world_3d().direct_space_state
	for hit in space.intersect_shape(query, 64):
		var body := hit.collider as RigidBody3D
		if body == null or body.is_queued_for_deletion() or body.freeze or not body.is_in_group("grabbable") or body.mass > maximum_mass:
			continue
		var distance := get_grip_position().distance_squared_to(body.global_position)
		if distance > grab_radius * grab_radius or distance >= nearest_distance:
			continue
		var ray := PhysicsRayQueryParameters3D.create(bird.global_position, body.global_position, bird.collision_mask, [bird.get_rid(), body.get_rid()])
		ray.hit_from_inside = true
		if not space.intersect_ray(ray).is_empty():
			continue
		nearest = body
		nearest_distance = distance
	return nearest


func try_grab() -> bool:
	if is_instance_valid(held_body):
		return false
	held_body = find_grab_target()
	if held_body == null:
		return false
	_added_bird_exception = not bird.get_collision_exceptions().has(held_body)
	_added_object_exception = not held_body.get_collision_exceptions().has(bird)
	if _added_bird_exception:
		bird.add_collision_exception_with(held_body)
	if _added_object_exception:
		held_body.add_collision_exception_with(bird)
	# Remove exceptions while its physics RID is still alive, including deletion.
	held_body.tree_exiting.connect(release, CONNECT_ONE_SHOT)
	held_body.sleeping = false
	return true


func release() -> void:
	if is_instance_valid(held_body):
		if held_body.tree_exiting.is_connected(release):
			held_body.tree_exiting.disconnect(release)
		if _added_bird_exception:
			bird.remove_collision_exception_with(held_body)
		if _added_object_exception:
			held_body.remove_collision_exception_with(bird)
	held_body = null
	_added_bird_exception = false
	_added_object_exception = false


func _physics_process(_delta: float) -> void:
	if _grab_requested:
		_grab_requested = false
		if is_instance_valid(held_body):
			release()
		else:
			try_grab()
	if is_instance_valid(held_body):
		var error := get_grip_position() - held_body.global_position
		if held_body.is_queued_for_deletion() or error.length() > release_distance:
			release()
		else:
			# A damped spring carries the body without teleporting it through walls.
			var relative_velocity := held_body.linear_velocity - bird.linear_velocity
			var force := (error * carry_stiffness - relative_velocity * carry_damping) * held_body.mass
			held_body.apply_central_force(force.limit_length(maximum_carry_force))
	else:
		held_body = null
	_hint.visible = show_grab_hint and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if _hint.visible:
		_hint.text = "E: Release" if held_body else "E: Grab" if find_grab_target() else ""


func _exit_tree() -> void:
	release()
