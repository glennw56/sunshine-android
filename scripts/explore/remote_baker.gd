extends Node3D
## Other signed-in bakers on the hosted patio. Interpolated, never authoritative.

const AvatarBodyScript := preload("res://scripts/explore/avatar_body.gd")

var net_id: String = ""
var _avatar: AvatarBody
var _target: Vector3 = Vector3.ZERO
var _target_yaw: float = 0.0
var _recipe: Dictionary = {}


func setup(row: Dictionary) -> void:
	net_id = str(row.get("net_id", ""))
	name = "Remote_%s" % net_id
	_avatar = AvatarBodyScript.new()
	add_child(_avatar)
	apply_row(row, true)


func apply_row(row: Dictionary, snap: bool = false) -> void:
	_target = Vector3(float(row.get("x", 0.0)), float(row.get("y", 0.02)), float(row.get("z", 11.0)))
	_target_yaw = float(row.get("yaw", 0.0))
	if snap:
		global_position = _target
		rotation.y = _target_yaw
	var recipe: Variant = row.get("avatar", {})
	if recipe is Dictionary and not recipe.is_empty():
		if str(recipe) != str(_recipe):
			_recipe = recipe
			_avatar.rebuild(recipe, str(row.get("display_name", "Baker")))
	_avatar.set_nameplate(str(row.get("display_name", "Baker")))
	_avatar.set_moving(bool(row.get("moving", false)))


func play_throw() -> void:
	if _avatar:
		_avatar.play_throw()


func hand_position() -> Vector3:
	if _avatar and _avatar.hand_socket():
		return _avatar.hand_socket().global_position
	return global_position + Vector3(0, 0.78, 0)


func _process(delta: float) -> void:
	global_position = global_position.lerp(_target, clampf(delta * 12.0, 0.0, 1.0))
	rotation.y = lerp_angle(rotation.y, _target_yaw, clampf(delta * 10.0, 0.0, 1.0))
	if _avatar:
		var viewer := Vector3.ZERO
		var local := get_tree().get_first_node_in_group("local_baker") as Node3D
		if local:
			viewer = local.global_position
		_avatar.update_nameplate_for(viewer)
