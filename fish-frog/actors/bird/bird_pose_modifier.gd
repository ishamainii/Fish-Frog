extends SkeletonModifier3D
## Run procedural poses before IK, and sole alignment after IK.

var driver: Node
var feet_pass := false
var attachment_pass := false


func _process_modification() -> void:
	if not is_instance_valid(driver):
		return
	if attachment_pass:
		driver.lock_leg_translations()
	elif feet_pass:
		driver.align_feet()
	else:
		driver.apply_poses()
