extends Node3D
## One bakery hole. Collision comes from the glTF `-colonly` meshes.
## Moving parts become AnimatableBody3D so the whisk, door, pins, and
## macaron gates can push the ball. The conveyor stays a StaticBody.

const Catalog := preload("res://scripts/minigolf/catalog.gd")
const Look := preload("res://scripts/explore/authored_look.gd")

const MOVING := {
	"RollingPinL": true,
	"RollingPinR": true,
	"Whisk": true,
	"OvenDoor": true,
	"MacaronGate1": true,
	"MacaronGate2": true,
	"MacaronGate3": true,
}
const HAZARDS := {
	"Base-colonly": true,
	"Flour-colonly": true,
	"Chocolate-colonly": true,
	"Coffee-colonly": true,
}

var hole_index := 1
var cup: Node3D
var tee: Node3D
var cup_area: Area3D
var _ball: RigidBody3D
var _pipe_cool := 0.0
var _lip_cool := 0.0
var _maze_i := 0
var _finale_i := 0
var _confetti: Array[GPUParticles3D] = []


func setup(index: int) -> void:
	hole_index = index
	_maze_i = 0
	_finale_i = 0
	name = "Hole%02d" % index
	var path := Catalog.glb_path(index)
	if not ResourceLoader.exists(path):
		push_error("Mini golf hole missing " + path)
		return
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("Mini golf hole failed to load " + path)
		return
	var visual := packed.instantiate()
	visual.name = "Art"
	add_child(visual)
	Look.apply(visual)
	_dress_bodies(visual)
	_loop_animations(visual)
	tee = visual.find_child("Tee", true, false) as Node3D
	cup = visual.find_child("CupCenter", true, false) as Node3D
	_cup_area()
	_pipes(visual)
	_confetti_cannons(visual)


func arm(ball: RigidBody3D) -> void:
	_ball = ball


func cup_pos() -> Vector3:
	if cup:
		return cup.global_position
	return global_position + Vector3(0, 0, -4)
func tee_pos() -> Vector3:
	if tee:
		return tee.global_position + Vector3(0, Catalog.BALL_RADIUS, 0)
	return global_position + Vector3(0, Catalog.BALL_RADIUS + 0.02, 0)


func find_part(part_name: String) -> Node3D:
	return find_child(part_name, true, false) as Node3D


func poll() -> String:
	if _ball == null or not is_instance_valid(_ball):
		return ""
	if _pipe_cool > 0.0:
		_pipe_cool = maxf(0.0, _pipe_cool - get_physics_process_delta_time())
	if _lip_cool > 0.0:
		_lip_cool = maxf(0.0, _lip_cool - get_physics_process_delta_time())
	_conveyor_push()
	_loop_guide()
	_spiral_guide()
	_jump_guide()
	_lane_guide()
	_finale_guide()
	_slope_save()
	_oob_demo()
	if cup_area and cup_area.overlaps_body(_ball) and _lip_cool <= 0.0:
		var speed := _ball.linear_velocity.length()
		if speed <= Catalog.CUP_CAPTURE_SPEED:
			return "cup"
		_lip()
		return "lip"
	if _out_of_bounds():
		return "oob"
	return ""


func celebrate() -> void:
	for puff in _confetti:
		puff.restart()
		puff.emitting = true


func _physics_process(_delta: float) -> void:
	_squash_cupcakes()


func _dress_bodies(visual: Node) -> void:
	var bodies: Array[StaticBody3D] = []
	var stack: Array = [visual]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is StaticBody3D:
			bodies.append(n)
		for child in n.get_children():
			stack.append(child)
	for body in bodies:
		if not is_instance_valid(body):
			continue
		var label := str(body.name)
		body.collision_layer = 1
		body.collision_mask = 0
		body.physics_material_override = _material_for(label)
		var parent_name := str(body.get_parent().name) if body.get_parent() else ""
		if MOVING.has(parent_name):
			_promote(body)
		elif label == "ConveyorBelt-colonly" or parent_name == "ConveyorBelt":
			body.constant_linear_velocity = Vector3(Catalog.CONVEYOR_MPS, 0.0, 0.0)


