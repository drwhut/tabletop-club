# open-tabletop
# Copyright (c) 2020-2021 Benjamin 'drwhut' Beddows
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

# Build a piece using an entry from the AssetDB.
# Returns: The piece corresponding to the given entry.
# piece_entry: The entry to create the piece with.
static func build_piece(piece_entry: Dictionary) -> Piece:
	var piece = load(piece_entry["scene_path"]).instance()
	
	# If the scene is not a piece (e.g. when importing a scene from the assets
	# folder), make it a piece so it can interact with other objects.
	if not piece is Piece:
		var build = Piece.new()
		
		_extract_and_shape_mesh_instances(build, piece, Transform.IDENTITY)
		
		# We should take the time to make sure that the centre of mass of the
		# piece is correct, i.e. the rigidbody node is positioned roughly at
		# the centre of the piece. This might not be the case since the
		# imported mesh could be translated to any position!
		var sum_points = Vector3.ZERO
		var num_points = 0
		for child in build.get_children():
			if child is CollisionShape:
				var shape = child.shape
				
				if shape is ConvexPolygonShape:
					for point in shape.points:
						sum_points += child.transform * point
						num_points += 1
		
		var avg_points = sum_points
		if num_points > 1:
			avg_points /= num_points
		
		for child in build.get_children():
			child.transform.origin -= avg_points
		
		if not piece.get_parent():
			piece.free()
		piece = build
	
	piece.mass = piece_entry["mass"]
	piece.piece_entry = piece_entry
	
	scale_piece(piece, piece_entry["scale"])
	
	if piece_entry.has("texture_path") and piece_entry["texture_path"] is String:
		var texture: Texture = load(piece_entry["texture_path"])
		piece.apply_texture(texture)
	
	return piece

# Fill a stack with pieces using an entry from the AssetDB.
# stack: The stack to fill.
# stack_entry: The stack entry to use.
static func fill_stack(stack: Stack, stack_entry: Dictionary) -> void:
	if stack_entry["masses"].size() != stack_entry["texture_paths"].size():
		push_error("Stack entry arrays do not match size!")
		return
	
	var single_piece = load(stack_entry["scene_path"]).instance()
	if not single_piece is Piece:
		push_error("Scene path does not point to a piece!")
		return
	if single_piece.get_collision_shapes().size() != 1:
		push_error("Stackable pieces can only have one collision shape!")
		return
	if single_piece.get_mesh_instances().size() != 1:
		push_error("Stackable pieces can only have one mesh instance!")
		return
	
	scale_piece(single_piece, stack_entry["scale"])
	
	for i in range(stack_entry["texture_paths"].size()):
		var mesh = get_piece_meshes(single_piece)[0]
		var shape = single_piece.get_collision_shapes()[0]
		
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

# Create an array of StackPieceInstances from a piece, which act as mesh
# instances, but can also be inserted into stacks.
# Returns: An array of StackPieceInstances representing the piece's mesh
# instances.
# piece: The piece to get the mesh instances from.
static func get_piece_meshes(piece: Piece) -> Array:
	var out = []
	for mesh_instance in piece.get_mesh_instances():
		var piece_mesh = StackPieceInstance.new()
		piece_mesh.name = piece.name
		piece_mesh.transform = piece.transform
		piece_mesh.piece_entry = piece.piece_entry
		
		# Get the scale from the mesh instance (since the rigid body itself
		# won't be scaled).
		piece_mesh.scale = mesh_instance.scale
		
		piece_mesh.mesh = mesh_instance.mesh
		piece_mesh.set_surface_material(0, mesh_instance.get_surface_material(0))
		
		out.append(piece_mesh)
	
	return out

# Scale a piece by changing the scale of its children collision shapes.
# piece: The piece to scale.
# scale: How much to scale the piece by.
static func scale_piece(piece: Piece, scale: Vector3) -> void:
	for child in piece.get_collision_shapes():
		child.scale_object_local(scale)

# Extract mesh instances from a tree, define collision shapes for each mesh
# instance, and add them to a node.
# add_to: The node to add the collision shapes + mesh instances to.
# from: Where to start recursing from.
# transform: The transform up to that point in the recursion.
static func _extract_and_shape_mesh_instances(add_to: Node, from: Node,
	transform: Transform) -> void:
	
	for child in from.get_children():
		var new_basis = transform.basis
		var new_origin = transform.origin
		
		if from is Spatial:
			new_basis = from.transform.basis * new_basis
			new_origin = from.transform.origin + new_origin
		
		var new_transform = Transform(new_basis, new_origin)
		_extract_and_shape_mesh_instances(add_to, child, new_transform)
	
	if from is MeshInstance:
		var parent = from.get_parent()
		if parent:
			parent.remove_child(from)
		
		# We also want to make sure that the mesh instance has it's own unique
		# material that isn't shared with the other instances, so when e.g. the
		# instance is being selected, not all of the instances look like they
		# are selected (see #20).
		var material = from.get_surface_material(0)
		if not material:
			material = from.mesh.surface_get_material(0)
			if material:
				material = material.duplicate()
				from.set_surface_material(0, material)
		
		var collision_shape = CollisionShape.new()
		collision_shape.shape = from.mesh.create_convex_shape()
		
		# The collision shape's transform needs to match up with the mesh
		# instance's, but they can't both use the same transform, otherwise
		# the transform of the mesh instance will be wrong.
		var collision_transform = transform
		collision_transform.basis = from.transform.basis * collision_transform.basis
		collision_transform.origin = from.transform.origin + collision_transform.origin
		
		collision_shape.transform = collision_transform
		from.transform = Transform.IDENTITY
		
		collision_shape.add_child(from)
		add_to.add_child(collision_shape)
