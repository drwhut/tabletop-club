# tabletop-club
# Copyright (c) 2020-2024 Benjamin 'drwhut' Beddows.
# Copyright (c) 2021-2024 Tabletop Club contributors (see game/CREDITS.tres).
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

class_name ObjectBuilder
extends Reference

## Used to build piece and table objects from their respective asset entries.
##
## TODO: Test this class once it is complete.


## Build a [Piece] from the given [AssetEntryScene].
func build_piece(piece_entry: AssetEntryScene) -> Piece:
	var packed_scene := piece_entry.load_scene()
	if packed_scene == null:
		# TODO: Instead of returning null, use a substitute scene.
		push_error("Failed to load scene '%s' for piece entry '%s'" % [
				piece_entry.scene_path, piece_entry.get_path()])
		return null
	
	var piece_node: Piece = null
	
	var instance := packed_scene.instance()
	if instance is Piece:
		piece_node = instance
		
		# Cards need to be given their own custom meshes, since they can have
		# differing corners.
		if piece_entry.scene_path == "res://assets/scenes/card.tscn":
			var collision_shape: CollisionShape = piece_node.get_child(0)
			var mesh_instance: MeshInstance = collision_shape.get_child(0)
			mesh_instance.mesh = CardMeshCache.get_mesh(
					Vector2(piece_entry.scale.x, piece_entry.scale.z),
					Vector2(0.25, 0.25)) # TODO: Editable corner size.
			
			# Can't set multiple surface materials in the editor, so need to
			# add them in code.
			mesh_instance.set_surface_material(0, SpatialMaterial.new())
			mesh_instance.set_surface_material(1, SpatialMaterial.new())
		
		# All materials need to be instanced individually, so that each piece
		# can be modified separately. As far as I can tell, with the way the
		# in-built scenes are constructed, there is no way to set the materials
		# to be local to their scenes, so we need to duplicate them here.
		for element in piece_node.get_mesh_instances():
			var mesh_instance: MeshInstance = element
			setup_materials(mesh_instance)
	else:
		print("ObjectBuilder: Building '%s' using '%s'" % [
				piece_entry.get_path(), piece_entry.scene_path])
		
		if piece_entry is AssetEntryContainer:
			piece_node = PieceContainer.new()
		elif piece_entry is AssetEntryDice:
			piece_node = PieceDice.new()
		else:
			# Stackable pieces like cards and tokens should always use a scene
			# that is built-in, since it is required for them to have standard
			# collision shapes, hence why they are not listed here.
			match piece_entry.type:
				"boards":
					piece_node = PieceBoard.new()
				"pieces":
					piece_node = Piece.new()
				"speakers":
					piece_node = PieceSpeaker.new()
				"timers":
					piece_node = PieceTimer.new()
				_:
					push_warning("Unknown piece type '%s', reverting to regular piece" %
							piece_entry.type)
					piece_node = Piece.new()
		
		transfer_and_shape_mesh_instances(instance, piece_node,
				piece_entry.collision_type)
		instance.free()
	
	# Converting from g -> kg -> (Ns^2/cm, since game units are in cm) = x10.
	piece_node.mass = 10.0 * piece_entry.mass
	
	# Copy the reference to the piece entry within the piece itself.
	piece_node.entry_built_with = piece_entry
	
	# Scale the piece using it's collision shape children. If the player sets
	# the user scale after, it will be relative to this new scale.
	# NOTE: This is done the exact same way that user scale is done in
	# AdvancedRigidBody3D.
	for child in piece_node.get_children():
		if child is CollisionShape:
			var new_shape := ShapeUtil.scale_shape(child.shape, piece_entry.scale)
			if new_shape != null:
				child.shape = new_shape
			
			var new_origin: Vector3 = piece_entry.scale * child.transform.origin
			child.transform.origin = new_origin
			
			if child.get_child_count() > 0:
				var mesh_instance: MeshInstance = child.get_child(0)
				var new_basis := mesh_instance.transform.basis.scaled(
						piece_entry.scale)
				mesh_instance.transform.basis = new_basis
	
	adjust_centre_of_mass(piece_node, piece_entry, false)
	
	piece_node.set_user_albedo(piece_entry.albedo_color)
	
	# If the entry tells us to override the piece's textures, do so here.
	if not piece_entry.texture_overrides.empty():
		var material_list := piece_node.get_materials()
		if piece_entry.texture_overrides.size() != material_list.size():
			push_warning("Texture override count (%d) does not match material count (%d)" % [
					piece_entry.texture_overrides.size(), material_list.size()])
		
		var index := 0
		while (
			index < piece_entry.texture_overrides.size() and
			index < material_list.size()
		):
			var material: SpatialMaterial = material_list[index]
			var texture_path: String = piece_entry.texture_overrides[index]
			
			var texture := ResourceLoader.load(texture_path, "Texture") as Texture
			if texture != null:
				material.albedo_texture = texture
			else:
				push_error("Failed to load texture override '%s'" % texture_path)
			
			index += 1
	
	# TODO: Setup outline materials.
	
	# TODO: Set up collision sound effects.
	
	return piece_node


