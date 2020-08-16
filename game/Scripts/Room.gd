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

extends Spatial

signal cards_in_hand_requested(cards)
signal started_hovering_card(card)
signal stopped_hovering_card(card)

const STACK_SPLIT_DISTANCE = 1.0

onready var _camera_controller = $CameraController
onready var _pieces = $Pieces

var _srv_next_piece_name = 0

# Called by the server to add a piece to the room.
# name: The name of the new piece.
# transform: The initial transform of the new piece.
# piece_entry: The piece's entry in the PieceDB.
# hover_player: If set to > 0, it will initially be in a hover state by the
# player with the given ID.
remotesync func add_piece(name: String, transform: Transform,
	piece_entry: Dictionary, hover_player: int = 0) -> void:
	
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	# Firstly, check to see if the piece entry does not represent a pre-filled
	# stack.
	if piece_entry.has("texture_paths") and (not piece_entry.has("texture_path")):
		push_error("Cannot add " + piece_entry.name + " as a piece, since it is a pre-filled stack!")
		return
	
	var piece = load(piece_entry["scene_path"]).instance()
	
	# If the scene is not a piece (e.g. when importing a scene from the assets
	# folder), make it a piece so it can interact with other objects.
	if not piece is Piece:
		piece = _build_piece(piece)
	
	piece.name = name
	piece.transform = transform
	piece.piece_entry = piece_entry
	
	# Scale the piece by changing the scale of all collision shapes and mesh
	# instances.
	_scale_piece(piece, piece_entry["scale"])
	
	_pieces.add_child(piece)
	
	piece.connect("piece_exiting_tree", self, "_on_piece_exiting_tree")
	
	# If it is a stackable piece, make sure we attach the signal it emits when
	# it wants to create a stack.
	if piece is StackablePiece:
		piece.connect("stack_requested", self, "_on_stack_requested")
	
	# Apply a generic texture to the die.
	if piece_entry.has("texture_path") and piece_entry["texture_path"]:
		var texture: Texture = load(piece_entry["texture_path"])
		
		piece.apply_texture(texture)
	
	if get_tree().is_network_server() and hover_player > 0:
		piece.srv_start_hovering(hover_player, transform.origin, Vector3())

# Called by the server to add a piece to a stack.
# piece_name: The name of the piece.
# stack_name: The name of the stack.
# on: Where to add the piece to in the stack.
# flip: Should the piece be flipped upon entering the stack?
remotesync func add_piece_to_stack(piece_name: String, stack_name: String,
	on: int = Stack.STACK_AUTO, flip: int = Stack.FLIP_AUTO) -> void:
	
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	var piece = _pieces.get_node(piece_name)
	var stack = _pieces.get_node(stack_name)
	
	if not piece:
		push_error("Piece " + stack_name + " does not exist!")
		return
	
	if not stack:
		push_error("Stack " + stack_name + " does not exist!")
		return
	
	if not piece is StackablePiece:
		push_error("Piece " + piece_name + " is not stackable!")
		return
	
	if not stack is Stack:
		push_error("Piece " + stack_name + " is not a stack!")
		return
	
	_pieces.remove_child(piece)
	
	var piece_mesh = _get_stack_piece_mesh(piece)
	var piece_shape = _get_stack_piece_shape(piece)
	
	if not (piece_mesh and piece_shape):
		return
	
	stack.add_piece(piece_mesh, piece_shape, on, flip)
	
	piece.queue_free()

