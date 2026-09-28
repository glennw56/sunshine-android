extends Node3D
class_name LogoSun
## Sunshine bakery logo as the daytime sun: circular girl-in-hat disc that
## travels an east→west sky arc. Not a generic yellow ball.

const LOGO := "res://assets/branding/sunshine-logo-girl.jpg"
const ARC_RADIUS := 44.0
const ARC_HEIGHT := 36.0
const NOON_Z := -28.0
const PERIOD_SEC := 96.0

var _phase: float = 0.38
var _light: DirectionalLight3D
var _billboard: Node3D


func _ready() -> void:
	add_to_group("logo_sun")
	_build()
	_place()


func _build() -> void:
	_billboard = Node3D.new()
	_billboard.name = "Billboard"
	add_child(_billboard)
	var disc := Sprite3D.new()
	disc.name = "LogoDisc"
	if ResourceLoader.exists(LOGO):
		disc.texture = load(LOGO)
	disc.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	disc.pixel_size = 0.0105
	disc.shaded = false
	disc.double_sided = true
	disc.alpha_cut = Sprite3D.ALPHA_CUT_DISABLED
	disc.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disc.material_override = _logo_mat()
	_billboard.add_child(disc)
	_light = DirectionalLight3D.new()
	_light.name = "SunLight"
	_light.light_color = Color("fff1d0")
	_light.light_energy = 1.18
	_light.shadow_enabled = true
	_light.shadow_opacity = 0.7
	_light.shadow_blur = 1.2
	_light.directional_shadow_max_distance = 90.0
	add_child(_light)


func _logo_mat() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, specular_disabled, depth_draw_never;
uniform sampler2D logo : source_color;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	if (dot(p, p) > 0.985) {
		discard;
	}
	vec4 c = texture(logo, UV);
	ALBEDO = c.rgb * 1.08;
	EMISSION = c.rgb * 0.55;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	if ResourceLoader.exists(LOGO):
		mat.set_shader_parameter("logo", load(LOGO))
	return mat


func _process(delta: float) -> void:
	_phase = fposmod(_phase + delta / PERIOD_SEC, 1.0)
	_place()


func set_phase(t: float) -> void:
	_phase = fposmod(t, 1.0)
	_place()


func _place() -> void:
	var ang := _phase * PI
	var lift := sin(ang)
	global_position = Vector3(
		cos(ang) * ARC_RADIUS,
		3.2 + lift * ARC_HEIGHT,
		NOON_Z - lift * 8.0
	)
	if _light:
		_light.look_at(Vector3(0.0, 1.0, 0.0), Vector3.UP)
		_light.light_energy = 0.42 + lift * 0.92
		_light.light_color = Color("fff1d0").lerp(Color("ffe0a0"), 1.0 - lift)