## Build a [Table] from the given [AssetEntryTable].
func build_table(table_entry: AssetEntryTable) -> Table:
	var packed_scene := table_entry.load_scene()
	if packed_scene == null:
		# TODO: Instead of returning null, use a substitute scene.
		push_error("Failed to load scene '%s' for table entry '%s'" % [
				table_entry.scene_path, table_entry.get_path()])
		return null
	
	var table_node: Table = null
	
	var instance := packed_scene.instance()
	if instance is Table:
		table_node = instance
	else:
		print("ObjectBuilder: Building '%s' using '%s'" % [
				table_entry.get_path(), table_entry.scene_path])
		table_node = Table.new()
		transfer_and_shape_mesh_instances(instance, table_node,
				table_entry.collision_type)
		instance.free()
	
	table_node.mass = 100000 # = 10kg
	table_node.mode = RigidBody.MODE_STATIC
	table_node.physics_material_override = table_entry.physics_material
	
	# NOTE: The scale property from the entry is not used here for tables,
	# and that's on purpose. Since tables have the requirement that the surface
	# needs to be parallel to the plane y=0, the scale property from the config
	# file would probably invalidate that requirement unexpectedly a lot of the
	# time, hence if the creator wishes to scale the table, it should be done
	# in the modelling software from which the table was made.
	
	adjust_centre_of_mass(table_node, table_entry, true)
	
	return table_node


## Given a scene of nodes, extract all of the [MeshInstance] nodes out of the
## scene and return them in an array. The nodes are automatically removed from
## their parents, and each local transform is adjusted to be their original
## global transform.
## NOTE: [code]root_node[/code] is NOT checked as a [MeshInstance].
## TODO: Make typed in 4.x
func extract_mesh_instances(root_node: Node) -> Array:
	var output_arr := []
	_extract_mesh_instances_recursive(root_node, Transform.IDENTITY, output_arr)
	return output_arr


## Given a [MeshInstance], set up its materials so that each instance of them is
## unique, which allows us to modify each material separately.
func setup_materials(mesh_instance: MeshInstance) -> void:
	var mesh := mesh_instance.mesh
	if mesh == null:
		push_error("Mesh instance '%s' does not contain a mesh" % mesh_instance.name)
		return
	
	var num_surfaces := mesh.get_surface_count()
	for surface_index in range(num_surfaces):
		var material := mesh_instance.get_active_material(surface_index)
		if material == null:
			continue
		
		var unique_material := material.duplicate()
		
		# There seems to be a bug in OSX where the default cull mode inverts the
		# normals of the mesh.
		# See: https://github.com/godotengine/godot/issues/39936
		if OS.get_name() == "OSX":
			if material is SpatialMaterial:
				material.params_cull_mode = SpatialMaterial.CULL_BACK
		
		mesh_instance.set_surface_material(surface_index, unique_material)


