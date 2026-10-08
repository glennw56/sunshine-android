extends Node3D
## Test-world moon. The bakery logo hangs in a fixed spot and a soft
## directional light points down from it. No shadow map, so phones stay light.

const LOGO := "res://assets/branding/sunshine-logo-disc.png"
const FALLBACK := "res://assets/branding/sunshine-logo-girl.jpg"
const MOON_GLB := "res://assets/explore/halloween/logo_moon.glb"
const Look := preload("res://scripts/explore/authored_look.gd")

var _billboard: Node3D


func _ready() -> void:
	name = "LogoMoon"
	add_to_group("logo_moon")
	global_position = Vector3(-6.0, 46.0, -32.0)
	_disc()
	var light := DirectionalLight3D.new()
	light.name = "MoonLight"
	light.light_color = Color("c9d7f2")
	light.light_energy = 0.55
	light.shadow_enabled = false
	add_child(light)
	light.look_at(Vector3(0.0, 1.2, 0.0), Vector3.UP)


func _process(_delta: float) -> void:
	if _billboard == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var from := _billboard.global_position
	var cam_p := cam.global_position
	_billboard.rotation.y = atan2(cam_p.x - from.x, cam_p.z - from.z)


func _disc() -> void:
	if not _attach_art():
		_sprite_disc()
	_halo()


func _attach_art() -> bool:
	if not ResourceLoader.exists(MOON_GLB):
		return false
	var art := Look.lift(MOON_GLB, "LogoMoonArt")
	if art == null:
		return false
	var disc := art.find_child("LogoDisc", true, false) as MeshInstance3D
	if disc == null:
		art.free()
		return false
	var path := LOGO if ResourceLoader.exists(LOGO) else FALLBACK
	disc.material_override = _glow_mat(path)
	_billboard = Node3D.new()
	_billboard.name = "Billboard"
	add_child(_billboard)
	_billboard.add_child(art)
	return true


func _sprite_disc() -> void:
	var disc := Sprite3D.new()
	disc.name = "LogoDisc"
	var path := LOGO if ResourceLoader.exists(LOGO) else FALLBACK
	if ResourceLoader.exists(path):
		disc.texture = load(path)
	disc.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	disc.pixel_size = 0.018
	disc.shaded = false
	disc.double_sided = true
	disc.alpha_cut = Sprite3D.ALPHA_CUT_DISABLED
	disc.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disc.modulate = Color(1.12, 1.14, 1.2)
	disc.material_override = _glow_mat(path)
	add_child(disc)


func _halo() -> void:
	var halo := Sprite3D.new()
	halo.name = "MoonHalo"
	var blank := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	blank.fill(Color.WHITE)
	halo.texture = ImageTexture.create_from_image(blank)
	halo.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	halo.pixel_size = 0.38
	halo.position = Vector3(0.0, 0.0, 0.4)
	halo.shaded = false
	halo.double_sided = true
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.material_override = _halo_mat()
	add_child(halo)


func _glow_mat(path: String) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, specular_disabled, depth_draw_never;
uniform sampler2D logo : source_color;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	if (dot(p, p) > 0.98) {
		discard;
	}
	vec4 c = texture(logo, UV);
	if (c.a < 0.2) {
		discard;
	}
	float luma = max(c.r, max(c.g, c.b));
	vec3 moon = vec3(0.62, 0.74, 0.98);
	vec3 mark = min(c.rgb * 1.35, vec3(1.0));
	ALBEDO = mix(moon, mark, smoothstep(0.08, 0.55, luma));
	EMISSION = ALBEDO * 0.2;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	if ResourceLoader.exists(path):
		mat.set_shader_parameter("logo", load(path))
	return mat


func _halo_mat() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, blend_add, depth_draw_never, specular_disabled;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = dot(p, p);
	if (d > 1.0) {
		discard;
	}
	float g = smoothstep(1.0, 0.2, d);
	ALBEDO = vec3(0.62, 0.74, 1.0) * g * 0.12;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	return mat
