extends Node3D
class_name CookieProjectile
## Flying chocolate-chip cookie. Hits NPCs and networked bakers.
## Baker tests run every frame (no grace). Grace is only for wall rays so a
## local toss does not burst on the thrower's own capsule.
## Burst drops cream crumbs so both phones see the same proj_id impact.

const MenuPropsLib := preload("res://scripts/explore/menu_props.gd")
const BAKER_KNOCK := 14.0

signal impacted(at: Vector3, id: String, hit_net_id: String)

var velocity: Vector3 = Vector3.ZERO
var life: float = 2.4
var hit_radius: float = 0.9
var baker_hit_radius: float = 2.05
var baker_hit_y: float = 1.55
var grace: float = 0.1
var exclude_rids: Array[RID] = []
var proj_id: String = ""
var owner_net_id: String = ""
var hit_net_id: String = ""
## Remote / inbound cookies must hurt the local baker even if net_id is empty.
var hits_local: bool = false
var _did_burst := false
var _crumbs: Array[Dictionary] = []


func _ready() -> void:
	add_to_group("cookie_projectile")
	var cookie := MenuPropsLib.instantiate_cookie()
	cookie.name = "Cookie"
	cookie.scale = Vector3(3.35, 3.35, 3.35)
	add_child(cookie)


func arm_from_net() -> void:
	hits_local = true
	grace = 0.0
	_try_hit_bakers(global_position, global_position)


func _physics_process(delta: float) -> void:
	if _did_burst:
		_tick_crumbs(delta)
		return
	velocity.y -= 9.0 * delta
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
			if col is Node and _hurt_collider(col as Node, wall.get("position", next) as Vector3):
				return
			burst_at(wall.get("position", next) as Vector3)
			return
	global_position = next
	rotate_x(8.0 * delta)
	rotate_y(5.0 * delta)
	for npc in get_tree().get_nodes_in_group("village_npc"):
		if not npc is Node3D:
			continue
		var mid: Vector3 = (npc as Node3D).global_position + Vector3(0, 0.75, 0)
		if global_position.distance_to(mid) <= hit_radius:
			if npc.has_method("apply_knockback"):
				npc.call("apply_knockback", global_position, BAKER_KNOCK)
			burst_at(mid)
			return
	life -= delta
	if life <= 0.0 or global_position.y < -1.2:
		queue_free()


func burst_at(at: Vector3, who: String = "") -> void:
	if _did_burst:
		return
	_did_burst = true
	if who != "":
		hit_net_id = who
	global_position = at
	velocity = Vector3.ZERO
	var vis := get_node_or_null("Cookie")
	if vis:
		vis.visible = false
	_spawn_crumbs()
	impacted.emit(at, proj_id, hit_net_id)
	life = 0.42


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
	_apply_baker_hit(baker as Node3D, at)
	return true


func _hurts_local() -> bool:
	if hits_local:
		return true
	if owner_net_id == "":
		return false
	if ExploreNet and owner_net_id == ExploreNet.net_id:
		return false
	return true


func _try_hit_bakers(from: Vector3, to: Vector3) -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	var best_who: Node3D = null
	var best_at := to
	var best_nid := ""
	var best_d := baker_hit_radius
	for baker in tree.get_nodes_in_group("remote_baker"):
		if not baker is Node3D:
			continue
		var nid := str(baker.get("net_id"))
		if nid == "" or nid == owner_net_id:
			continue
		var hit := _baker_overlap(from, to, baker as Node3D)
		if hit.is_empty():
			continue
		var d: float = float(hit["d"])
		if d <= best_d:
			best_d = d
			best_who = baker as Node3D
			best_at = hit["at"]
			best_nid = nid
	if _hurts_local():
		for baker in tree.get_nodes_in_group("local_baker"):
			if not baker is Node3D:
				continue
			var hit := _baker_overlap(from, to, baker as Node3D)
			if hit.is_empty():
				continue
			var d: float = float(hit["d"])
			if d <= best_d:
				best_d = d
				best_who = baker as Node3D
				best_at = hit["at"]
				best_nid = ExploreNet.net_id if ExploreNet else ""
	if best_who == null:
		return false
	_apply_baker_hit(best_who, best_at, best_nid)
	return true


func _apply_baker_hit(who: Node3D, at: Vector3, nid: String = "") -> void:
	if nid == "" and who.is_in_group("remote_baker"):
		nid = str(who.get("net_id"))
	elif nid == "" and who.is_in_group("local_baker") and ExploreNet:
		nid = ExploreNet.net_id
	if who.has_method("apply_knockback"):
		who.call("apply_knockback", at + velocity.normalized() * -0.4, BAKER_KNOCK)
	burst_at(at, nid)


func _baker_overlap(from: Vector3, to: Vector3, baker: Node3D) -> Dictionary:
	var chest: Vector3 = baker.global_position + Vector3(0, 0.78, 0)
	var at := _closest_on_segment(from, to, chest)
	var planar := Vector2(at.x - chest.x, at.z - chest.z).length()
	if planar > baker_hit_radius:
		return {}
	if absf(at.y - chest.y) > baker_hit_y:
		return {}
	return {"at": at, "d": planar}


func _closest_on_segment(a: Vector3, b: Vector3, p: Vector3) -> Vector3:
	var ab := b - a
	var denom := ab.length_squared()
	if denom < 0.0001:
		return a
	return a + ab * clampf(ab.dot(p - a) / denom, 0.0, 1.0)


func _spawn_crumbs() -> void:
	for i in 8:
		var mi := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.045 + float(i % 3) * 0.012
		ball.height = ball.radius * 2.0
		ball.radial_segments = 8
		ball.rings = 4
		mi.mesh = ball
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color("c47a3a") if i % 2 == 0 else Color("f3e2c4")
		mi.material_override = mat
		mi.position = Vector3(randf_range(-0.08, 0.08), 0.04, randf_range(-0.08, 0.08))
		add_child(mi)
		_crumbs.append({
			"n": mi,
			"vel": Vector3(randf_range(-2.4, 2.4), randf_range(2.2, 4.4), randf_range(-2.4, 2.4)),
		})


func _tick_crumbs(delta: float) -> void:
	life -= delta
	for row in _crumbs:
		var mi: MeshInstance3D = row["n"]
		if not is_instance_valid(mi):
			continue
		var vel: Vector3 = row["vel"]
		vel.y -= 16.0 * delta
		row["vel"] = vel
		mi.position += vel * delta
		var fade := clampf(life / 0.42, 0.0, 1.0)
		mi.scale = Vector3.ONE * fade
	if life <= 0.0:
		queue_free()