## Given a [MeshInstance], create a single [CollisionShape] representing the
## mesh. If [code]concave[/code] is [code]true[/code], the resulting shape will
## be concave, otherwise it will be convex.
##
## [b]NOTE:[/b] The [Shape] that is returned does not account for the transform
## of the [MeshInstance], only the [Mesh] within.
func create_single_shape(mesh_instance: MeshInstance,
		concave: bool) -> CollisionShape:
	
	var mesh := mesh_instance.mesh
	if mesh == null:
		push_error("Mesh instance '%s' does not contain a mesh" % mesh_instance.name)
		return null
	
	var collision_shape := CollisionShape.new()
	if concave:
		collision_shape.shape = mesh.create_trimesh_shape()
	else:
		collision_shape.shape = mesh.create_convex_shape()
	
	return collision_shape


## Given a [MeshInstance], create an array of [CollisionShape] representing the
## mesh.
##
## [b]NOTE:[/b] The [Shape] that is returned does not account for the transform
## of the [MeshInstance], only the [Mesh] within.
## TODO: Check if this is actually true.
func create_multiple_shapes(mesh_instance: MeshInstance) -> Array:
	mesh_instance.create_multiple_convex_collisions()
	
	# The operation above should have created a [StaticBody] with one or more
	# [CollisionShape] nodes as children, we just need to find it.
	var static_body_index := -1
	for index in range(mesh_instance.get_child_count()):
		var child := mesh_instance.get_child(index)
		if child is StaticBody:
			if static_body_index < 0:
				static_body_index = index
			else:
				push_error("Mesh instance '%s' has multiple StaticBody children" %
						mesh_instance.name)
				return []
	
	if static_body_index < 0:
		push_error("Mesh instance '%s' has no StaticBody child" % mesh_instance.name)
		return []
	
	var static_body := mesh_instance.get_child(static_body_index)
	var collision_shape_arr := []
	for collision_shape in static_body.get_children():
		if collision_shape is CollisionShape:
			static_body.remove_child(collision_shape)
			collision_shape_arr.push_back(collision_shape)
	
	static_body.free()
	return collision_shape_arr


