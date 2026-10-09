extends Node3D
class_name PumpkinProjectile
## Test-world pumpkin. Same arc family as the cookie, softer landing.
## Art slot: res://assets/explore/prop_pumpkin_toss.glb (0.35–0.45 m, origin at the bottom).
## Until that GLB is imported, a procedural stand-in matches the size.

const PumpkinProp := preload("res://scripts/explore/pumpkin_prop.gd")
const BAKER_KNOCK := 10.0

signal impacted(at: Vector3, id: String, hit_net_id: String)

var velocity: Vector3 = Vector3.ZERO
var life: float = 2.8
var hit_radius: float = 0.95
var grace: float = 0.1
var exclude_rids: Array[RID] = []
var proj_id: String = ""
var owner_net_id: String = ""
var hit_net_id: String = ""
var hits_local: bool = false
var _did_burst := false
var _crumbs: Array[Dictionary] = []


func _ready() -> void:
	add_to_group("pumpkin_projectile")
	add_to_group("cookie_projectile")
	var prop := PumpkinProp.instantiate()
	prop.name = "Pumpkin"
	add_child(prop)


func arm_from_net() -> void:
	hits_local = true
	grace = 0.0
	_try_hit_bakers(global_position, global_position)


func _physics_process(delta: float) -> void:
	if _did_burst:
		_tick_crumbs(delta)
		return
	velocity.y -= 7.2 * delta
	var next := global_position + velocity * delta
	if _try_hit_bakers(global_position, next):
		return
	grace = maxf(0.0, grace - delta)
	var space := get_world_3d().direct_space_state
	if grace <= 0.0 and space:
		var q := PhysicsRayQueryParameters3D.create(global_position, next)
		q.collide_with_areas = false
		q.exclude = exclude_rids
		var wall: Dictionary = space.intersect_ray(q)
		if not wall.is_empty():
			var col: Variant = wall.get("collider")
			var at: Vector3 = wall.get("position", next)
			if col is Node and _hurt_collider(col as Node, at):
				return
			if col is Node:
				var stand := _scored_target(col as Node)
				if stand != null and stand.has_method("register_hit"):
					stand.call("register_hit")
			soft_land(at)
			return
	global_position = next
	rotate_x(4.0 * delta)
	rotate_z(2.2 * delta)
	for npc in get_tree().get_nodes_in_group("village_npc"):
		if not npc is Node3D:
			continue
		var mid: Vector3 = (npc as Node3D).global_position + Vector3(0, 0.75, 0)
		if global_position.distance_to(mid) <= hit_radius:
			if npc.has_method("apply_knockback"):
				npc.call("apply_knockback", global_position, BAKER_KNOCK)
			soft_land(mid)
			return
	if global_position.y <= 0.05 and velocity.y < 0.0:
		soft_land(Vector3(global_position.x, 0.04, global_position.z))
		return
	life -= delta
	if life <= 0.0 or global_position.y < -1.2:
		queue_free()


func soft_land(at: Vector3, who: String = "") -> void:
	if _did_burst:
		return
	_did_burst = true
	if who != "":
		hit_net_id = who
	global_position = at
	velocity = Vector3.ZERO
	var vis := get_node_or_null("Pumpkin") as Node3D
	if vis:
		vis.scale = Vector3(1.25, 0.35, 1.25)
		vis.position.y = 0.02
	_spawn_crumbs()
	impacted.emit(at, proj_id, hit_net_id)
	life = 0.55


func burst_at(at: Vector3, who: String = "") -> void:
	soft_land(at, who)


func _scored_target(col: Node) -> Node:
	var n: Node = col
	while n:
		if n.is_in_group("practice_target") or n.is_in_group("disco_bullseye"):
			return n
		n = n.get_parent()
	return null


func _hurt_collider(col: Node, at: Vector3) -> bool:
	var baker := col as Node
	while baker and not baker.is_in_group("local_baker") and not baker.is_in_group("remote_baker"):
		baker = baker.get_parent()
	if baker == null:
		return false
	if baker.is_in_group("local_baker") and not _hurts_local():
		return false
	if baker.is_in_group("remote_baker") and str(baker.get("net_id")) == owner_net_id:
		return false
	if baker.has_method("apply_knockback"):
		baker.call("apply_knockback", global_position, BAKER_KNOCK)
	var who := ""
	if baker.is_in_group("remote_baker") or baker.is_in_group("local_baker"):
		who = str(baker.get("net_id"))
	soft_land(at, who)
	return true


func _hurts_local() -> bool:
	return hits_local or owner_net_id != ""


func _try_hit_bakers(from: Vector3, to: Vector3) -> bool:
	var samples: Array[Vector3] = [from, from.lerp(to, 0.5), to]
	for sample in samples:
		for baker in get_tree().get_nodes_in_group("remote_baker"):
			if not baker is Node3D:
				continue
			if str(baker.get("net_id")) == owner_net_id:
				continue
			var mid: Vector3 = (baker as Node3D).global_position + Vector3(0, 1.15, 0)
			if sample.distance_to(mid) <= 1.35:
				if baker.has_method("apply_knockback"):
					baker.call("apply_knockback", sample, BAKER_KNOCK)
				soft_land(mid, str(baker.get("net_id")))
				return true
		if _hurts_local():
			for baker in get_tree().get_nodes_in_group("local_baker"):
				if not baker is Node3D:
					continue
				if str(baker.get("net_id")) == owner_net_id and owner_net_id != "":
					continue
				var mid: Vector3 = (baker as Node3D).global_position + Vector3(0, 1.15, 0)
				if sample.distance_to(mid) <= 1.35:
					if baker.has_method("apply_knockback"):
						baker.call("apply_knockback", sample, BAKER_KNOCK)
					soft_land(mid, str(baker.get("net_id")))
					return true
	return false


func _spawn_crumbs() -> void:
	var orange := Color("e07a32")
	var blush := Color("e8b4b8")
	for i in 5:
		var mesh := SphereMesh.new()
		mesh.radius = 0.045
		mesh.height = 0.09
		mesh.radial_segments = 8
		mesh.rings = 4
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = blush if i == 0 else orange
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = mat
		add_child(mi)
		var dir := Vector3(randf_range(-1, 1), randf_range(0.2, 1.0), randf_range(-1, 1)).normalized()
		_crumbs.append({"node": mi, "vel": dir * randf_range(1.2, 2.4)})


func _tick_crumbs(delta: float) -> void:
	life -= delta
	for row in _crumbs:
		var mi: MeshInstance3D = row.get("node")
		if mi == null:
			continue
		var vel: Vector3 = row.get("vel", Vector3.ZERO)
		vel.y -= 9.0 * delta
		row["vel"] = vel
		mi.position += vel * delta
	if life <= 0.0:
		queue_free()