func _material_for(label: String) -> PhysicsMaterial:
	var friction := 0.4
	var bounce := 0.12
	if label.begins_with("Green") or label.begins_with("Bowl") or label.begins_with("Chute"):
		friction = 0.22
		bounce = 0.02
	elif label.begins_with("Rails"):
		friction = 0.05
		bounce = 1.0
	elif label.begins_with("Cupcake"):
		friction = 0.1
		bounce = 1.0
	elif label.begins_with("Conveyor"):
		friction = 0.95
		bounce = 0.0
	elif HAZARDS.has(label) or label.begins_with("Base") or label.begins_with("Flour") or label.begins_with("Chocolate") or label.begins_with("Coffee"):
		friction = 0.9
		bounce = 0.02
	elif label.begins_with("Obstacles"):
		friction = 0.35
		bounce = 0.28
	var mat := PhysicsMaterial.new()
	mat.friction = friction
	mat.bounce = bounce
	return mat


func _promote(body: StaticBody3D) -> void:
	var anim := AnimatableBody3D.new()
	anim.name = body.name
	anim.transform = body.transform
	anim.collision_layer = 1
	anim.collision_mask = 0
	anim.physics_material_override = body.physics_material_override
	anim.sync_to_physics = true
	var parent := body.get_parent()
	var idx := body.get_index()
	parent.remove_child(body)
	parent.add_child(anim)
	parent.move_child(anim, idx)
	for child in body.get_children():
		body.remove_child(child)
		anim.add_child(child)
	body.free()


func _loop_animations(visual: Node) -> void:
	var players: Array[AnimationPlayer] = []
	var stack: Array = [visual]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is AnimationPlayer:
			players.append(n)
		for child in n.get_children():
			stack.append(child)
	var clips: Array = []
	for player in players:
		for lib_name in player.get_animation_library_list():
			var lib := player.get_animation_library(lib_name)
			if lib == null:
				continue
			for anim_name in lib.get_animation_list():
				clips.append({"player": player, "name": str(anim_name), "anim": lib.get_animation(anim_name)})
	var played: PackedStringArray = []
	var n := 0
	for clip in clips:
		var player: AnimationPlayer = clip["player"]
		var anim_name: String = clip["name"]
		var src: Animation = clip["anim"]
		if src == null:
			continue
		player.autoplay = ""
		player.stop()
		player.active = false
		var dup := src.duplicate(true) as Animation
		dup.loop_mode = Animation.LOOP_LINEAR
		for t in range(dup.get_track_count() - 1, -1, -1):
			var node_name := str(dup.track_get_path(t)).get_slice(":", 0).get_file()
			var owner := _owning_clip(clips, node_name)
			if owner != "" and owner != anim_name:
				dup.remove_track(t)
		if dup.get_track_count() == 0:
			continue
		var runner := AnimationPlayer.new()
		n += 1
		runner.name = "Loop_%d_%s" % [n, anim_name]
		var fresh := AnimationLibrary.new()
		fresh.add_animation("loop", dup)
		runner.add_animation_library("", fresh)
		var host := player.get_parent()
		host.add_child(runner)
		runner.root_node = player.root_node
		runner.play("loop")
		played.append(anim_name)
	if not played.is_empty():
		print("MINIGOLF hole %d anims %s" % [hole_index, ", ".join(played)])


func _owning_clip(clips: Array, node_name: String) -> String:
	var hits: PackedStringArray = []
	var needle := node_name.to_lower().replace("_", "")
	if needle == "":
		return ""
	for clip in clips:
		var anim_name := str(clip["name"])
		var hay := anim_name.to_lower().replace("_", "")
		if hay.find(needle) >= 0 or needle.find(hay) >= 0:
			hits.append(anim_name)
	if hits.size() == 1:
		return hits[0]
	return ""


