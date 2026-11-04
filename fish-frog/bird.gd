extends RigidBody3D

@export var flap_boost: float = 5.0
@export var forward_acceleration: float = 8.0
@export var braking_deceleration: float = 3.0
@export_range(0.0, 2.0, 0.01) var glide_drag: float = 0.08
@export var maximum_pitch: float = deg_to_rad(60)
@export var maximum_roll: float = deg_to_rad(45)
@export var maximum_turn_rate: float = deg_to_rad(120)
@export var maximum_pitch_rate: float = deg_to_rad(45)
@export var max_velocity: float = 200

@export_group("Walking")
@export_range(0.1, 20.0, 0.1) var walk_speed: float = 5.0
@export_range(1.0, 100.0, 1.0) var walk_acceleration: float = 25.0
@export_range(1.0, 100.0, 1.0) var walk_braking: float = 35.0
@export var walk_turn_speed: float = deg_to_rad(360.0)
@export_range(0.001, 0.02, 0.001) var ground_look_sensitivity: float = 0.003
@export var maximum_ground_look_pitch: float = deg_to_rad(60.0)
@export var maximum_walkable_slope: float = deg_to_rad(45.0)
@export_range(1.0, 20.0, 0.5) var takeoff_speed: float = 6.5

@export_group("Cursor Steering")
@export_range(1.0, 1000.0, 1.0) var cursor_radius: float = 200.0
@export_range(0.0, 0.9, 0.01) var cursor_dead_zone: float = 0.08
@export_range(1.0, 3.0, 0.1) var cursor_response_curve: float = 1.5
@export var maximum_aim_yaw: float = deg_to_rad(25)
@export var maximum_aim_pitch: float = deg_to_rad(20)

@export_group("Response Times")
@export_range(0.01, 2.0, 0.01) var aim_response_time: float = 0.10
@export_range(0.01, 2.0, 0.01) var bank_response_time: float = 0.20
@export_range(0.01, 2.0, 0.01) var travel_response_time: float = 0.35
@export_range(0.01, 2.0, 0.01) var camera_response_time: float = 0.45

@export_group("Camera Follow")
@export_range(0.0, 0.95, 0.05) var camera_aim_follow: float = 0.35
@export var maximum_camera_yaw_lag: float = deg_to_rad(12)
@export var maximum_camera_pitch_lag: float = deg_to_rad(8)
@export var maximum_camera_roll: float = deg_to_rad(5)
@export var show_cursor_debug: bool = true

@onready var visuals: Node3D = $Visuals
@onready var camera_pivot: Node3D = $CameraPivot

var yaw: float = 0.0
var pitch: float = 0.0
var roll: float = 0.0
var aim_yaw: float = 0.0
var aim_pitch: float = 0.0
var cursor_offset := Vector2.ZERO
var cursor_bias := Vector2.ZERO
var cursor_debug_label := Label.new()
var is_grounded := false
var ground_normal := Vector3.UP
var ground_velocity := Vector3.ZERO
var ground_camera_yaw := 0.0
var ground_camera_pitch := 0.0
var takeoff_cooldown := 0.0
var _flap_requested := false


func _ready() -> void:
	# Floor detection uses actual support contacts, not proximity to a wall.
	max_contacts_reported = maxi(max_contacts_reported, 8)
	# Keep the readout while tuning; it can be hidden in the Inspector.
	var debug_layer := CanvasLayer.new()
	add_child(debug_layer)
	debug_layer.add_child(cursor_debug_label)
	cursor_debug_label.position = Vector2(16.0, 16.0)
	cursor_debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		cursor_offset = Vector2.ZERO
		cursor_bias = Vector2.ZERO
		get_viewport().set_input_as_handled()
		return

	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return

	if event is InputEventMouseMotion:
		_apply_cursor_motion(event.screen_relative)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("Flap") and not event.is_echo():
		_flap_requested = true
		get_viewport().set_input_as_handled()


func _apply_cursor_motion(movement: Vector2) -> void:
	if is_grounded:
		ground_camera_yaw = wrapf(ground_camera_yaw - movement.x * ground_look_sensitivity, -PI, PI)
		ground_camera_pitch = clampf(ground_camera_pitch - movement.y * ground_look_sensitivity,
			-maximum_ground_look_pitch, maximum_ground_look_pitch)
		return
	var radius := maxf(cursor_radius, 1.0)
	cursor_offset = (cursor_offset + movement).limit_length(radius)
	cursor_bias = _get_cursor_bias()


