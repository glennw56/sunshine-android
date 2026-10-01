extends VBoxContainer
## Player-maker portrait. Same SubViewport, camera, and AvatarBody as customize.
## The Explore player uses this same AvatarBody script. Do not fork a second mesh.

const AvatarBodyScript := preload("res://scripts/explore/avatar_body.gd")

var _avatar: AvatarBody
var _view: SubViewport


func _ready() -> void:
	if _view == null:
		_mount()


func show_recipe(raw: Dictionary, display_name: String = "") -> void:
	if _avatar == null:
		_mount()
	_avatar.rebuild(raw, display_name)
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
	cam.position = Vector3(0.42, 1.05, 2.35)
	cam.look_at_from_position(cam.position, Vector3(0, 0.72, 0))
	root.add_child(cam)
	_avatar = AvatarBodyScript.new()
	_avatar.name = "Avatar"
	_avatar.position = Vector3(0, 0, 0)
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
