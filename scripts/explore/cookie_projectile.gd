extends Node3D
class_name CookieProjectile
## Flying chocolate-chip cookie. Hits patio NPCs with playful knockback — no gore.

const MenuPropsLib := preload("res://scripts/explore/menu_props.gd")

var velocity: Vector3 = Vector3.ZERO
var life: float = 2.4
var hit_radius: float = 0.9


func _ready() -> void:
	add_to_group("cookie_projectile")
	var cookie := MenuPropsLib.instantiate_cookie()
	cookie.name = "Cookie"
	cookie.scale = Vector3(1.55, 1.55, 1.55)
	add_child(cookie)


func _physics_process(delta: float) -> void:
	velocity.y -= 9.0 * delta
	var next := global_position + velocity * delta
	var space := get_world_3d().direct_space_state
	if space:
		var q := PhysicsRayQueryParameters3D.create(global_position, next)
		q.collide_with_areas = false
		var wall: Dictionary = space.intersect_ray(q)
		if not wall.is_empty():
			_burst()
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
			_burst()
			return
	life -= delta
	if life <= 0.0 or global_position.y < -1.2:
		queue_free()


func _burst() -> void:
	queue_free()
