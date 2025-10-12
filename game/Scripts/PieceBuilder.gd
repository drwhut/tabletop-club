# tabletop-club
# Copyright (c) 2020-2025 Benjamin 'drwhut' Beddows.
# Copyright (c) 2021-2025 Tabletop Club contributors (see game/CREDITS.tres).
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

extends Node

enum {
	COLLISION_CONVEX,
	COLLISION_MULTI_CONVEX,
	COLLISION_CONCAVE
}

enum {
	COM_ADJUST_OFF,
	COM_ADJUST_VOLUME,
	COM_ADJUST_GEOMETRY
}

# Build a piece using an entry from the AssetDB.
# Returns: The piece corresponding to the given entry.
# piece_entry: The entry to create the piece with.
# extra_nodes: If true, also include nodes that provide extra functionality,
# e.g. sound effects.
func build_piece(piece_entry: Dictionary, extra_nodes: bool = true) -> Piece:
	var piece = ResourceManager.load_res(piece_entry["scene_path"]).instance()
	
	# If the scene is not a piece (e.g. when importing a scene from the assets
	# folder), make it a piece so it can interact with other objects.
	if not piece is Piece:
		var scene_dir = piece_entry["scene_path"].get_base_dir()
		var build: Piece = null
		
		if scene_dir.ends_with("containers"):
			build = PieceContainer.new()
			
			build.contact_monitor = true
			build.contacts_reported = 2
			
			var pieces_node = Spatial.new()
			pieces_node.name = "Pieces"
			build.add_child(pieces_node)
			pieces_node.owner = build
		elif scene_dir.ends_with("speakers") or scene_dir.ends_with("timers"):
			if extra_nodes:
				if scene_dir.ends_with("speakers"):
					build = SpeakerPiece.new()
				else:
					build = TimerPiece.new()
				
				var audio_player_node = AudioStreamPlayer.new()
				audio_player_node.name = "AudioStreamPlayer"
				build.add_child(audio_player_node)
				audio_player_node.owner = build
			else:
				# Speakers rely on their audio player, so convert to a vanilla
				# piece if we don't want the audio player.
				build = Piece.new()
		else:
			var parent_dir = scene_dir.get_base_dir()
			if parent_dir.ends_with("dice"):
				build = Dice.new()
				
				if extra_nodes:
					# Dice, along with cards and tokens, have their own unique
					# sound effects which are implemented here.
					build.contact_monitor = true
					build.contacts_reported = 1
					
					var effect_player = AudioStreamPlayer3D.new()
					effect_player.name = "EffectPlayer"
					effect_player.bus = "Effects"
					effect_player.unit_size = 20.0
					build.add_child(effect_player)
					effect_player.owner = build
					
					build.effect_player_path = NodePath("EffectPlayer")
					
					build.table_collide_fast_sounds = preload("res://Sounds/Dice/DiceTableFastSounds.tres")
					build.shake_sounds = preload("res://Sounds/Dice/DiceShakeSounds.tres")
			else:
				build = Piece.new()
		
		_extract_and_shape_mesh_instances(build, piece, Transform.IDENTITY,
				piece_entry["collision_mode"])
		
		if not piece.get_parent():
			ResourceManager.free_object(piece)
		piece = build
	
	piece.mass = piece_entry["mass"]
	piece.piece_entry = piece_entry
	
	scale_piece(piece, piece_entry["scale"])
	_adjust_centre_of_mass(piece, piece_entry)
	
	if piece_entry.has("texture_path") and piece_entry["texture_path"] is String:
		var texture: Texture = ResourceManager.load_res(piece_entry["texture_path"])
		piece.apply_texture(texture)
		
		# Check if the entry has textures for more than one surface.
		var surface = 1
		while piece_entry.has("texture_path_" + str(surface)):
			var texture_path: String = piece_entry["texture_path_" + str(surface)]
			var optional_texture: Texture
			if not texture_path.empty():
				optional_texture = ResourceManager.load_res(texture_path)
			else:
				optional_texture = preload("res://Images/BlackTexture.png")
			piece.apply_texture(optional_texture, surface)
			surface += 1
	
	if piece.is_albedo_color_exposed():
		piece.set_albedo_color_client(piece_entry["color"])
	
	if extra_nodes:
		piece.setup_outline_material()
		
		var inbuilt_sfx = false
		match piece_entry["scene_path"]:
			"res://Pieces/Card.tscn":
				inbuilt_sfx = true
			"res://Pieces/Tokens/Cube.tscn":
				inbuilt_sfx = true
			"res://Pieces/Tokens/Cylinder.tscn":
				inbuilt_sfx = true
		
		var provided_sfx = false
		if piece_entry.has("sfx"):
			if piece_entry["sfx"] is String:
				if piece_entry["sfx"] in AssetDB.SFX_AUDIO_STREAMS:
					provided_sfx = true
		
		if inbuilt_sfx or provided_sfx:
			if piece.effect_player_path.empty():
				var effect_player = AudioStreamPlayer3D.new()
				effect_player.name = "EffectPlayer"
				effect_player.bus = "Effects"
				effect_player.unit_size = 20
				
				piece.add_child(effect_player)
				effect_player.owner = piece
				piece.effect_player_path = NodePath("EffectPlayer")
			
			# Need to enable contact monitoring so the piece knows when to
			# play the sound effects.
			if not piece.contact_monitor:
				piece.contact_monitor = true
				piece.contacts_reported = 1
			
			if provided_sfx:
				var sounds = AssetDB.SFX_AUDIO_STREAMS[piece_entry["sfx"]]
				piece.table_collide_fast_sounds = sounds["fast"]
				piece.table_collide_slow_sounds = sounds["slow"]
	
	return piece