# Called by the server to add a stack to the room with 2 initial pieces.
# name: The name of the new stack.
# transform: The initial transform of the new stack.
# piece1_name: The name of the first piece to add to the stack.
# piece2_name: The name of the second piece to add to the stack.
remotesync func add_stack(name: String, transform: Transform,
	piece1_name: String, piece2_name: String) -> void:
	
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	var piece1 = _pieces.get_node(piece1_name)
	var piece2 = _pieces.get_node(piece2_name)
	
	if not piece1:
		push_error("Stackable piece " + piece1_name + " does not exist!")
		return
	
	if not piece2:
		push_error("Stackable piece " + piece2_name + " does not exist!")
		return
	
	if not piece1 is StackablePiece:
		push_error("Piece " + piece1_name + " is not stackable!")
		return
	
	if not piece2 is StackablePiece:
		push_error("Piece " + piece2_name + " is not stackable!")
		return
	
	_pieces.remove_child(piece1)
	_pieces.remove_child(piece2)
	
	var piece1_mesh = _get_stack_piece_mesh(piece1)
	var piece2_mesh = _get_stack_piece_mesh(piece2)
	
	var piece1_shape = _get_stack_piece_shape(piece1)
	var piece2_shape = _get_stack_piece_shape(piece2)
	
	if not (piece1_mesh and piece2_mesh and piece1_shape and piece2_shape):
		return
	
	var stack = add_stack_empty(name, transform)
	
	stack.add_piece(piece1_mesh, piece1_shape)
	stack.add_piece(piece2_mesh, piece2_shape)
	
	piece1.queue_free()
	piece2.queue_free()

# Called by the server to add an empty stack to the room.
# name: The name of the new stack.
# transform: The initial transform of the new stack.
puppet func add_stack_empty(name: String, transform: Transform) -> Stack:
	
	if get_tree().get_rpc_sender_id() != 1:
		return null
	
	var stack: Stack = preload("res://Pieces/Stack.tscn").instance()
	
	stack.name = name
	stack.transform = transform
	
	_pieces.add_child(stack)
	
	stack.connect("piece_exiting_tree", self, "_on_piece_exiting_tree")
	stack.connect("stack_requested", self, "_on_stack_requested")
	
	return stack

