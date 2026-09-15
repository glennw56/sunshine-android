extends Node3D
class_name LogoSun
## Sunshine bakery logo as the daytime sun: circular girl-in-hat disc that
## travels an east→west sky arc. Not a generic yellow ball.

const LOGO := "res://assets/branding/sunshine-logo-girl.jpg"
const ARC_RADIUS := 44.0
const ARC_HEIGHT := 36.0
const NOON_Z := -28.0
const PERIOD_SEC := 96.0
const DISC_M := 9.5

var _phase: float = 0.38
var _light: DirectionalLight3D
var _disc: MeshInstance3D


func _ready() -> void:
	add_to_group("logo_sun")
	_build()
	_place()


func _build() -> void:
	var glow := MeshInstance3D.new()
	glow.name = "Glow"
	var glow_mesh := QuadMesh.new()
	glow_mesh.size = Vector2(DISC_M * 1.45, DISC_M * 1.45)
	glow.mesh = glow_mesh
	var glow_mat := StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.albedo_color = Color(1.0, 0.82, 0.42, 0.42)
	glow_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	glow_mat.no_depth_test = true
	glow.material_override = glow_mat
	glow.position = Vector3(0, 0, 0.15)
	add_child(glow)
	_disc = MeshInstance3D.new()
	_disc.name = "LogoDisc"
	var quad := QuadMesh.new()
	quad.size = Vector2(DISC_M, DISC_M)
	_disc.mesh = quad
	_disc.material_override = _logo_mat()
	add_child(_disc)
	var halo := OmniLight3D.new()
	halo.name = "Halo"
	halo.light_color = Color("fff1c4")
	halo.light_energy = 2.4
	halo.omni_range = 48.0
	halo.shadow_enabled = false
	add_child(halo)
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
render_mode unshaded, cull_disabled, shadows_disabled, specular_disabled;
uniform sampler2D logo : source_color, filter_linear;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(normalize(cross(
			normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)),
			vec3(0.0, 1.0, 0.0))), 0.0),
		MODELVIEW_MATRIX[3]);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	if (dot(p, p) > 0.98) {
		discard;
	}
	vec4 c = texture(logo, UV);
	ALBEDO = c.rgb * 1.12;
	EMISSION = c.rgb * 0.35;
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