# Build a table using a table entry from the AssetDB.
# Returns: The table corresponding to the given entry.
# table_entry: The entry to create the table with.
func build_table(table_entry: Dictionary) -> RigidBody:
	var scene: Spatial = ResourceManager.load_res(table_entry["scene_path"]).instance()
	
	var table = RigidBody.new()
	_extract_and_shape_mesh_instances(table, scene, Transform.IDENTITY,
			table_entry["collision_mode"])
	if not scene.get_parent():
		ResourceManager.free_object(scene)
	
	table.mass = 100000 # = 10kg
	table.mode = RigidBody.MODE_STATIC
	
	var physics_material = PhysicsMaterial.new()
	physics_material.bounce = table_entry["bounce"]
	table.physics_material_override = physics_material
	
	# Since the table is a vanilla RigidBody, it doesn't have a "table_entry"
	# property like pieces do, so we'll store the table entry in it's metadata.
	table.set_meta("table_entry", table_entry)
	
	_adjust_centre_of_mass(table, table_entry, true)
	
	return table

# Fill a stack with pieces using an entry from the AssetDB.
# stack: The stack to fill.
# stack_entry: The stack entry to use.
func fill_stack(stack: Stack, stack_entry: Dictionary) -> void:
	var stack_entry_dir = stack_entry["entry_path"].get_base_dir()
	for entry_name in stack_entry["entry_names"]:
		var entry_path = stack_entry_dir + "/" + entry_name
		var piece_entry = AssetDB.search_path(entry_path)
		if piece_entry.empty():
			push_error("Entry (%s) was not found!" % entry_path)
			continue
		
		stack.add_piece(piece_entry, Transform.IDENTITY, Stack.STACK_BOTTOM,
			Stack.FLIP_NO)

# Create an array of MeshInstances from a piece, which can also be inserted
# into stacks.
# Returns: An array of MeshInstances representing the piece's meshes, but with
# extra metadata.
# piece: The piece to get the mesh instances from.
func get_piece_meshes(piece: Piece) -> Array:
	var out = []
	for mesh_instance in piece.get_mesh_instances():
		var piece_mesh = MeshInstance.new()
		piece_mesh.name = piece.name
		piece_mesh.transform = mesh_instance.transform
		
		piece_mesh.set_meta("piece_entry", piece.piece_entry)
		
		piece_mesh.mesh = mesh_instance.mesh
		for surface in range(mesh_instance.get_surface_material_count()):
			var material = mesh_instance.get_surface_material(surface)
			piece_mesh.set_surface_material(surface, material)
		
		out.append(piece_mesh)
	
	return out

# Scale a piece by changing the scale of its children collision shapes.
# piece: The piece to scale.
# scale: How much to scale the piece by.
func scale_piece(piece: Piece, scale: Vector3) -> void:
	for child in piece.get_collision_shapes():
		child.scale_object_local(scale)

# If the given piece entry has bounding box information, adjust the centre of
# mass of a piece to be the centre of the bounding box.
# piece: The piece whose centre of mass to adjust.
# piece_entry: The piece entry of the piece.
# keep_pos: Should the piece's position stay the same?
func _adjust_centre_of_mass(piece: RigidBody, piece_entry: Dictionary,
	keep_pos: bool = false) -> void:
	
	if not piece_entry.has("com_adjust"):
		return
	
	var adjust_method: int = piece_entry["com_adjust"]
	if adjust_method == COM_ADJUST_OFF:
		return
	
	var centre_of_mass: Vector3
	match adjust_method:
		COM_ADJUST_VOLUME:
			var box_min: Vector3 = piece_entry["bounding_box"][0]
			var box_max: Vector3 = piece_entry["bounding_box"][1]
			centre_of_mass = 0.5 * (box_min + box_max)
		COM_ADJUST_GEOMETRY:
			centre_of_mass = piece_entry["avg_point"]
		_:
			push_error("Invalid 'com_adjust' value %d!" % adjust_method)
			return
	
	# NOTE: The reason we offset all the collision shapes is because the
	# Bullet physics engine defines the centre of mass as the origin of the
	# rigidbody, and there is currently no way to manually define the
	# centre of mass of a rigidbody in Godot. See:
	# https://github.com/godotengine/godot-proposals/issues/945
	for child in piece.get_children():
		if child is CollisionShape:
			child.transform.origin -= centre_of_mass
	
	if keep_pos:
		piece.transform.origin += centre_of_mass