# Called by the server to add a pre-filled stack to the room.
# name: The name of the new stack.
# transform: The initial transform of the new stack.
# stack_entry: The stack's entry in the PieceDB.
# piece_names: The names of the pieces in the newly filled stack.
remotesync func add_stack_filled(name: String, transform: Transform,
	stack_entry: Dictionary, piece_names: Array) -> void:
	
	var single_piece = load(stack_entry["scene_path"]).instance()
	_scale_piece(single_piece, stack_entry["scale"])
	
	var stack = add_stack_empty(name, transform)
	
	var i = 0
	for texture_path in stack_entry["texture_paths"]:
		var mesh = _get_stack_piece_mesh(single_piece)
		var shape = _get_stack_piece_shape(single_piece)
		
		# Create a new piece entry based on the stack entry.
		mesh.name = piece_names[i]
		mesh.piece_entry = {
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
		
		i += 1
	
	single_piece.queue_free()

# Called by the server to merge the contents of one stack into another stack.
# stack1_name: The name of the stack to merge contents from.
# stack2_name: The name of the stack to merge contents to.
remotesync func add_stack_to_stack(stack1_name: String, stack2_name: String) -> void:
	
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	var stack1 = _pieces.get_node(stack1_name)
	var stack2 = _pieces.get_node(stack2_name)
	
	if not stack1:
		push_error("Stack " + stack1_name + " does not exist!")
		return
	
	if not stack2:
		push_error("Stack " + stack2_name + " does not exist!")
		return
	
	if not stack1 is Stack:
		push_error("Piece " + stack1_name + " is not a stack!")
		return
	
	if not stack2 is Stack:
		push_error("Piece " + stack2_name + " is not a stack!")
		return
	
	# If there are no children in the first stack, don't bother doing anything.
	if stack1.get_piece_count() == 0:
		return
	
	# We need to determine in which order to add the children of the first stack
	# to the second stack.
	# NOTE: In stacks, children are stored bottom-first.
	var reverse = false
	
	if stack1.transform.origin.y > stack2.transform.origin.y:
		reverse = stack1.transform.basis.y.dot(Vector3.DOWN) > 0
	else:
		reverse = stack1.transform.basis.y.dot(Vector3.UP) > 0
	
	# Remove the children of the first stack, determine their transform, then
	# add them to the second stack.
	var pieces = stack1.empty()
	if reverse:
		pieces.invert()
	
	for piece in pieces:
		var basis = piece.transform.basis
		var origin = piece.transform.origin
		
		basis = stack1.transform.basis * basis
		origin = stack1.transform.origin + origin
		
		piece.transform = Transform(basis, origin)
		
		stack2.add_piece(piece, null)
	
	# Finally, delete the first stack.
	_pieces.remove_child(stack1)
	stack1.queue_free()

# Apply options from the options menu.
# config: The options to apply.
func apply_options(config: ConfigFile) -> void:
	_camera_controller.apply_options(config)

# Get the player camera's hover position.
# Returns: The current hover position.
func get_camera_hover_position() -> Vector3:
	return _camera_controller.get_hover_position()

# Get a piece in the room with a given name.
# Returns: The piece with the given name.
# name: The name of the piece.
func get_piece_with_name(name: String) -> Piece:
	return _pieces.get_node(name)

# Get the list of pieces in the room.
# Returns: The list of pieces in the room.
func get_pieces() -> Array:
	return _pieces.get_children()

# Get the number of pieces in the room.
# Returns: The number of pieces in the room.
func get_piece_count() -> int:
	return _pieces.get_child_count()

# Get the current room state.
# Returns: The current room state.
func get_state() -> Dictionary:
	var out = {}
	
	var piece_dict = {}
	var stack_dict = {}
	for piece in _pieces.get_children():
		if piece is Stack:
			var stack_meta = {
				"is_locked": piece.is_locked(),
				"transform": piece.transform
			}
			
			var child_pieces = []
			for child_piece in piece.get_pieces():
				var child_piece_meta = {
					"flip_y": piece.is_piece_flipped(child_piece),
					"name": child_piece.name,
					"piece_entry": child_piece.piece_entry
				}
				
				child_pieces.push_back(child_piece_meta)
			
			stack_meta["pieces"] = child_pieces
			stack_dict[piece.name] = stack_meta
		else:
			var piece_meta = {
				"is_locked": piece.is_locked(),
				"piece_entry": piece.piece_entry,
				"transform": piece.transform
			}
			
			piece_dict[piece.name] = piece_meta
	
	out["pieces"] = piece_dict
	out["stacks"] = stack_dict
	return out

# Request the server to add a pre-filled stack.
# stack_entry: The stack's entry in the PieceDB.
master func request_add_stack_filled(stack_entry: Dictionary) -> void:
	# Before we can get everyone to add the stack, we need to come up with names
	# for the stack and it's items.
	var stack_name = srv_get_next_piece_name()
	var piece_names = []
	
	for texture_path in stack_entry["texture_paths"]:
		piece_names.push_back(srv_get_next_piece_name())
	
	var transform = Transform(Basis.IDENTITY, Vector3(0, Piece.SPAWN_HEIGHT, 0))
	
	rpc("add_stack_filled", stack_name, transform, stack_entry, piece_names)

# Request the server to collect a set of pieces and, if possible, put them into
# stacks.
# piece_names: The names of the pieces to try and collect.
master func request_collect_pieces(piece_names: Array) -> void:
	var pieces = []
	for piece_name in piece_names:
		var piece = _pieces.get_node(piece_name)
		if piece and piece is StackablePiece:
			pieces.append(piece)
	
	if pieces.size() <= 1:
		return
	
	var add_to = pieces.pop_front()
	
	while add_to:
		for i in range(pieces.size() - 1, -1, -1):
			var add_from = pieces[i]
			
			if add_to.matches(add_from):
				if add_to is Stack:
					if add_from is Stack:
						rpc("add_stack_to_stack", add_to.name, add_from.name)
					else:
						rpc("add_piece_to_stack", add_from.name, add_to.name)
				else:
					if add_from is Stack:
						rpc("add_piece_to_stack", add_to.name, add_from.name)
						
						# add_to (Piece) has been added to add_from (Stack), so
						# in future, we need to add pieces to add_from.
						add_to = add_from
					else:
						var new_stack_name = srv_get_next_piece_name()
						rpc("add_stack", new_stack_name, add_to.transform,
							add_to.name, add_from.name)
						add_to = _pieces.get_node(new_stack_name)
				
				pieces.remove(i)
		
		add_to = pieces.pop_front()

# Request the server to hover a piece.
# piece_name: The name of the piece to hover.
# init_pos: The initial hover position.
# offset_pos: The hover position offset.
master func request_hover_piece(piece_name: String, init_pos: Vector3,
	offset_pos: Vector3) -> void:
	
	var piece = _pieces.get_node(piece_name)
	
	if not piece:
		push_error("Piece " + piece_name + " does not exist!")
		return
	
	if not piece is Piece:
		push_error("Object " + piece_name + " is not a piece!")
		return
	
	var player_id = get_tree().get_rpc_sender_id()
	
	if piece.srv_start_hovering(player_id, init_pos, offset_pos):
		rpc_id(player_id, "request_hover_piece_accepted", piece_name)

# Called by the server if the request to hover a piece was accepted.
# piece_name: The name of the piece we are now hovering.
remotesync func request_hover_piece_accepted(piece_name: String) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	var piece = _pieces.get_node(piece_name)
	
	if not piece:
		push_error("Piece " + piece_name + " does not exist!")
		return
	
	if not piece is Piece:
		push_error("Object " + piece_name + " is not a piece!")
		return
	
	_camera_controller.append_selected_pieces([piece])
	_camera_controller.set_is_hovering(true)
	
	if piece is Card:
		emit_signal("started_hovering_card", piece)

# Request the server to pop the piece at the top of a stack.
# stack_name: The name of the stack to pop.
# hover: Do we want to start hovering the piece afterwards?
master func request_pop_stack(stack_name: String, hover: bool = true) -> void:
	
	var player_id = get_tree().get_rpc_sender_id()
	var stack = _pieces.get_node(stack_name)
	
	if not stack:
		push_error("Stack " + stack_name + " does not exist!")
		return
	
	if not stack is Stack:
		push_error("Object " + stack_name + " is not a stack!")
		return
	
	var piece_instance: StackPieceInstance = null
	
	if stack.get_piece_count() == 0:
		return
	elif stack.get_piece_count() == 1:
		piece_instance = stack.empty()[0]
		stack.rpc("remove_self")
	else:
		piece_instance = stack.pop_piece()
		stack.rpc("remove_piece_by_name", piece_instance.name)
	
	if piece_instance:
		
		# Create the transform for the new piece.
		# NOTE: We normalise the basis here to reset the piece's scale, because
		# add_piece will use the piece entry to scale the piece again.
		var new_basis = (stack.transform.basis * piece_instance.transform.basis).orthonormalized()
		var new_origin = stack.transform.origin + Vector3(0, stack.get_total_height() / 2, 0)
		
		# If this piece will hover, get it away from the stack so it doesn't
		# immediately collide with it again.
		if hover:
			new_origin.y += STACK_SPLIT_DISTANCE + stack.get_unit_height() / 2
		var new_transform = Transform(new_basis, new_origin)
		
		if not hover:
			player_id = 0
		
		rpc("add_piece", piece_instance.name, new_transform,
			piece_instance.piece_entry, player_id)
		
		if hover:
			rpc_id(player_id, "request_pop_stack_accepted", piece_instance.name)
		
		piece_instance.queue_free()
		
	# Check to see if there is only one piece left in the stack - if there is,
	# turn it into a normal piece with this method.
	if stack.get_piece_count() == 1:
		request_pop_stack(stack_name, false)

# Called by the server if the request to pop a stack was accepted, and we are
# now hovering the new piece.
# piece_name: The name of the piece that is now hovering.
remotesync func request_pop_stack_accepted(piece_name: String) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	# The server has allowed us to hover the piece that has just poped off the
	# stack!
	request_hover_piece_accepted(piece_name)

# Request the server to get a stack to collect all of the pieces that it can
# stack.
# stack_name: The name of the collecting stack.
# collect_stacks: Do we want to collect other stacks? If false, it only collects
# individual pieces.
master func request_stack_collect_all(stack_name: String, collect_stacks: bool) -> void:
	var stack = _pieces.get_node(stack_name)
	
	if not stack:
		push_error("Stack " + stack_name + " does not exist!")
		return
	
	if not stack is Stack:
		push_error("Object " + stack_name + " is not a stack!")
		return
	
	for piece in get_pieces():
		if piece is StackablePiece and piece.name != stack_name:
			if stack.matches(piece):
				if piece is Stack:
					if collect_stacks:
						rpc("add_stack_to_stack", piece.name, stack_name)
					else:
						continue
				else:
					if piece is Card and piece.srv_is_placed_aside():
						continue
					rpc("add_piece_to_stack", piece.name, stack_name, Stack.STACK_TOP)

# Set the room state.
# state: The new room state.
puppet func set_state(state: Dictionary) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	# Delete all the pieces on the board currently before we begin.
	for child in _pieces.get_children():
		remove_child(child)
		child.queue_free()
	
	if state.has("pieces"):
		for piece_name in state["pieces"]:
			var piece_meta = state["pieces"][piece_name]
			
			if not piece_meta.has("is_locked"):
				push_error("Piece " + piece_name + " in new state has no is locked value!")
				return
			
			if not piece_meta["is_locked"] is bool:
				push_error("Piece " + piece_name + " is locked value is not a boolean!")
				return
			
			if not piece_meta.has("piece_entry"):
				push_error("Piece " + piece_name + " in new state has no piece entry!")
				return
			
			if not piece_meta["piece_entry"] is Dictionary:
				push_error("Piece " + piece_name + " entry is not a dictionary!")
				return
			
			if not piece_meta.has("transform"):
				push_error("Piece " + piece_name + " in new state has no transform!")
				return
			
			if not piece_meta["transform"] is Transform:
				push_error("Piece " + piece_name + " transform is not a transform!")
				return
			
			add_piece(piece_name, piece_meta["transform"], piece_meta["piece_entry"])
			
			if piece_meta["is_locked"]:
				var piece: Piece = _pieces.get_node(piece_name)
				piece.lock_client(piece_meta["transform"])
	
	if state.has("stacks"):
		for stack_name in state["stacks"]:
			var stack_meta = state["stacks"][stack_name]
			
			if not stack_meta.has("is_locked"):
				push_error("Stack " + stack_name + " in new state has no is locked value!")
				return
			
			if not stack_meta["is_locked"] is bool:
				push_error("Stack " + stack_name + " is locked value is not a boolean!")
				return
			
			if not stack_meta.has("transform"):
				push_error("Stack " + stack_name + " in new state has no transform!")
				return
			
			if not stack_meta["transform"] is Transform:
				push_error("Stack " + stack_name + " transform is not a transform!")
				return
			
			if not stack_meta.has("pieces"):
				push_error("Stack " + stack_name + " in new state has no piece array!")
				return
			
			if not stack_meta["pieces"] is Array:
				push_error("Stack " + stack_name + " piece array is not an array!")
				return
			
			var stack = add_stack_empty(stack_name, stack_meta["transform"])
			
			if stack_meta["is_locked"]:
				var stack_node: Stack = _pieces.get_node(stack_name)
				stack_node.lock_client(stack_meta["transform"])
			
			for stack_piece_meta in stack_meta["pieces"]:
				
				if not stack_piece_meta is Dictionary:
					push_error("Stack piece is not a dictionary!")
					return
				
				if not stack_piece_meta.has("name"):
					push_error("Stack piece does not have a name!")
					return
				
				if not stack_piece_meta["name"] is String:
					push_error("Stack piece name is not a string!")
					return
				
				var stack_piece_name = stack_piece_meta["name"]
				
				if not stack_piece_meta.has("flip_y"):
					push_error("Stack piece" + stack_piece_name + " does not have a flip value!")
					return
				
				if not stack_piece_meta["flip_y"] is bool:
					push_error("Stack piece" + stack_piece_name + " flip value is not a boolean!")
					return
				
				if not stack_piece_meta.has("piece_entry"):
					push_error("Stack piece" + stack_piece_name + " does not have a piece entry!")
					return
				
				if not stack_piece_meta["piece_entry"] is Dictionary:
					push_error("Stack piece" + stack_piece_name + " entry is not a dictionary!")
					return
				
				# Add the piece normally so we can extract the mesh instance and
				# shape.
				add_piece(stack_piece_name, Transform(), stack_piece_meta["piece_entry"])
				
				# Then add it to the stack at the top (since we're going through
				# the list in order from bottom to top).
				var flip = Stack.FLIP_NO
				if stack_piece_meta["flip_y"]:
					flip = Stack.FLIP_YES
				
				add_piece_to_stack(stack_piece_name, stack_name, Stack.STACK_TOP, flip)

# Get the next piece name.
# Returns: The next piece name.
func srv_get_next_piece_name() -> String:
	var next_name = str(_srv_next_piece_name)
	_srv_next_piece_name += 1
	return next_name

# Start sending the player's 3D cursor position to the server.
func start_sending_cursor_position() -> void:
	_camera_controller.send_cursor_position = true

# Create a Piece object out of a generic Spatial object.
# Returns: A Piece.
# piece: The Spatial object.
func _build_piece(piece: Spatial) -> Piece:
	var out = Piece.new()
	
	# Find the first MeshInstance in the piece scene, so we can get it's mesh
	# data to create a collision shape.
	var mesh_instance = _find_first_mesh_instance(piece)
	if mesh_instance:
		var collision_shape = CollisionShape.new()
		collision_shape.shape = mesh_instance.mesh.create_convex_shape()
		collision_shape.add_child(piece)
		out.add_child(collision_shape)
	else:
		push_error(piece.name + " does not have a mesh instance!")
	
	return out

# Find the first mesh instance node in a Spatial.
# Returns: The first mesh instance if it exists, null otherwise.
# piece: The Spatial to query.
func _find_first_mesh_instance(piece: Spatial):
	if piece is MeshInstance:
		return piece
	
	for child in piece.get_children():
		var found = _find_first_mesh_instance(child)
		if found is MeshInstance:
			return found
	
	return null

# Create a StackPieceInstance from a stackable piece, which can be put into a
# stack.
# Returns: A StackPieceInstance representing the piece's mesh instance.
# piece: The piece to use.
func _get_stack_piece_mesh(piece: StackablePiece) -> StackPieceInstance:
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

# Get the collision shape of a stackable piece.
# Returns: The piece's collision shape.
# piece: The piece to query.
func _get_stack_piece_shape(piece: StackablePiece) -> CollisionShape:
	var piece_collision_shape = piece.get_node("CollisionShape")
	if not piece_collision_shape:
		push_error("Piece " + piece.name + " does not have a CollisionShape child!")
		return null
	
	return piece_collision_shape

# Scale a piece by changing the scale of its children collision shapes.
# piece: The Spatial to scale.
# scale: How much to scale the piece by.
func _scale_piece(piece: Spatial, scale: Vector3) -> void:
	for child in piece.get_children():
		if child is CollisionShape:
			child.scale_object_local(scale)

func _on_piece_exiting_tree(piece: Piece) -> void:
	_camera_controller.erase_selected_pieces(piece)

func _on_stack_requested(piece1: StackablePiece, piece2: StackablePiece) -> void:
	if get_tree().is_network_server():
		if piece1 is Stack and piece2 is Stack:
			rpc("add_stack_to_stack", piece1.name, piece2.name)
		elif piece1 is Stack:
			rpc("add_piece_to_stack", piece2.name, piece1.name)
		elif piece2 is Stack:
			rpc("add_piece_to_stack", piece1.name, piece2.name)
		else:
			rpc("add_stack", srv_get_next_piece_name(), piece1.transform, piece1.name,
				piece2.name)

func _on_CameraController_cards_in_hand_requested(cards: Array):
	emit_signal("cards_in_hand_requested", cards)

func _on_CameraController_collect_pieces_requested(pieces: Array):
	var names = []
	for piece in pieces:
		if piece is StackablePiece:
			names.append(piece.name)
	rpc_id(1, "request_collect_pieces", names)

func _on_CameraController_hover_piece_requested(piece: Piece, offset: Vector3):
	rpc_id(1, "request_hover_piece", piece.name,
		_camera_controller.get_hover_position(), offset)

func _on_CameraController_pop_stack_requested(stack: Stack):
	rpc_id(1, "request_pop_stack", stack.name)

func _on_CameraController_stack_collect_all_requested(stack: Stack, collect_stacks: bool):
	rpc_id(1, "request_stack_collect_all", stack.name, collect_stacks)

func _on_CameraController_started_hovering_card(card: Card):
	emit_signal("started_hovering_card", card)

func _on_CameraController_stopped_hovering_card(card: Card):
	emit_signal("stopped_hovering_card", card)
