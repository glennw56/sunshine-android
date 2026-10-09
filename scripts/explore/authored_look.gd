extends RefCounted
## Unshaded albedo for baked test-world GLBs. Keeps alpha cutout, blend, and vertex color.
## No night multiply: the atlas already has the lighting these models were baked with.


static func apply(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh:
			for i in mi.mesh.get_surface_count():
				var src := mi.get_active_material(i)
				if src == null:
					src = mi.mesh.surface_get_material(i)
				var mat := StandardMaterial3D.new()
				var tex: Texture2D = null
				var albedo := Color.WHITE
				var use_vertex := false
				var transparency := BaseMaterial3D.TRANSPARENCY_DISABLED
				var alpha_scissor := 0.0
				if src is BaseMaterial3D:
					var bm := src as BaseMaterial3D
					tex = bm.albedo_texture
					albedo = bm.albedo_color
					use_vertex = bm.vertex_color_use_as_albedo
					transparency = bm.transparency
					alpha_scissor = bm.alpha_scissor_threshold
				if tex != null:
					mat.albedo_texture = tex
					mat.albedo_color = Color.WHITE
					mat.cull_mode = BaseMaterial3D.CULL_DISABLED
					mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
					mat.vertex_color_use_as_albedo = use_vertex
					mat.transparency = transparency
					mat.alpha_scissor_threshold = alpha_scissor
				else:
					mat.albedo_color = albedo
					mat.vertex_color_use_as_albedo = use_vertex
					mat.transparency = transparency
					mat.alpha_scissor_threshold = alpha_scissor
				mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				mat.metallic = 0.0
				mat.roughness = 1.0
				mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
				mi.set_surface_override_material(i, mat)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in n.get_children():
		apply(child)


static func lift(packed_path: String, node_name: String) -> Node3D:
	if not ResourceLoader.exists(packed_path):
		return null
	var packed := load(packed_path) as PackedScene
	if packed == null:
		return null
	var wrapper := packed.instantiate() as Node3D
	if wrapper == null:
		return null
	var inner := wrapper.find_child(node_name, true, false) as Node3D
	if inner == null:
		wrapper.name = node_name
		wrapper.add_to_group("authored_glb")
		apply(wrapper)
		return wrapper
	wrapper.remove_child(inner)
	wrapper.free()
	inner.name = node_name
	inner.add_to_group("authored_glb")
	apply(inner)
	return inner


static func hide_primitive_standins(root: Node) -> void:
	## Old code meshes share names with the GLB. Godot renames the duplicates,
	## so a first-name hide leaves the rest on top. Hide every primitive that
	## is not inside an authored model. Colliders are not meshes and stay.
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n != root and n.is_in_group("authored_glb"):
			continue
		if n is MeshInstance3D and _is_primitive((n as MeshInstance3D).mesh):
			(n as MeshInstance3D).visible = false
		for child in n.get_children():
			stack.append(child)


static func _is_primitive(mesh: Mesh) -> bool:
	return mesh is BoxMesh or mesh is CylinderMesh or mesh is SphereMesh or mesh is CapsuleMesh or mesh is PrismMesh or mesh is QuadMesh or mesh is TorusMesh