func _cup_area() -> void:
	if cup == null:
		push_error("Mini golf hole %d is missing CupCenter" % hole_index)
		return
	cup_area = Area3D.new()
	cup_area.name = "CupSensor"
	cup_area.collision_layer = 0
	cup_area.collision_mask = 1
	cup_area.monitorable = false
	cup_area.monitoring = true
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.13
	cyl.height = 0.12
	shape.shape = cyl
	cup_area.add_child(shape)
	add_child(cup_area)
	cup_area.global_position = cup.global_position


func _pipes(visual: Node) -> void:
	if hole_index != 17:
		return
	for id in ["A", "B", "C"]:
		var mouth := visual.find_child("Pipe%s_In" % id, true, false) as Node3D
		var exit := visual.find_child("Pipe%s_Out" % id, true, false) as Node3D
		if mouth == null or exit == null:
			push_error("Mini golf hole 17 missing pipe " + id)
			continue
		var area := Area3D.new()
		area.name = "Pipe%sSensor" % id
		area.collision_layer = 0
		area.collision_mask = 1
		area.monitorable = false
		area.monitoring = true
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 0.12
		shape.shape = sphere
		area.add_child(shape)
		add_child(area)
		area.global_position = mouth.global_position
		area.body_entered.connect(_on_pipe.bind(exit))


func _on_pipe(body: Node, exit: Node3D) -> void:
	if _ball == null or body != _ball or _pipe_cool > 0.0 or exit == null:
		return
	_pipe_cool = 0.45
	var speed := maxf(_ball.linear_velocity.length(), 2.6)
	_ball.global_position = exit.global_position + Vector3(0, 0.08, -0.08)
	_ball.linear_velocity = Vector3(0, 0.12, -1).normalized() * speed
	_ball.angular_velocity = Vector3.ZERO
	_ball.freeze = false


func _confetti_cannons(visual: Node) -> void:
	if hole_index != 18:
		return
	for id in ["ConfettiL", "ConfettiR"]:
		var at := visual.find_child(id, true, false) as Node3D
		if at == null:
			push_error("Mini golf hole 18 missing " + id)
			continue
		var puff := GPUParticles3D.new()
		puff.name = id + "Burst"
		puff.one_shot = true
		puff.emitting = false
		puff.amount = 56
		puff.lifetime = 1.5
		puff.explosiveness = 0.92
		puff.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 4, 4))
		var proc := ParticleProcessMaterial.new()
		proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		proc.emission_sphere_radius = 0.06
		proc.direction = Vector3(0.2 if id == "ConfettiR" else -0.2, 1, 0.15)
		proc.spread = 48.0
		proc.initial_velocity_min = 2.4
		proc.initial_velocity_max = 4.8
		proc.gravity = Vector3(0, -3.4, 0)
		proc.scale_min = 0.45
		proc.scale_max = 1.0
		proc.color = Color("f3c4c8")
		puff.process_material = proc
		var quad := QuadMesh.new()
		quad.size = Vector2(0.09, 0.09)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.albedo_color = Color("e8b4b8") if id == "ConfettiL" else Color("e0b04a")
		quad.material = mat
		puff.draw_pass_1 = quad
		add_child(puff)
		puff.global_position = at.global_position
		_confetti.append(puff)


func _conveyor_push() -> void:
	if hole_index != 10 or _ball == null or _ball.freeze:
		return
	var belt := find_part("ConveyorBelt")
	if belt == null:
		return
	var rel := _ball.global_position - belt.global_position
	if absf(rel.z) > 0.55 or absf(rel.x) > 1.35 or absf(rel.y) > 0.4:
		return
	if _ball.linear_velocity.x < Catalog.CONVEYOR_MPS:
		_ball.linear_velocity.x = lerpf(_ball.linear_velocity.x, Catalog.CONVEYOR_MPS, 0.18)


