extends Control
## Square Loyalty. Balance is GameSave.loyalty_points from login / AccountClient.refresh().
## Explore pickup counters stay off this screen.

const BakeryTheme := preload("res://scripts/ui/bakery_theme.gd")
const CosContracts := preload("res://scripts/contracts/cos_contracts.gd")
const AvatarBodyScript := preload("res://scripts/explore/avatar_body.gd")

const JOIN_LINE := "Sign in / join loyalty to earn"
const HOW_IT_WORKS := (
	"Earn 1 point for every $1.00 you spend, before tax.\n\n"
	+ "100 points: a free Fruit Tea.\n\n"
	+ "200 points: $10.00 off the entire sale.\n\n"
	+ "Join from the sign-in screen. Keep “Join Sunshine’s Bakery loyalty / save your orders” checked."
)

var _avatar: AvatarBody
var _view: SubViewport
var _portrait: TextureRect

@onready var _points: Label = $Safe/Col/Scroll/Card/Pad/Col/Points
@onready var _track: LoyaltyTrack = $Safe/Col/Scroll/Card/Pad/Col/Track
@onready var _how_title: Label = $Safe/Col/Scroll/Card/Pad/Col/HowTitle
@onready var _how: Label = $Safe/Col/Scroll/Card/Pad/Col/HowBody
@onready var _join: Button = $Safe/Col/Scroll/Card/Pad/Col/Join
@onready var _back: Button = $Safe/Col/Header/Back
@onready var _title: Label = $Safe/Col/Header/Title


func _ready() -> void:
	BakeryTheme.apply(self)
	_style()
	_mount_avatar()
	_refresh_avatar()
	_paint()
	if not ProfileStore.avatar_changed.is_connected(_on_avatar_changed):
		ProfileStore.avatar_changed.connect(_on_avatar_changed)
	_sync_portrait()
	if AccountClient.is_logged_in():
		_refresh_balance()


func _style() -> void:
	var card := $Safe/Col/Scroll/Card as PanelContainer
	card.add_theme_stylebox_override("panel", _card_style())
	_title.add_theme_color_override("font_color", BakeryTheme.WINE)
	_title.add_theme_font_size_override("font_size", BakeryTheme.SIZE_HERO)
	_points.add_theme_color_override("font_color", BakeryTheme.WINE)
	_points.add_theme_font_size_override("font_size", BakeryTheme.SIZE_TITLE)
	_how_title.add_theme_color_override("font_color", BakeryTheme.WINE)
	_how_title.add_theme_font_size_override("font_size", BakeryTheme.SIZE_TITLE)
	_how.add_theme_color_override("font_color", BakeryTheme.INK)
	_how.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BODY)
	_how.text = HOW_IT_WORKS
	_back.theme_type_variation = "SecondaryButton"
	_back.custom_minimum_size = Vector2(128, 64)
	_back.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BUTTON)
	_back.pressed.connect(func(): AppConfig.go("res://scenes/main_menu.tscn"))
	_join.custom_minimum_size = Vector2(0, 72)
	_join.add_theme_font_size_override("font_size", BakeryTheme.SIZE_BUTTON)
	_join.text = "Sign in / join loyalty"
	if not _join.pressed.is_connected(_on_join):
		_join.pressed.connect(_on_join)


func _card_style() -> StyleBoxFlat:
	var style := BakeryTheme.card_style()
	style.set_corner_radius_all(28)
	style.border_color = Color(BakeryTheme.BLUSH, 0.95)
	style.set_border_width_all(2)
	style.content_margin_left = 8
	style.content_margin_top = 8
	style.content_margin_right = 8
	style.content_margin_bottom = 8
	return style


func _mount_avatar() -> void:
	## Same live chibi as Explore and the customize preview (AvatarBody + recipe).
	var host := $Safe/Col/Scroll/Card/Pad/Col/PreviewHost as VBoxContainer
	var frame := PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.add_theme_stylebox_override("panel", _preview_style())
	var world := SubViewport.new()
	world.name = "BakerView"
	world.size = Vector2i(640, 520)
	world.transparent_bg = false
	world.own_world_3d = true
	world.handle_input_locally = false
	world.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_view = world
	var root := Node3D.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("fff6ea")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("fff4ea")
	env.ambient_light_energy = 0.9
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	root.add_child(world_env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-34, 28, 0)
	key.light_energy = 1.15
	root.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-18, -150, 0)
	fill.light_energy = 0.4
	root.add_child(fill)
	var ground := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.72
	disc.bottom_radius = 0.72
	disc.height = 0.04
	ground.mesh = disc
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = BakeryTheme.BLUSH
	ground.material_override = gmat
	ground.position = Vector3(0, -0.02, 0)
	root.add_child(ground)
	var cam := Camera3D.new()
	cam.current = true
	cam.position = Vector3(0.42, 1.05, 2.35)
	cam.look_at_from_position(cam.position, Vector3(0, 0.72, 0))
	root.add_child(cam)
	_avatar = AvatarBodyScript.new()
	_avatar.name = "Avatar"
	_avatar.position = Vector3(0, 0, 0)
	_avatar.hide_nameplate()
	root.add_child(_avatar)
	world.add_child(root)
	host.add_child(world)
	var rect := TextureRect.new()
	rect.name = "Portrait"
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(0, 300)
	rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.add_child(rect)
	host.add_child(frame)
	_portrait = rect


func _sync_portrait() -> void:
	## Copy the live viewport after it draws. A SubViewportContainer clears its
	## texture during the parent draw on this GL path, so the still is what shows.
	for _i in 3:
		await RenderingServer.frame_post_draw
	if not is_inside_tree() or _view == null or _portrait == null:
		return
	var img := _view.get_texture().get_image()
	if img == null or img.get_width() < 2:
		return
	_portrait.texture = ImageTexture.create_from_image(img)


func _preview_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("fff6ea")
	style.border_color = BakeryTheme.BLUSH
	style.set_border_width_all(3)
	style.set_corner_radius_all(22)
	return style


func _recipe() -> Dictionary:
	var raw: Dictionary = GameSave.avatar_recipe
	if raw.is_empty():
		raw = ProfileStore.current_avatar()
	return CosContracts.sanitize_avatar(raw)


func _refresh_avatar() -> void:
	if _avatar == null:
		return
	_avatar.hide_nameplate()
	_avatar.rebuild(_recipe())


func _on_avatar_changed(_recipe_now: Dictionary) -> void:
	_refresh_avatar()
	_sync_portrait()


func _paint() -> void:
	var enrolled := GameSave.shows_loyalty_balance()
	if enrolled:
		var total := GameSave.loyalty_points
		_points.text = "1 point" if total == 1 else "%d points" % total
		_join.visible = false
	else:
		_points.text = JOIN_LINE
		_join.visible = true
	if _track:
		_track.set_balance(GameSave.loyalty_points if enrolled else 0, enrolled)


func _refresh_balance() -> void:
	await AccountClient.refresh()
	if is_inside_tree():
		_paint()


func _on_join() -> void:
	AccountClient.logout()
	AppConfig.go("res://scenes/account/login.tscn")
