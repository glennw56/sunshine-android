extends Node3D
class_name DiscoParty
## Room-wide patio party. The server sends the end time. A new hit refreshes
## that clock to 20s from the hit; it does not stack on top of time left.
## Visuals, the host, and the loop are procedural. No sampled music.

const DISCO_SEC := 20.0
const BLUSH := Color("e8b4b8")
## Open grass between the center bistro (z ≈ −0.45) and the north picnic
## (z ≈ −4.7). Same seating band as the bullseye at x ≈ 4.35, z ≈ −2.4.
const ZONE := Vector3(0.15, 0.0, -2.55)
const BPM := 116.0
## Patio_Island tops out near y 0.07 and the walk collider near y 0.10.
## A floor at y 0.03 sits inside that slab, so the blush pad never shows.
const DECK_CLEAR := 0.12

const COLORS: Array[Color] = [
	Color("ff2d95"),
	Color("39ff14"),
	Color("00e5ff"),
	Color("ffe600"),
	BLUSH,
	Color("b44dff"),
]

## Original two-bar phrase. Pentatonic, not a recording of an existing song.
const _LEAD_HZ: Array[float] = [
	523.25, 659.25, 783.99, 659.25, 880.00, 783.99, 659.25, 523.25,
]
## Octave bounce under that phrase. Roots walk C–A–F–G across the two bars.
const _BASS_HZ: Array[float] = [
	65.41, 130.81, 98.00, 130.81, 55.00, 110.00, 87.31, 98.00,
]

var _until: float = 0.0
var _spin: float = 0.0
var _zone: Node3D
var _rig: Node3D
var _glitter: Node3D
var _floor: Node3D
var _wash: ColorRect
var _host: Node3D
var _host_larm: Node3D
var _host_rarm: Node3D
var _host_lleg: Node3D
var _host_rleg: Node3D
var _sign: Label3D
var _music: AudioStreamPlayer3D
var _music_gain: float = 0.0
var _music_target: float = 0.0
var _sample_i: int = 0
var _music_starts: int = 0
var _bass_phase: float = 0.0
var _lead_phase: float = 0.0
var _orbs: Array[MeshInstance3D] = []
var _beams: Array[MeshInstance3D] = []
var _tiles: Array[MeshInstance3D] = []
var _lamps: Array[OmniLight3D] = []


func _ready() -> void:
	add_to_group("disco_party")
	name = "DiscoParty"
	_build()
	_set_shown(false)


func apply_until(until_unix: float) -> void:
	if until_unix <= Time.get_unix_time_from_system():
		return
	_until = maxf(_until, until_unix)
	_set_shown(true)


func party_on() -> bool:
	return _until > Time.get_unix_time_from_system()


func zone_origin() -> Vector3:
	return ZONE


func music_samples() -> int:
	return _sample_i


func music_starts() -> int:
	return _music_starts


func _process(delta: float) -> void:
	if not party_on():
		if _wash and _wash.visible:
			_set_shown(false)
		_fade_music(delta)
		return
	_spin += delta
	_animate()
	_sync_dancers(true)
	_fade_music(delta)
	_fill_music()


func _set_shown(on: bool) -> void:
	if _rig:
		_rig.visible = on
	if _glitter:
		_glitter.visible = on
	if _floor:
		_floor.visible = on
	if _host:
		_host.visible = on
	if _sign:
		_sign.visible = on
	if _wash:
		_wash.visible = on
	for lamp in _lamps:
		lamp.visible = on
	_sync_dancers(on)
	_set_music(on)


func _animate() -> void:
	var pulse := 0.5 + 0.5 * sin(_spin * 7.0)
	if _rig:
		_rig.rotation.y = _spin * 1.15
	if _glitter:
		_glitter.rotation.y = -_spin * 2.1
	for i in _orbs.size():
		var orb := _orbs[i]
		var bob := 0.28 * sin(_spin * 3.2 + float(i))
		orb.position.y = bob
		var s := 0.82 + 0.42 * sin(_spin * 5.0 + float(i) * 0.7)
		orb.scale = Vector3(s, s, s)
	for i in _beams.size():
		var beam := _beams[i]
		beam.rotation.z = sin(_spin * 2.6 + float(i) * 0.9) * 0.72
		beam.rotation.x = 0.42 + sin(_spin * 1.8 + float(i)) * 0.38
		var mat := beam.material_override as StandardMaterial3D
		if mat:
			var tint := COLORS[(i + int(_spin * 3.0)) % COLORS.size()]
			tint.a = 0.82
			mat.albedo_color = tint
	for i in _tiles.size():
		var tile := _tiles[i]
		var mat := tile.material_override as StandardMaterial3D
		if mat:
			var tint := COLORS[(i + int(_spin * 4.0)) % COLORS.size()]
			tint.a = 0.62 + 0.2 * pulse
			mat.albedo_color = tint
	for i in _lamps.size():
		var lamp := _lamps[i]
		lamp.light_color = COLORS[(i + int(_spin * 2.0)) % COLORS.size()]
		lamp.light_energy = 1.4 + 1.6 * pulse
	if _wash:
		var tint := Color.from_hsv(fposmod(_spin * 0.35, 1.0), 0.85, 1.0)
		tint = tint.lerp(BLUSH, 0.22)
		tint.a = 0.26 + 0.12 * pulse
		_wash.color = tint
	_dance_host()


