# open-tabletop
# Copyright (c) 2020 Benjamin 'drwhut' Beddows
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

extends Resource

class_name PieceBuilder

# Build a piece using an entry from the PieceDB.
# Returns: The piece corresponding to the given entry.
# piece_entry: The entry to create the piece with.
static func build_piece(piece_entry: Dictionary) -> Piece:
	var piece = load(piece_entry["scene_path"]).instance()
	
	# If the scene is not a piece (e.g. when importing a scene from the assets
	# folder), make it a piece so it can interact with other objects.
	if not piece is Piece:
		var build = Piece.new()
		
		# Find the first MeshInstance in the piece scene, so we can get it's
		# mesh data to create a collision shape.
		var mesh_instance = Piece.find_first_mesh_instance(piece)
		if mesh_instance:
			var collision_shape = CollisionShape.new()
			collision_shape.shape = mesh_instance.mesh.create_convex_shape()
			collision_shape.add_child(piece)
			build.add_child(collision_shape)
			
			# We also want to make sure that the mesh instance has it's own
			# unique material that isn't shared with the other instances, so
			# when e.g. the instance is being selected, not all of the instances
			# look like they are selected (see #20).
			var material = mesh_instance.get_surface_material(0)
			if not material:
				material = mesh_instance.mesh.surface_get_material(0)
				if material:
					material = material.duplicate()
					mesh_instance.set_surface_material(0, material)
			
			piece = build
		else:
			push_error(piece.name + " does not have a mesh instance!")
			return null
	
	piece.mass = piece_entry["mass"]
	piece.piece_entry = piece_entry
	
	scale_piece(piece, piece_entry["scale"])
	
	if piece_entry.has("texture_path") and piece_entry["texture_path"] is String:
		var texture: Texture = load(piece_entry["texture_path"])
		piece.apply_texture(texture)
	
	return piece

# Fill a stack with pieces using an entry from the PieceDB.
# stack: The stack to fill.
# stack_entry: The stack entry to use.
static func fill_stack(stack: Stack, stack_entry: Dictionary) -> void:
	if stack_entry["masses"].size() != stack_entry["texture_paths"].size():
		push_error("Stack entry arrays do not match size!")
		return
	
	var single_piece = load(stack_entry["scene_path"]).instance()
	scale_piece(single_piece, stack_entry["scale"])
	
	for i in range(stack_entry["texture_paths"].size()):
		var mesh = get_piece_mesh(single_piece)
		var shape = get_piece_shape(single_piece)
		
		var mass = stack_entry.masses[i]
		var texture_path = stack_entry.texture_paths[i]
		
		# Create a new piece entry based on the stack entry.
		mesh.piece_entry = {
			"mass": mass,
			"name": stack_entry.name,
			"scale": stack_entry.scale,
			"scene_path": stack_entry.scene_path,
			"texture_path": texture_path
		}
		
		# TODO: Make sure StackPieceInstances do the exact same thing as Pieces
		# when it comes to applying textures.
		var texture: Texture = load(texture_path)
		var new_material = SpatialMaterial.new()
		new_material.albedo_texture = texture
		
		mesh.set_surface_material(0, new_material)
		
		stack.add_piece(mesh, shape, Stack.STACK_BOTTOM, Stack.FLIP_NO)
	
	single_piece.queue_free()

# Create a StackPieceInstance from a piece, which acts as a mesh instance, but
# can also be inserted into a stack.
# Returns: A StackPieceInstance representing the piece's mesh instance.
# piece: The piece to use.
static func get_piece_mesh(piece: Piece) -> StackPieceInstance:
	var piece_mesh = StackPieceInstance.new()
	piece_mesh.name = piece.name
	piece_mesh.transform = piece.transform
	piece_mesh.piece_entry = piece.piece_entry
	
	var piece_mesh_inst = piece.get_node("CollisionShape/MeshInstance")
	if not piece_mesh_inst:
		push_error("Piece " + piece.name + " does not have a MeshInstance child!")
		return null
	
	# Get the scale from the mesh instance (since the rigid body itself won't be
	# scaled).
	piece_mesh.scale = piece_mesh_inst.scale
	
	piece_mesh.mesh = piece_mesh_inst.mesh
	piece_mesh.set_surface_material(0, piece_mesh_inst.get_surface_material(0))
	
	return piece_mesh

# Get the collision shape of a piece.
# Returns: The piece's collision shape.
# piece: The piece to query.
static func get_piece_shape(piece: Piece) -> CollisionShape:
	var piece_collision_shape = piece.get_node("CollisionShape")
	if not piece_collision_shape:
		push_error("Piece " + piece.name + " does not have a CollisionShape child!")
		return null
	
	return piece_collision_shape

# Scale a piece by changing the scale of its children collision shapes.
# piece: The piece to scale.
# scale: How much to scale the piece by.
static func scale_piece(piece: Piece, scale: Vector3) -> void:
	for child in piece.get_children():
		if child is CollisionShape:
			child.scale_object_local(scale)