func _get_cursor_bias() -> Vector2:
	var input := (cursor_offset / maxf(cursor_radius, 1.0)).limit_length(1.0)
	var strength := input.length()
	var dead_zone := clampf(cursor_dead_zone, 0.0, 0.9)
	if strength <= dead_zone:
		return Vector2.ZERO
	# Remap outside the dead zone, retaining precision near the center.
	var remapped := (strength - dead_zone) / (1.0 - dead_zone)
	return input.normalized() * pow(remapped, cursor_response_curve)


func _response_weight(delta: float, response_time: float) -> float:
	return 1.0 - exp(-delta / maxf(response_time, 0.001))


func _update_steering(delta: float, controls_active: bool = true) -> void:
	var horizontal_speed := Vector2(linear_velocity.x, linear_velocity.z).length()
	var full_turn_speed: float = 25.0
	var speed_fraction := clampf(
		horizontal_speed / full_turn_speed,
		0.0, 1.0
	)
	var turn_multiplier := lerpf(0.2, 1.0, speed_fraction)
	cursor_bias = _get_cursor_bias() if controls_active else Vector2.ZERO
	var aim_weight := _response_weight(delta, aim_response_time)
	aim_yaw = lerp_angle(aim_yaw, -cursor_bias.x * maximum_aim_yaw, aim_weight)
	aim_pitch = lerp_angle(aim_pitch, -cursor_bias.y * maximum_aim_pitch, aim_weight)

	# Right input lowers the right wing (negative local Z rotation).
	roll = lerp_angle(roll, -cursor_bias.x * maximum_roll,
		_response_weight(delta, bank_response_time))
	# Bank leads the turn. A held bias keeps changing heading indefinitely.
	yaw = wrapf(yaw + roll / maxf(maximum_roll, 0.001) * maximum_turn_rate * turn_multiplier * delta, -PI, PI)
	pitch = clampf(pitch - cursor_bias.y * maximum_pitch_rate * delta, -maximum_pitch, maximum_pitch)


func _steer_velocity(motion: Vector3, forward: Vector3, delta: float) -> Vector3:
	var speed := motion.length()
	if speed < 0.001:
		return motion
	var direction := motion / speed
	var axis := direction.cross(forward)
	var angle := direction.angle_to(forward)
	if angle < 0.00001:
		return motion
	# An opposite direction has no cross-product axis; choose a stable one.
	if axis.length_squared() < 0.000001:
		axis = direction.cross(Vector3.UP)
		if axis.length_squared() < 0.000001:
			axis = direction.cross(Vector3.RIGHT)
	return direction.rotated(axis.normalized(), angle *
		_response_weight(delta, travel_response_time)) * speed


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var controls_active := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	takeoff_cooldown = maxf(0.0, takeoff_cooldown - state.step)
	_update_ground_contact(state)
	if _flap_requested:
		_flap_requested = false
		if controls_active:
			state.linear_velocity = _perform_flap(state.linear_velocity)
	if is_grounded:
		var movement := Input.get_vector("walk_left", "walk_right", "walk_forward", "walk_backward")
		state.linear_velocity = _update_walk_velocity(state.linear_velocity, movement, state.step, controls_active)
	else:
		_update_steering(state.step, controls_active)
		state.linear_velocity = _update_flight_velocity(state.linear_velocity, state.step,
			controls_active, Input.is_action_pressed("boost"))


func _update_ground_contact(state: PhysicsDirectBodyState3D) -> void:
	var supported := false
	var best_up := cos(maximum_walkable_slope)
	ground_normal = Vector3.UP
	ground_velocity = Vector3.ZERO
	if takeoff_cooldown <= 0.0:
		for contact in range(state.get_contact_count()):
			# "Local" identifies this body's side of the contact; normals are world-space.
			var normal := state.get_contact_local_normal(contact).normalized()
			var support_velocity := state.get_contact_collider_velocity_at_position(contact)
			# Do not reattach to a floor while moving away from it after a flap.
			if normal.y >= best_up and (state.linear_velocity - support_velocity).dot(normal) <= 1.0:
				best_up = normal.y
				ground_normal = normal
				ground_velocity = support_velocity
				supported = true
	_set_grounded(supported)


func _set_grounded(value: bool) -> void:
	if is_grounded == value:
		return
	is_grounded = value
	# Both transitions clear steering input so mouse look cannot become a turn.
	cursor_offset = Vector2.ZERO
	cursor_bias = Vector2.ZERO
	aim_yaw = 0.0
	aim_pitch = 0.0
	pitch = 0.0
	roll = 0.0
	if is_grounded:
		ground_camera_yaw = camera_pivot.rotation.y
		ground_camera_pitch = clampf(camera_pivot.rotation.x,
			-maximum_ground_look_pitch, maximum_ground_look_pitch)
	else:
		yaw = ground_camera_yaw
		# Keep vertical camera look continuous when returning to flight.
		pitch = clampf(ground_camera_pitch, -maximum_pitch, maximum_pitch)
		ground_normal = Vector3.UP
		ground_velocity = Vector3.ZERO