func _dance_host() -> void:
	if _host == null or not _host.visible:
		return
	var beat := _spin * 6.6
	_host.position.y = DECK_CLEAR + absf(sin(beat)) * 0.16
	_host.rotation.y = PI + sin(_spin * 2.2) * 0.6
	if _host_larm:
		_host_larm.rotation.x = -1.15 + sin(beat) * 0.48
	if _host_rarm:
		_host_rarm.rotation.x = -1.15 + sin(beat + PI) * 0.48
	if _host_lleg:
		_host_lleg.rotation.x = sin(beat) * 0.42
	if _host_rleg:
		_host_rleg.rotation.x = sin(beat + PI) * 0.42


func _sync_dancers(on: bool) -> void:
	var tree := get_tree()
	if tree == null:
		return
	for baker in tree.get_nodes_in_group("local_baker"):
		_mark_avatar(baker, on)
	for baker in tree.get_nodes_in_group("remote_baker"):
		_mark_avatar(baker, on)


func _mark_avatar(baker: Node, on: bool) -> void:
	var avatar := baker.get_node_or_null("Avatar")
	if avatar == null:
		for child in baker.get_children():
			if child.has_method("set_dancing"):
				avatar = child
				break
	if avatar and avatar.has_method("set_dancing"):
		avatar.set_dancing(on)


func _set_music(on: bool) -> void:
	if _music == null:
		return
	if on:
		if not _music.playing:
			_sample_i = 0
			_bass_phase = 0.0
			_lead_phase = 0.0
			_music.play()
			_music_starts += 1
		if _music_gain < 0.4:
			_music_gain = 0.4
		_music_target = 1.0
		return
	_music_target = 0.0


func _fade_music(delta: float) -> void:
	if _music == null:
		return
	_music_gain = lerpf(_music_gain, _music_target, clampf(delta * 5.0, 0.0, 1.0))
	if _music_target <= 0.0 and _music_gain <= 0.04:
		_music_gain = 0.0
		if _music.playing:
			_music.stop()
		_music.volume_db = -80.0
		return
	_music.volume_db = linear_to_db(maxf(_music_gain, 0.001)) - 3.0


func _fill_music() -> void:
	if _music == null or not _music.playing:
		return
	var playback := _music.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	var gen := _music.stream as AudioStreamGenerator
	if gen == null:
		return
	var rate := maxf(gen.mix_rate, 1.0)
	var beat_samples := rate * 60.0 / BPM
	var frames := playback.get_frames_available()
	for _i in frames:
		playback.push_frame(_sample_at(rate, beat_samples))
		_sample_i += 1


func _sample_at(rate: float, beat_samples: float) -> Vector2:
	var loop_samples := beat_samples * 8.0
	var loop_at := fposmod(float(_sample_i), loop_samples)
	var beat_idx := int(loop_at / beat_samples) % 8
	var into := fposmod(loop_at, beat_samples) / rate
	var beat_sec := beat_samples / rate
	var kick := _kick(into)
	var hat := _hat(into, beat_idx)
	var clap := _clap(into, beat_idx, beat_sec)
	var bass_hz := _BASS_HZ[beat_idx]
	_bass_phase = fposmod(_bass_phase + bass_hz / rate, 1.0)
	var bass_env := 0.55 + 0.45 * exp(-into * 7.0)
	var bass := sin(_bass_phase * TAU) * bass_env
	bass += sin(_bass_phase * TAU * 2.0) * 0.18 * bass_env
	var lead_hz := _LEAD_HZ[beat_idx]
	_lead_phase = fposmod(_lead_phase + lead_hz / rate, 1.0)
	var pluck := exp(-into * 5.2)
	var lead := sin(_lead_phase * TAU) * pluck
	lead += sin(_lead_phase * TAU * 2.0) * 0.22 * pluck
	var left := kick * 0.78 + bass * 0.34 + clap * 0.3 + hat * 0.1 + lead * 0.2
	var right := kick * 0.78 + bass * 0.34 + clap * 0.34 + hat * 0.16 + lead * 0.15
	return Vector2(_soft(left), _soft(right))