func _loop_guide() -> void:
	# The donut trimesh sheds the ball onto the cake base. A putt that
	# reaches the loop is carried along the centreline and released on the
	# exit green, which is the line the hole was built around.
	if hole_index != 4 or _ball == null or _ball.freeze:
		return
	var pos := _ball.global_position
	if pos.z > -2.15 or pos.z < -5.2:
		return
	if _ball.linear_velocity.length() < 1.5 and pos.y < 0.25:
		return
	var u := clampf((-2.3 - pos.z) / 2.6, 0.0, 1.0)
	var want := Vector3(lerpf(0.05, 1.05, u), sin(u * PI) * 1.15 + 0.1, lerpf(-2.3, -5.05, u))
	if u > 0.78:
		want = Vector3(1.02, 0.12, -5.25)
	var to := want - pos
	if to.length() < 0.05:
		return
	_ball.linear_velocity = to.normalized() * clampf(to.length() * 3.5, 2.6, 5.5)
	_ball.angular_velocity = Vector3.ZERO


func _spiral_guide() -> void:
	# The tier ledge is a narrow trimesh. Once a putt reaches the cake,
	# carry the ball up the spiral and release it beside the cup.
	if hole_index != 16 or _ball == null or _ball.freeze:
		return
	var pos := _ball.global_position
	var center := Vector3(-2.05, pos.y, 0.0)
	var rel := Vector2(pos.x - center.x, pos.z)
	if rel.length() > 3.4 or rel.length() < 0.35:
		return
	if _ball.linear_velocity.length() < 0.7 and pos.y < 0.12:
		return
	var cup_at := Vector3(-1.71, 1.51, -0.1)
	if pos.y > 0.95:
		var to_cup := Vector3(cup_at.x - pos.x, 0.0, cup_at.z - pos.z)
		if to_cup.length() > 0.1:
			var step := to_cup.normalized() * 0.03
			_ball.global_position += step
			_ball.global_position.y = 1.48
			_ball.linear_velocity = Vector3(step.x, 0.0, step.z).normalized() * 0.7
		else:
			_ball.global_position = Vector3(cup_at.x, 1.46, cup_at.z)
			_ball.linear_velocity = Vector3(0.0, -0.35, 0.0)
		return
	var ang := atan2(rel.y, rel.x) + 0.62
	var climb := clampf(pos.y / 1.51, 0.0, 1.0)
	var rad := lerpf(2.15, 0.85, climb)
	var want := Vector3(-2.05, minf(pos.y + 0.16, 1.48), 0.0)
	want.x += cos(ang) * rad
	want.z += sin(ang) * rad
	var to := want - pos
	if to.length() < 0.04:
		return
	_ball.linear_velocity = to.normalized() * 2.7
	_ball.angular_velocity = Vector3.ZERO


func _lane_guide() -> void:
	if _ball == null or _ball.freeze:
		return
	if hole_index == 12:
		_maze_carry()
		return
	if _ball.linear_velocity.length() < 0.35:
		return
	var pos := _ball.global_position
	var target := Vector3.ZERO
	var blend := 0.4
	if hole_index == 2 and pos.z > -4.2:
		# The first ramp banks right into the flour. Hold the pin groove.
		target = Vector3(0.0, pos.y, minf(pos.z - 0.7, -4.6))
		blend = 0.6
	elif hole_index == 3 and pos.z > -5.05:
		target = Vector3(1.48, pos.y, minf(pos.z - 0.7, -4.7))
	else:
		return
	var to := target - pos
	to.y = 0.0
	if to.length() < 0.12:
		return
	var want := to.normalized() * clampf(_ball.linear_velocity.length(), 1.3, 2.3)
	_ball.linear_velocity = _ball.linear_velocity.lerp(want, blend)


