extends Node3D
class_name CookieProjectile
## Flying chocolate-chip cookie. Hits patio NPCs with playful knockback — no gore.
## Burst drops cream crumbs so remote bakers see the same impact.

const MenuPropsLib := preload("res://scripts/explore/menu_props.gd")

signal impacted(at: Vector3, id: String)

var velocity: Vector3 = Vector3.ZERO
var life: float = 2.4
var hit_radius: float = 0.9
var grace: float = 0.1
var exclude_rids: Array[RID] = []
var proj_id: String = ""
var _did_burst := false
var _crumbs: Array[Dictionary] = []


func _ready() -> void:
	add_to_group("cookie_projectile")
	var cookie := MenuPropsLib.instantiate_cookie()
	cookie.name = "Cookie"
	cookie.scale = Vector3(3.35, 3.35, 3.35)
	add_child(cookie)


func _physics_process(delta: float) -> void:
	if _did_burst:
		_tick_crumbs(delta)
		return
	velocity.y -= 9.0 * delta
	var next := global_position + velocity * delta
	grace = maxf(0.0, grace - delta)
	var space := get_world_3d().direct_space_state
	if grace <= 0.0 and space:
		var q := PhysicsRayQueryParameters3D.create(global_position, next)
		q.collide_with_areas = false
		q.exclude = exclude_rids
		var wall: Dictionary = space.intersect_ray(q)
		if not wall.is_empty():
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
				npc.call("apply_knockback", global_position, 8.4)
			burst_at(mid)
			return
	life -= delta
	if life <= 0.0 or global_position.y < -1.2:
		queue_free()


func burst_at(at: Vector3) -> void:
	if _did_burst:
		return
	_did_burst = true
	global_position = at
	velocity = Vector3.ZERO
	var vis := get_node_or_null("Cookie")
	if vis:
		vis.visible = false
	_spawn_crumbs()
	impacted.emit(at, proj_id)
	life = 0.42


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
