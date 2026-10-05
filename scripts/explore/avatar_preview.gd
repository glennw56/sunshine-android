extends VBoxContainer
## Player-maker portrait. Same SubViewport, camera, and AvatarBody as customize.
## The Explore player uses this same AvatarBody script. Do not fork a second mesh.

const AvatarBodyScript := preload("res://scripts/explore/avatar_body.gd")
## Face, eyes, and apron are local −Z. This camera sits on +Z, so a half-turn
## points that face at the viewer. Explore leaves the body at yaw 0 (player.gd).
const FACE_THE_CAMERA := PI

var _avatar: AvatarBody
var _view: SubViewport
var _cam: Camera3D


func _ready() -> void:
	if _view == null:
		_mount()


func show_recipe(raw: Dictionary, display_name: String = "") -> void:
	if _avatar == null:
		_mount()
	_avatar.rebuild(raw, display_name)
	_face_camera()
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
	add_child(rect)
	_view = world


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


func _face_camera() -> void:
	if _avatar:
		_avatar.rotation.y = FACE_THE_CAMERA