func _perform_flap(motion: Vector3) -> Vector3:
	if is_grounded:
		_set_grounded(false)
		takeoff_cooldown = 0.2
		motion.y = maxf(motion.y, 0.0) + takeoff_speed
	else:
		motion.y += flap_boost
	return motion


func _update_walk_velocity(motion: Vector3, movement: Vector2, delta: float, controls_active: bool) -> Vector3:
	if not controls_active:
		movement = Vector2.ZERO
	movement = movement.limit_length(1.0)
	var camera_basis := Basis(Vector3.UP, ground_camera_yaw)
	var direction := camera_basis.x * movement.x + camera_basis.z * movement.y
	var desired := direction.slide(ground_normal).normalized() * walk_speed * movement.length()
	var relative := motion - ground_velocity
	var tangent := relative.slide(ground_normal)
	var acceleration := walk_acceleration if not movement.is_zero_approx() else walk_braking
	tangent = tangent.move_toward(desired, acceleration * delta)
	if not direction.is_zero_approx():
		var target_yaw := atan2(-direction.x, -direction.z)
		yaw = rotate_toward(yaw, target_yaw, walk_turn_speed * delta)
	return tangent + ground_normal * relative.dot(ground_normal) + ground_velocity


func _update_flight_velocity(motion: Vector3, delta: float, controls_active: bool, accelerating: bool) -> Vector3:
	if controls_active:
		var forward := -Basis.from_euler(Vector3(pitch, yaw, 0.0)).z
		if accelerating:
			motion += forward * forward_acceleration * delta
		# Redirect existing momentum even when the accelerate button is released.
		motion = _steer_velocity(motion, forward, delta)
		if not accelerating:
			# Glide with gentle drag instead of actively braking to a stop.
			var retention := exp(-glide_drag * delta)
			motion.x *= retention
			motion.z *= retention
	else:
		# Releasing mouse control still brakes horizontal motion.
		var horizontal := Vector3(motion.x, 0.0, motion.z)
		horizontal = horizontal.move_toward(Vector3.ZERO, braking_deceleration * delta)
		motion.x = horizontal.x
		motion.z = horizontal.z
	return motion.limit_length(max_velocity)


func _limited_camera_angle(current: float, target: float, delta: float, limit: float) -> float:
	var followed := lerp_angle(current, target, _response_weight(delta, camera_response_time))
	var gap := wrapf(target - followed, -PI, PI)
	return target - clampf(gap, -maxf(limit, 0.0), maxf(limit, 0.0))


func _update_camera(delta: float) -> void:
	if is_grounded:
		# Direct mouse look keeps WASD aligned with the visible camera; flight
		# retains its separate lagged follow behavior below.
		camera_pivot.rotation = Vector3(ground_camera_pitch, ground_camera_yaw,
			lerp_angle(camera_pivot.rotation.z, 0.0, _response_weight(delta, 0.1)))
		return
	# Use the commanded heading at every speed. Velocity already lags during
	# turns; following it here would add that lag to the camera's own smoothing.
	var target_yaw := yaw
	var target_pitch := pitch
	# Follow a fraction of the bird's mouse aim, keeping its turn visible.
	var aim_follow := clampf(camera_aim_follow, 0.0, 0.95)
	target_yaw += aim_yaw * aim_follow
	target_pitch += aim_pitch * aim_follow
	var camera_rotation := camera_pivot.rotation
	camera_rotation.y = _limited_camera_angle(camera_rotation.y, target_yaw, delta, maximum_camera_yaw_lag)
	camera_rotation.x = _limited_camera_angle(camera_rotation.x, target_pitch, delta, maximum_camera_pitch_lag)
	var target_roll := roll / maxf(maximum_roll, 0.001) * maximum_camera_roll
	camera_rotation.z = lerp_angle(camera_rotation.z, target_roll, _response_weight(delta, camera_response_time))
	camera_pivot.rotation = camera_rotation


func _process(delta: float) -> void:
	cursor_debug_label.visible = show_cursor_debug
	cursor_debug_label.text = "Walking | WASD: move | Mouse: look | Space: take off" if is_grounded else \
		"Flying | Cursor bias: (%.2f, %.2f) | strength: %.2f" % [cursor_bias.x, cursor_bias.y, cursor_bias.length()]
	# Aim and bank are local offsets, independent of the accumulated heading.
	visuals.basis = Basis.from_euler(Vector3(pitch, yaw, 0.0)) * Basis.from_euler(Vector3(aim_pitch, aim_yaw, roll))
	_update_camera(delta)