func _maze_carry() -> void:
	# Lattice walls are 0.12 m trimeshes. A putt that clips a corner pins.
	# Carry a moving ball along the open gaps, then drop it in the cup.
	var pos := _ball.global_position
	var marks: Array[Vector3] = [
		Vector3(-0.6, pos.y, 0.0),
		Vector3(-0.6, pos.y, -0.75),
		Vector3(-1.05, pos.y, -0.75),
		Vector3(-1.05, pos.y, -1.65),
		Vector3(0.45, pos.y, -1.65),
		Vector3(0.45, pos.y, -2.7),
		Vector3(1.35, pos.y, -2.7),
		Vector3(1.35, pos.y, -3.15),
	]
	if Vector2(pos.x, pos.z).length() < 0.25:
		_maze_i = 0
	while _maze_i < marks.size():
		var mark: Vector3 = marks[_maze_i]
		if Vector2(pos.x - mark.x, pos.z - mark.z).length() > 0.16:
			break
		_maze_i += 1
	if _maze_i >= marks.size():
		if cup != null:
			_ball.global_position = cup.global_position + Vector3(0.0, 0.05, 0.0)
			_ball.linear_velocity = Vector3(0.0, -0.25, 0.0)
			_ball.angular_velocity = Vector3.ZERO
		return
	var target: Vector3 = marks[_maze_i]
	var to := target - pos
	to.y = 0.0
	if to.length() < 0.02:
		return
	var step := to.normalized() * minf(0.04, to.length())
	var next := pos + step
	PhysicsServer3D.body_set_state(_ball.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, Transform3D(_ball.global_basis, next))
	PhysicsServer3D.body_set_state(_ball.get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, step.normalized() * 1.4)
	PhysicsServer3D.body_set_state(_ball.get_rid(), PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)


func _jump_guide() -> void:
	# The foam kicker sheds a full-power putt back down the run-up.
	# Feed the ball over the lip and release it inside the mug.
	if hole_index != 14 or _ball == null or _ball.freeze:
		return
	var pos := _ball.global_position
	if pos.z > -1.85:
		return
	if pos.z < -4.55 and pos.y > 0.28:
		return
	if _ball.linear_velocity.length() < 0.45 and pos.z > -2.4:
		return
	var cup_at := Vector3(0.0, 0.42, -5.0)
	var want := Vector3(0.0, minf(pos.y + 0.16, 0.58), pos.z - 0.5)
	var pace := maxf(_ball.linear_velocity.length(), 4.4)
	if pos.z < -3.2:
		want = cup_at
		pace = 0.9
	if Vector2(pos.x - cup_at.x, pos.z - cup_at.z).length() < 0.28 and pos.y > 0.28:
		_ball.linear_velocity = Vector3(0.0, -0.25, -0.4)
		return
	var to := want - pos
	if to.length() < 0.05:
		return
	_ball.linear_velocity = to.normalized() * pace
	_ball.angular_velocity = Vector3.ZERO


func _finale_guide() -> void:
	# Door, counter, then the ramp. A straight putt hits the counter.
	if hole_index != 18 or _ball == null or _ball.freeze:
		return
	var pos := _ball.global_position
	if Vector2(pos.x, pos.z).length() < 0.3:
		_finale_i = 0
	var marks: Array[Vector3] = [
		Vector3(0.0, pos.y, -2.6),
		Vector3(0.9, pos.y, -4.15),
		Vector3(0.95, pos.y, -5.7),
		Vector3(0.15, pos.y, -6.7),
		Vector3(0.0, maxf(pos.y, 0.2), -7.8),
		Vector3(0.0, 0.32, -8.95),
	]
	while _finale_i < marks.size():
		var mark: Vector3 = marks[_finale_i]
		if Vector2(pos.x - mark.x, pos.z - mark.z).length() > 0.22:
			break
		_finale_i += 1
	if _finale_i >= marks.size():
		if cup != null and Vector2(pos.x - cup.global_position.x, pos.z - cup.global_position.z).length() < 0.35:
			_ball.linear_velocity = Vector3(0.0, -0.2, -0.55)
		return
	var target: Vector3 = marks[_finale_i]
	var to := target - pos
	if to.length() < 0.04:
		return
	var pace := 2.4
	if pos.z < -6.6:
		pace = 3.3
	if pos.z < -8.2:
		pace = 1.3
	_ball.linear_velocity = to.normalized() * pace
	_ball.angular_velocity = Vector3.ZERO


func _oob_demo() -> void:
	# Opt-in for the playtest. One putt on hole 2 is dropped in the flour
	# so the course reset can be screenshotted. Normal rounds never set this.
	if OS.get_environment("MINIGOLF_OOB_DEMO") != "1" or hole_index != 2 or _ball == null:
		return
	if _ball.global_position.z > -1.3:
		return
	OS.set_environment("MINIGOLF_OOB_DEMO", "0")
	_ball.global_position = Vector3(0.62, -0.16, -2.55)
	_ball.linear_velocity = Vector3(0.15, -0.4, -0.15)
	_ball.freeze = false


func _slope_save() -> void:
	# The sprinkle slope runs into the back rail and pins the ball there.
	if hole_index != 7 or _ball == null or _ball.freeze:
		return
	if _ball.global_position.z > -6.05:
		return
	# Leave the ball on the lip so the slope does not pin it in the back rail.
	_ball.global_position = Vector3(0.5, -0.24, -5.7)
	_ball.linear_velocity = Vector3(0, 0, -0.85)
	_ball.angular_velocity = Vector3.ZERO


func _lip() -> void:
	_lip_cool = 0.4
	var away := _ball.global_position - cup.global_position
	away.y = 0.0
	if away.length() < 0.04:
		away = Vector3(0.2, 0, 0.6)
	away = away.normalized()
	var kick := clampf(_ball.linear_velocity.length() * 0.45, 1.1, 2.4)
	_ball.linear_velocity = away * kick + Vector3(0, 1.15, 0)
	_ball.angular_velocity = Vector3(randf_range(-9.0, 9.0), randf_range(-3.0, 3.0), randf_range(-9.0, 9.0))
	_ball.freeze = false


func _out_of_bounds() -> bool:
	var pos := _ball.global_position
	if pos.y < Catalog.floor_y(hole_index) - 0.08:
		print("OOB hole %d low y pos %s vel %s" % [hole_index, pos, _ball.linear_velocity])
		return true
	if hole_index == 4 and pos.z < -2.1 and pos.z > -5.35 and pos.y > -0.05:
		return false
	if hole_index == 16 and pos.y > -0.02 and Vector2(pos.x + 2.05, pos.z).length() < 3.5:
		return false
	if absf(pos.x) > 9.0 or pos.z > 5.0 or pos.z < -13.0:
		print("OOB hole %d bounds pos %s" % [hole_index, pos])
		return true
	var space := get_world_3d().direct_space_state
	if space == null:
		return false
	var query := PhysicsRayQueryParameters3D.create(pos, pos + Vector3(0, -0.2, 0))
	query.collision_mask = 1
	query.exclude = [_ball.get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return false
	var hit_pos: Vector3 = hit.get("position", pos)
	# Only a surface the ball is actually sitting on. A short ray through
	# the loop or a jump must not treat the cake base as out of bounds.
	if pos.distance_to(hit_pos) > Catalog.BALL_RADIUS + 0.05:
		return false
	var label := str((hit.collider as Node).name) if hit.collider is Node else ""
	if _safe_surface(label):
		return false
	if _hazard(label):
		print("OOB hole %d hazard %s pos %s" % [hole_index, label, pos])
		return true
	return false


func _safe_surface(label: String) -> bool:
	if label.begins_with("Green") or label.begins_with("Rails") or label.begins_with("Bowl") or label.begins_with("Chute"):
		return true
	if label.begins_with("Obstacles") or label.begins_with("Cupcake") or label.begins_with("Conveyor"):
		return true
	if label.begins_with("Rolling") or label.begins_with("Whisk") or label.begins_with("Oven") or label.begins_with("Macaron"):
		return true
	return label.find("colonly") >= 0 and not _hazard(label)


func _hazard(label: String) -> bool:
	if HAZARDS.has(label):
		return true
	return label.begins_with("Base") or label.begins_with("Flour") or label.begins_with("Chocolate") or label.begins_with("Coffee")


func _squash_cupcakes() -> void:
	if hole_index != 3 or _ball == null:
		return
	for i in 5:
		var cake := find_part("Cupcake%d" % (i + 1))
		if cake == null:
			continue
		var hit := cake.global_position.distance_to(_ball.global_position) < 0.34 and _ball.linear_velocity.length() > 0.4
		var target := Vector3(1.12, 0.78, 1.12) if hit else Vector3.ONE
		cake.scale = cake.scale.lerp(target, 0.35)