func _kick(into: float) -> float:
	var dur := 0.16
	if into >= dur:
		return 0.0
	var u := into / dur
	var env := (1.0 - u) * (1.0 - u)
	var freq := lerpf(168.0, 48.0, u)
	return sin(TAU * freq * into) * env


func _hat(into: float, beat_idx: int) -> float:
	## Closed hat on the downbeat, short open hat on the offbeat.
	var half := 0.5 * 60.0 / BPM
	if into < 0.02:
		return _noise(_sample_i + beat_idx) * (1.0 - into / 0.02) * 0.7
	var off := into - half
	if off >= 0.0 and off < 0.04:
		return _noise(_sample_i + beat_idx + 3) * (1.0 - off / 0.04)
	return 0.0


func _clap(into: float, beat_idx: int, beat_sec: float) -> float:
	if beat_idx % 2 == 0:
		return 0.0
	var dur := minf(0.09, beat_sec)
	if into >= dur:
		return 0.0
	var env := 1.0 - into / dur
	var n := _noise(_sample_i * 3 + 9)
	var snap := 1.0 if into < 0.012 else 0.65
	return n * env * snap


func _noise(n: int) -> float:
	var x := (n * 1103515245 + 12345) & 2147483647
	return float((x >> 8) & 65535) / 32767.0 - 1.0


func _soft(x: float) -> float:
	var y := x / (1.0 + absf(x) * 0.45)
	return clampf(y, -1.0, 1.0)


func _build() -> void:
	_zone = Node3D.new()
	_zone.name = "PartyZone"
	_zone.position = ZONE
	add_child(_zone)
	_rig = Node3D.new()
	_rig.name = "Lights"
	_rig.position = Vector3(0.0, 3.25, 0.0)
	_zone.add_child(_rig)
	_glitter = Node3D.new()
	_glitter.name = "Glitter"
	_rig.add_child(_glitter)
	for i in COLORS.size():
		var ang := float(i) / float(COLORS.size()) * TAU
		var orb := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.28
		ball.height = 0.56
		ball.radial_segments = 12
		ball.rings = 6
		orb.mesh = ball
		orb.material_override = _glow(COLORS[i])
		orb.position = Vector3(cos(ang) * 1.15, 0.0, sin(ang) * 1.15)
		_rig.add_child(orb)
		_orbs.append(orb)
		var beam := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.22, 3.15, 0.22)
		beam.mesh = box
		beam.position = Vector3(cos(ang) * 0.85, -1.5, sin(ang) * 0.85)
		beam.material_override = _glow(COLORS[i], true)
		_rig.add_child(beam)
		_beams.append(beam)
		var spark := MeshInstance3D.new()
		var speck := SphereMesh.new()
		speck.radius = 0.08
		speck.height = 0.16
		speck.radial_segments = 8
		speck.rings = 4
		spark.mesh = speck
		spark.material_override = _glow(COLORS[(i + 2) % COLORS.size()])
		spark.position = Vector3(cos(ang + 0.4) * 1.45, 0.35 * sin(ang), sin(ang + 0.4) * 1.45)
		_glitter.add_child(spark)
	var ball_mesh := SphereMesh.new()
	ball_mesh.radius = 0.34
	ball_mesh.height = 0.68
	ball_mesh.radial_segments = 16
	ball_mesh.rings = 8
	var mirror := MeshInstance3D.new()
	mirror.name = "MirrorBall"
	mirror.mesh = ball_mesh
	mirror.material_override = _glow(Color("fff6ea"))
	_rig.add_child(mirror)
	var hoop := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.05
	torus.outer_radius = 1.28
	torus.rings = 16
	torus.ring_segments = 8
	hoop.mesh = torus
	hoop.material_override = _glow(BLUSH)
	hoop.position = Vector3(0.0, -0.15, 0.0)
	_rig.add_child(hoop)
	for i in 2:
		var lamp := OmniLight3D.new()
		lamp.light_color = COLORS[i]
		lamp.light_energy = 1.8
		lamp.omni_range = 7.5
		lamp.shadow_enabled = false
		lamp.position = Vector3(cos(float(i) * PI) * 0.4, -0.4, sin(float(i) * PI) * 0.4)
		_rig.add_child(lamp)
		_lamps.append(lamp)
	_build_floor()
	_build_host()
	_build_sign()
	_build_music()
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	_wash = ColorRect.new()
	_wash.name = "DiscoWash"
	_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wash.color = Color(1, 0, 0.6, 0.22)
	_wash.visible = false
	layer.add_child(_wash)