# Extract mesh instances from a tree, define collision shapes for each mesh
# instance, and add them to a node.
# add_to: The node to add the collision shapes + mesh instances to.
# from: Where to start recursing from.
# transform: The transform up to that point in the recursion.
# collision_mode: The type of collision shape to make - see the enum above for
# possible values.
func _extract_and_shape_mesh_instances(add_to: Node, from: Node,
	transform: Transform, collision_mode: int) -> void:
	
	for child in from.get_children():
		var new_basis = transform.basis
		var new_origin = transform.origin
		
		if from is Spatial:
			new_basis = from.transform.basis * new_basis
			new_origin = from.transform.origin + new_origin
		
		var new_transform = Transform(new_basis, new_origin)
		_extract_and_shape_mesh_instances(add_to, child, new_transform,
				collision_mode)
	
	if from is MeshInstance:
		var parent = from.get_parent()
		if parent:
			parent.remove_child(from)
		
		# We also want to make sure that the mesh instance has it's own unique
		# material that isn't shared with the other instances, so when e.g. the
		# instance is being selected, not all of the instances look like they
		# are selected (see #20).
		var num_materials = from.get_surface_material_count()
		var num_surfaces  = from.mesh.get_surface_count()
		if num_materials < num_surfaces:
			push_warning("Mesh '%s' has %d surfaces, but only %d materials!" %
				[from.mesh.resource_path, num_surfaces, num_materials])
		
		var num_verts = 0
		for surface in range(num_surfaces):
			# A number of arrays make up the surface - the first of them being
			# the vertex array (which is guaranteed to be there).
			num_verts += from.mesh.surface_get_arrays(surface)[0].size()
			
			# NOTE: We always assume that imported meshes put their materials
			# into the mesh itself, not the mesh instance.
			var material = from.mesh.surface_get_material(surface)
			if material:
				material = material.duplicate()
				
				# There seems to be a bug on OSX where the default cull mode
				# inverts the normals of the mesh.
				# See: https://github.com/godotengine/godot/issues/39936
				if OS.get_name() == "OSX":
					if material is SpatialMaterial:
						material.params_cull_mode = SpatialMaterial.CULL_BACK
				
				from.set_surface_material(surface, material)
				
				# Real-time global illumination is coming in Godot 4, so while
				# we wait we can approximate emissive materials using
				# OmniLights (see #34).
				# EDIT: Having a ton of these lights is causing serious issues
				# on Linux with the NVIDIA Driver (520.56.06), so I'm going to
				# disable them for now - I can always enable them again if there
				# is enough demand, or if the NVIDIA driver has been updated.
				"""
				if material is SpatialMaterial:
					if material.emission_enabled:
						var omnilight = OmniLight.new()
						omnilight.light_color = material.emission
						omnilight.light_energy = material.emission_energy
						from.add_child(omnilight)
				"""
		
		# Don't bother making a collision shape if there's no vertices.
		if num_verts > 0:
			var collision_shape_arr = []
			
			if collision_mode == COLLISION_MULTI_CONVEX:
				from.create_multiple_convex_collisions()
				
				var static_body_index = -1
				for index in range(from.get_child_count()):
					var child = from.get_child(index)
					if child is StaticBody:
						if static_body_index < 0:
							static_body_index = index
						else:
							push_error("Multiple StaticBody children generated!")
							return
				
				if static_body_index < 0:
					push_error("Could not find generated StaticBody!")
					return
				var static_body: StaticBody = from.get_child(static_body_index)
				
				for collision_shape in static_body.get_children():
					if collision_shape is CollisionShape:
						static_body.remove_child(collision_shape)
						collision_shape_arr.append(collision_shape)
				
				from.remove_child(static_body)
				ResourceManager.free_object(static_body)
			else:
				var collision_shape = CollisionShape.new()
				
				if collision_mode == COLLISION_CONVEX:
					collision_shape.shape = from.mesh.create_convex_shape()
				elif collision_mode == COLLISION_CONCAVE:
					collision_shape.shape = from.mesh.create_trimesh_shape()
				else:
					push_error("Invalid collision mode %d!" % collision_mode)
				
				collision_shape_arr.append(collision_shape)
			
			# The collision shape's transform needs to match up with the mesh
			# instance's, but they can't both use the same transform, otherwise
			# the transform of the mesh instance will be wrong.
			var collision_transform = transform
			collision_transform.basis = from.transform.basis * collision_transform.basis
			collision_transform.origin = from.transform.origin + collision_transform.origin
			
			from.transform = Transform.IDENTITY
			for collision_shape in collision_shape_arr:
				collision_shape.transform = collision_transform
				add_to.add_child(collision_shape)
				
				# Set the collision shape's owner to the add_to node, so the
				# PieceCache can store this scene in it's entirety if it wants.
				collision_shape.owner = add_to
			
			if not collision_shape_arr.empty():
				collision_shape_arr[0].add_child(from)
				from.owner = add_to
				
				# We may have added extra nodes to the mesh instance above,
				# for example, OmniLights.
				for sub_child in from.get_children():
					sub_child.owner = add_to
		else:
			ResourceManager.free_object(from)