## Transfer all [MeshInstance] nodes from the node structure starting with
## [code]from_node[/code], and place them into the node structure starting with
## [code]to_node[/code] as children of [CollisionShape] nodes.
## [code]collision_type[/code] is one of [enum AssetEntryScene.CollisionType].
func transfer_and_shape_mesh_instances(from_node: Node, to_node: Node,
		collision_type: int) -> void:
	
	var mesh_instance_arr := extract_mesh_instances(from_node)
	
	# Go through the array backwards, as there is a chance that some of the mesh
	# instances will be invalid, meaning they can't be used, and will need to be
	# freed from memory during this function.
	for index in range(mesh_instance_arr.size() - 1, -1, -1):
		var mesh_instance: MeshInstance = mesh_instance_arr[index]
		
		# Check to see if the mesh within the instance actually contains any
		# vertices, we should skip it if it doesn't as we won't be able to make
		# collision shapes out of it.
		var mesh := mesh_instance.mesh
		if mesh == null:
			mesh_instance.free()
			continue
		
		var has_verts := false
		for surface in range(mesh.get_surface_count()):
			# The engine guarantees that the vertex array will always exist.
			var vert_arr: Array = mesh.surface_get_arrays(surface)[0]
			if not vert_arr.empty():
				has_verts = true
				break
		
		if not has_verts:
			mesh_instance.free()
			continue
		
		setup_materials(mesh_instance)
		
		var collision_shape_arr: Array
		match collision_type:
			AssetEntryScene.CollisionType.COLLISION_CONVEX:
				collision_shape_arr = [ create_single_shape(mesh_instance, false) ]
			AssetEntryScene.CollisionType.COLLISION_CONCAVE:
				collision_shape_arr = [ create_single_shape(mesh_instance, true) ]
			AssetEntryScene.CollisionType.COLLISION_MULTI_CONVEX:
				collision_shape_arr = create_multiple_shapes(mesh_instance)
			AssetEntryScene.CollisionType.COLLISION_NONE:
				push_warning("No collision shape wanted for custom mesh '%s', probably not intended" %
						mesh_instance.name)
				collision_shape_arr = [ CollisionShape.new() ]
			_:
				push_warning("Unknown value '%d' for collision type" % collision_type)
				collision_shape_arr = [ CollisionShape.new() ]
		
		if collision_shape_arr.empty():
			push_error("No collision shapes generated for mesh '%s'" % mesh_instance.name)
			mesh_instance.free()
			continue
		
		for element in collision_shape_arr:
			var collision_shape: CollisionShape = element
			
			# Take only the translation from the mesh instance - the rotation
			# and scale will be embedded into the shape data.
			# This way, we can avoid messing with the collision shape's basis
			# and allow the physics engine to make optimisations.
			collision_shape.transform.origin = mesh_instance.transform.origin
			
			# Apply the mesh instance's transform to the generated collision
			# shape, so that it lines up with the mesh instance. We need to do
			# this since the generated shape is only based on the mesh, not the
			# mesh instance.
			var transformed_shape := ShapeUtil.transform_shape(
					collision_shape.shape, mesh_instance.transform.basis)
			collision_shape.shape = transformed_shape
			
			to_node.add_child(collision_shape)
			
			# Add the mesh instance to the first available collision shape.
			if mesh_instance.get_parent() == null:
				collision_shape.add_child(mesh_instance)
		
		# Since we have added the mesh's translation to all collision shapes,
		# we need to remove it from the mesh instance so that the translation
		# is not applied twice.
		mesh_instance.transform.origin = Vector3.ZERO


## Adjust the centre-of-mass of an object using the geometric metadata in it's
## scene entry. If [code]keep_position[/code] is [code]true[/code], then the
## position of the object itself is counter-adjusted so that it's global
## position remains the same.
## NOTE: This function is needed since the centre-of-mass of a [RigidBody] in
## Bullet Physics is defined as the centre of the rigid body, so this function
## adjusts the positions of the [CollisionShape] children. See:
## https://github.com/godotengine/godot-proposals/issues/945
func adjust_centre_of_mass(object: Spatial, scene_entry: AssetEntryScene,
		keep_position: bool) -> void:
	
	if scene_entry.com_adjust == AssetEntryScene.ComAdjust.COM_ADJUST_OFF:
		return
	
	var centre_of_mass := Vector3.ZERO
	match scene_entry.com_adjust:
		AssetEntryScene.ComAdjust.COM_ADJUST_VOLUME:
			centre_of_mass = scene_entry.bounding_box.get_center()
		AssetEntryScene.ComAdjust.COM_ADJUST_GEOMETRY:
			centre_of_mass = scene_entry.avg_point
		_:
			push_warning("Unknown value '%d' for COM adjustment of '%s'" % [
					scene_entry.com_adjust, scene_entry.get_path()])
	
	for child in object.get_children():
		if child is CollisionShape:
			child.transform.origin -= centre_of_mass
	
	if keep_position:
		object.transform.origin += centre_of_mass


# Recursively check through the child nodes of [code]current_node[/code], with
# [code]parent_transform[/code] being the global transform of it's parent, and
# extract all [MeshInstance] nodes to the output array.
func _extract_mesh_instances_recursive(current_node: Node,
		parent_transform: Transform, output_array: Array) -> void:
	
	var current_transform := parent_transform
	if current_node is Spatial:
		current_transform = parent_transform * current_node.transform
	
	for child in current_node.get_children():
		if child is MeshInstance:
			current_node.remove_child(child)
			child.transform = current_transform * child.transform
			output_array.push_back(child)
		
		elif child.get_child_count() > 0:
			_extract_mesh_instances_recursive(child, current_transform,
					output_array)