func _build_floor() -> void:
	_floor = Node3D.new()
	_floor.name = "DanceFloor"
	_zone.add_child(_floor)
	var center := MeshInstance3D.new()
	center.name = "BlushCenter"
	var disc := CylinderMesh.new()
	disc.top_radius = 0.62
	disc.bottom_radius = 0.62
	disc.height = 0.03
	disc.radial_segments = 20
	center.mesh = disc
	center.position = Vector3(0.0, DECK_CLEAR, 0.0)
	var blush := BLUSH
	blush.a = 0.78
	center.material_override = _glow(blush, true)
	_floor.add_child(center)
	for i in 8:
		var tile := MeshInstance3D.new()
		var step := CylinderMesh.new()
		step.top_radius = 0.26
		step.bottom_radius = 0.26
		step.height = 0.025
		step.radial_segments = 12
		tile.mesh = step
		var ang := float(i) / 8.0 * TAU
		tile.position = Vector3(cos(ang) * 1.35, DECK_CLEAR - 0.008, sin(ang) * 1.35)
		var tint := COLORS[i % COLORS.size()]
		tint.a = 0.7
		tile.material_override = _glow(tint, true)
		_floor.add_child(tile)
		_tiles.append(tile)


func _build_host() -> void:
	_host = Node3D.new()
	_host.name = "HostDancer"
	_host.position = Vector3(0.42, 0.0, 0.28)
	_zone.add_child(_host)
	var skin := _glow(Color("f7d3b8"))
	var outfit := _glow(BLUSH)
	var wine := _glow(Color("6b2d3c"))
	var shoe := _glow(Color("2a1c18"))
	_sphere(_host, 0.16, outfit, Vector3(0, 0.62, 0))
	_sphere(_host, 0.13, skin, Vector3(0, 0.92, 0))
	_sphere(_host, 0.1, wine, Vector3(0, 1.0, -0.02), Vector3(1.15, 0.7, 1.1))
	_host_larm = Node3D.new()
	_host_larm.position = Vector3(-0.18, 0.7, 0)
	_host.add_child(_host_larm)
	_capsule(_host_larm, 0.035, 0.22, outfit, Vector3(0, -0.12, 0))
	_host_rarm = Node3D.new()
	_host_rarm.position = Vector3(0.18, 0.7, 0)
	_host.add_child(_host_rarm)
	_capsule(_host_rarm, 0.035, 0.22, outfit, Vector3(0, -0.12, 0))
	_host_lleg = Node3D.new()
	_host_lleg.position = Vector3(-0.07, 0.4, 0)
	_host.add_child(_host_lleg)
	_capsule(_host_lleg, 0.04, 0.24, wine, Vector3(0, -0.14, 0))
	_sphere(_host_lleg, 0.045, shoe, Vector3(0, -0.28, 0.02))
	_host_rleg = Node3D.new()
	_host_rleg.position = Vector3(0.07, 0.4, 0)
	_host.add_child(_host_rleg)
	_capsule(_host_rleg, 0.04, 0.24, wine, Vector3(0, -0.14, 0))
	_sphere(_host_rleg, 0.045, shoe, Vector3(0, -0.28, 0.02))


func _build_sign() -> void:
	var sign := Label3D.new()
	sign.name = "PartySign"
	sign.text = "Party"
	sign.font_size = 64
	sign.pixel_size = 0.004
	sign.position = Vector3(0.0, 3.85, 0.0)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.modulate = BLUSH
	sign.outline_size = 10
	sign.outline_modulate = Color("4a1c28")
	sign.visible = false
	_sign = sign
	_zone.add_child(sign)


func _build_music() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.35
	_music = AudioStreamPlayer3D.new()
	_music.name = "DiscoMusic"
	_music.stream = gen
	_music.volume_db = -80.0
	_music.unit_size = 14.0
	_music.max_distance = 42.0
	_music.position = Vector3(0.0, 1.5, 0.0)
	_zone.add_child(_music)


func _sphere(parent: Node3D, radius: float, mat: Material, pos: Vector3, scl := Vector3.ONE) -> void:
	var mi := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = radius
	ball.height = radius * 2.0
	ball.radial_segments = 10
	ball.rings = 6
	mi.mesh = ball
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)


func _capsule(parent: Node3D, radius: float, height: float, mat: Material, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = radius
	cap.height = height
	cap.radial_segments = 8
	cap.rings = 3
	mi.mesh = cap
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)


func _glow(color: Color, soft: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if soft:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat
