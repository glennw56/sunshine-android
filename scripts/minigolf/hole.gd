extends Node3D
## One bakery hole. Collision comes from the glTF `-colonly` meshes.
## Moving parts become AnimatableBody3D so the whisk, door, pins, and
## macaron gates can push the ball. The conveyor stays a StaticBody.

const Catalog := preload("res://scripts/minigolf/catalog.gd")
const Look := preload("res://scripts/explore/authored_look.gd")
const Solids := preload("res://scripts/minigolf/solids.gd")
const Cup := preload("res://scripts/minigolf/cup.gd")

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
var cup_surface_y := 0.0
var _ball: RigidBody3D
var _pipe_cool := 0.0
var _confetti: Array[GPUParticles3D] = []


func setup(index: int) -> void:
	hole_index = index
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
	Solids.apply(self, index, visual)
	_loop_animations(visual)
	# A new hole node starts the whisk, door, pins, and gates from the first frame.
	print("OBSTACLE RESET hole %d" % index)
	tee = visual.find_child("Tee", true, false) as Node3D
	cup = visual.find_child("CupCenter", true, false) as Node3D
	var dug: Dictionary = Cup.build(self)
	cup_surface_y = float(dug.get("y", cup.global_position.y if cup else 0.0))
	_pipes(visual)
	_confetti_cannons(visual)


func arm(ball: RigidBody3D) -> void:
	_ball = ball


func cup_pos() -> Vector3:
	if cup:
		return cup.global_position
	return global_position + Vector3(0, 0, -4)
func tee_pos() -> Vector3:
	var at := global_position
	if tee:
		at = tee.global_position
	# Hole 10's belt crosses the lane further down. The spawn stays on the
	# centreline, on the felt, in front of that belt.
	if hole_index == 10:
		at.x = 0.0
	return _seat_on_lane(at)


func _seat_on_lane(at: Vector3) -> Vector3:
	var fallback := Vector3(at.x, at.y + Catalog.BALL_RADIUS, at.z)
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	if space == null:
		return fallback
	var x := 0.0 if hole_index == 10 else at.x
	# A long ray from above the rails hits a raised lip before the felt and
	# used to walk a good tee forward. Cast only the span the ball occupies.
	# Step toward the start (+Z) only when that span is a conveyor or a hazard.
	for step in 8:
		var z := at.z + float(step) * 0.3
		var hit := _surface_under(space, x, z, at.y)
		if hit.is_empty():
			return fallback
		if _good_spawn(hit):
			var spot: Vector3 = hit.position
			return Vector3(x, spot.y + Catalog.BALL_RADIUS, spot.z)
		if _bad_spawn(hit):
			continue
		return fallback
	return fallback


func _surface_under(space: PhysicsDirectSpaceState3D, x: float, z: float, y: float) -> Dictionary:
	var origin := Vector3(x, y + 0.32, z)
	var end := origin + Vector3(0, -0.7, 0)
	var exclude: Array[RID] = []
	var last: Dictionary = {}
	for _i in 5:
		var query := PhysicsRayQueryParameters3D.create(origin, end)
		query.collision_mask = 1
		query.exclude = exclude
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			return last
		last = hit
		if _good_spawn(hit) or _bad_spawn(hit):
			return hit
		var col: Object = hit.collider
		if col is CollisionObject3D:
			exclude.append((col as CollisionObject3D).get_rid())
			continue
		return hit
	return last


func _good_spawn(hit: Dictionary) -> bool:
	var label := _hit_label(hit)
	if not (label.begins_with("Green") or label.begins_with("Bowl") or label.begins_with("Chute")):
		return false
	var spot: Vector3 = hit.position
	# The cookie belt occupies z -3.4..-2.6. Do not seat on it.
	if hole_index == 10 and spot.z < -2.35 and spot.z > -3.55:
		return false
	return true


func _bad_spawn(hit: Dictionary) -> bool:
	var label := _hit_label(hit)
	if label.begins_with("Conveyor") or _hazard(label):
		return true
	var spot: Vector3 = hit.position
	return hole_index == 10 and spot.z < -2.35 and spot.z > -3.55


func _hit_label(hit: Dictionary) -> String:
	var col: Object = hit.collider
	return str(col.name) if col is Node else ""


func find_part(part_name: String) -> Node3D:
	return find_child(part_name, true, false) as Node3D


func poll() -> String:
	if _ball == null or not is_instance_valid(_ball):
		return ""
	if _pipe_cool > 0.0:
		_pipe_cool = maxf(0.0, _pipe_cool - get_physics_process_delta_time())
	_oob_demo()
	if _sunk():
		var pos := _ball.global_position
		print("CUP sink hole %d y %.3f below %.3f speed %.2f" % [
			hole_index, pos.y, cup_surface_y - pos.y, _ball.linear_velocity.length(),
		])
		return "cup"
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
		# Hole 11 is a 0.30 m bridge. Hole 16's rails are already 0.17 m
		# vertical boxes with flat tops, so a raised crown would wall the lane.
		if label.begins_with("Rails") and hole_index != 11 and hole_index != 16:
			# The loop stays in with a short lip. Open holes need a taller one
			# or a full putt rides the crown and leaves.
			var extra := 0.30 if hole_index == 4 else 0.90
			_steady_rails(body, extra)
		var parent_name := str(body.get_parent().name) if body.get_parent() else ""
		if MOVING.has(parent_name):
			_promote(body)
		elif label == "ConveyorBelt-colonly" or parent_name == "ConveyorBelt":
			body.constant_linear_velocity = Vector3(Catalog.CONVEYOR_MPS, 0.0, 0.0)


func _material_for(label: String) -> PhysicsMaterial:
	var friction := 0.4
	var bounce := 0.12
	if label.begins_with("Green") or label.begins_with("Bowl") or label.begins_with("Chute"):
		# Felt. High friction, and rough so this value is the one the solver uses.
		# Rolling resistance itself is on the ball: PhysicsMaterial has no such term.
		friction = 0.9
		bounce = 0.02
		var mat := PhysicsMaterial.new()
		mat.friction = friction
		mat.bounce = bounce
		mat.rough = true
		return mat
	elif label.begins_with("Rails"):
		# A livelier bank skis a full putt off the curb. 0.5 keeps the remaining curbs down.
		friction = 0.35
		bounce = 0.5
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


func _steady_rails(body: StaticBody3D, extra: float) -> void:
	# v2 rails are 0.135 m with a rounded crown. A full putt rides that
	# crown and leaves the hole. Keep the side faces and stand the crown
	# up into a low wall so the opening in the mesh stays open.
	for child in body.get_children():
		if not (child is CollisionShape3D):
			continue
		var shape_node := child as CollisionShape3D
		if not (shape_node.shape is ConcavePolygonShape3D):
			continue
		var src := shape_node.shape as ConcavePolygonShape3D
		var faces := src.get_faces()
		var out := PackedVector3Array()
		var raised := 0
		var i := 0
		while i + 2 < faces.size():
			var a := faces[i]
			var b := faces[i + 1]
			var c := faces[i + 2]
			i += 3
			var n := (b - a).cross(c - a)
			if n.length() < 0.000001:
				continue
			n = n.normalized()
			if n.y > 0.45:
				var low1 := a
				var low2 := b
				var third := c
				if b.y < a.y and b.y <= c.y:
					low1 = b
					low2 = a if a.y <= c.y else c
					third = c if a.y <= c.y else a
				elif c.y < a.y and c.y <= b.y:
					low1 = c
					low2 = a if a.y <= b.y else b
					third = b if a.y <= b.y else a
				elif a.y <= b.y and a.y <= c.y:
					low2 = b if b.y <= c.y else c
					third = c if b.y <= c.y else b
				var top := maxf(a.y, maxf(b.y, c.y)) + extra
				var h1 := Vector3(low1.x, top, low1.z)
				var h2 := Vector3(low2.x, top, low2.z)
				out.push_back(low1)
				out.push_back(low2)
				out.push_back(h2)
				out.push_back(low1)
				out.push_back(h2)
				out.push_back(h1)
				raised += 1
				# third is unused on purpose; the crown face is replaced.
				if third.y < -999.0:
					raised += 0
			else:
				out.push_back(a)
				out.push_back(b)
				out.push_back(c)
		var rebuilt := ConcavePolygonShape3D.new()
		rebuilt.set_faces(out)
		shape_node.shape = rebuilt
		print("RAIL %s hole %d raised %d" % [body.name, hole_index, raised])


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


func _sunk() -> bool:
	if cup == null or _ball == null:
		return false
	var pos := _ball.global_position
	var flat := Vector2(pos.x - cup.global_position.x, pos.z - cup.global_position.z).length()
	# Below the bevel, inside the throat, and slow. A faster ball is left
	# to physics so the rim can kick it back out.
	# Inside the throat. 0.11 still leaves the ball below the green, so a
	# putt that only reaches the lip does not count.
	# Anywhere in the recess, below the green. The lip is still at green level.
	if flat > 0.28 or pos.y > cup_surface_y - 0.05:
		return false
	return _ball.linear_velocity.length() <= Catalog.CUP_CAPTURE_SPEED


func _in_cup_column() -> bool:
	if cup == null or _ball == null:
		return false
	var pos := _ball.global_position
	var flat := Vector2(pos.x - cup.global_position.x, pos.z - cup.global_position.z).length()
	return flat < 0.42 and pos.y > cup_surface_y - 0.40 and pos.y < cup_surface_y + 0.25


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


func _out_of_bounds() -> bool:
	if _in_cup_column():
		return false
	var pos := _ball.global_position
	if pos.y < Catalog.floor_y(hole_index) - 0.08:
		print("OOB hole %d low y pos %s vel %s" % [hole_index, pos, _ball.linear_velocity])
		return true
	if hole_index == 4 and pos.z < -2.1 and pos.z > -5.35 and pos.y > -0.05:
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
	if label.begins_with("SolidDeck") or label == "CupRim" or label == "CupFloor":
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
