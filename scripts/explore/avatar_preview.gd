extends VBoxContainer
## Player-maker portrait. Same SubViewport, camera, and AvatarBody as customize.
## The Explore player uses this same AvatarBody script. Do not fork a second mesh.

const AvatarBodyScript := preload("res://scripts/explore/avatar_body.gd")
## Face, eyes, and apron are local −Z. This camera sits on +Z, so a half-turn
## points that face at the viewer. Explore leaves the body at yaw 0 (player.gd).
const FACE_THE_CAMERA := PI

signal portrait_tapped

var _avatar: AvatarBody
var _view: SubViewport
var _cam: Camera3D
var _yaw := FACE_THE_CAMERA
var _spin := 0.0
var _dragging := false
var _drag_px := 0.0
const _YAW_PER_PX := 0.012
const _TAP_PX := 12.0
const _SPIN_CAP := 2.4


func _ready() -> void:
	if _view == null:
		_mount()


func show_recipe(raw: Dictionary, display_name: String = "") -> void:
	if _avatar == null:
		_mount()
	_avatar.rebuild(raw, display_name)
	_apply_yaw()
	if display_name.strip_edges() == "":
		_avatar.hide_nameplate()


func _mount() -> void:
	var world := SubViewport.new()
	world.name = "BakerView"
	world.size = Vector2i(560, 520)
	world.transparent_bg = true
	world.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var root := Node3D.new()
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-34, 28, 0)
	light.light_energy = 1.05
	root.add_child(light)
	var ground := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.7
	disc.bottom_radius = 0.7
	disc.height = 0.04
	ground.mesh = disc
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color("6db84a")
	ground.material_override = gmat
	ground.position = Vector3(0, -0.02, 0)
	root.add_child(ground)
	var cam := Camera3D.new()
	cam.name = "BakerCam"
	cam.position = Vector3(0.42, 1.05, 2.35)
	cam.look_at_from_position(cam.position, Vector3(0, 0.72, 0))
	root.add_child(cam)
	_cam = cam
	_avatar = AvatarBodyScript.new()
	_avatar.name = "Avatar"
	_avatar.position = Vector3(0, 0, 0)
	_face_camera()
	root.add_child(_avatar)
	world.add_child(root)
	add_child(world)
	var rect := TextureRect.new()
	rect.name = "Portrait"
	rect.texture = world.get_texture()
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.custom_minimum_size = Vector2(0, 300)
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	rect.gui_input.connect(_on_portrait_gui)
	add_child(rect)
	_view = world
	set_process(true)


func frame_baker(fill_ratio: float, look_y: float = 0.82, body_h: float = 1.75) -> void:
	## fill_ratio is how much of the frame height the baker should occupy.
	## Loyalty leaves the wider default camera. Customize asks for about 0.80.
	if _cam == null:
		_cam = find_child("BakerCam", true, false) as Camera3D
	if _cam == null:
		return
	var fill := clampf(fill_ratio, 0.35, 0.92)
	var fov := deg_to_rad(_cam.fov)
	var dist := (body_h / fill) * 0.5 / tan(fov * 0.5)
	var aim := Vector3(0.0, look_y, 0.0)
	var offset := Vector3(0.14, 0.04, 1.0).normalized() * dist
	_cam.position = aim + offset
	_cam.look_at(aim, Vector3.UP)


func _process(delta: float) -> void:
	if _dragging or absf(_spin) < 0.02:
		return
	_yaw += _spin * delta
	var keep := exp(-3.4 * delta)
	_spin *= keep
	_apply_yaw()


func _on_portrait_gui(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mouse := event as InputEventMouseButton
		if mouse.pressed:
			_dragging = true
			_drag_px = 0.0
			_spin = 0.0
		else:
			_dragging = false
			if _drag_px < _TAP_PX:
				portrait_tapped.emit()
		if get_viewport():
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		var dx := motion.relative.x
		_drag_px += absf(dx)
		var dyaw := -dx * _YAW_PER_PX
		_yaw += dyaw
		var dt := maxf(get_process_delta_time(), 0.001)
		_spin = clampf(dyaw / dt, -_SPIN_CAP, _SPIN_CAP)
		_apply_yaw()
		if get_viewport():
			get_viewport().set_input_as_handled()


func _apply_yaw() -> void:
	if _avatar:
		_avatar.rotation.y = _yaw


func _face_camera() -> void:
	_yaw = FACE_THE_CAMERA
	_spin = 0.0
	_apply_yaw()
