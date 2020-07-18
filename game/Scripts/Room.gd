# open-tabletop
# Copyright (c) 2020 drwhut
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

signal started_hovering_card(card)
signal stopped_hovering_card(card)

onready var _camera_controller = $CameraController
onready var _pieces = $Pieces

var _hovering_piece: Piece = null
var _srv_next_piece_name = 0

remotesync func add_piece(name: String, transform: Transform,
	piece_entry: Dictionary, hover_player: int = 0) -> void:
	
	if get_tree().get_rpc_sender_id() != 1:
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
	if piece is Card:
		piece_entry["scale"].y = 1
	_scale_piece(piece, piece_entry["scale"])
	
	_pieces.add_child(piece)
	
	# If it is a stackable piece, make sure we attach the signal it emits when
	# it wants to create a stack.
	if piece is StackablePiece:
		piece.connect("stack_requested", self, "_on_stack_requested")
	
	# Apply a generic texture to the die.
	if piece_entry["texture_path"]:
		var texture: Texture = load(piece_entry["texture_path"])
		texture.set_flags(0)
		
		piece.apply_texture(texture)
	
	if get_tree().is_network_server() and hover_player > 0:
		piece.srv_start_hovering(hover_player)

remotesync func add_piece_to_stack(piece_name: String, stack_name: String,
	on: int = Stack.FLIP_AUTO, flip: int = Stack.FLIP_AUTO) -> void:
	
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
	
	# Should the stack be shuffleable?
	var shuffleable = false
	
	if (piece1 is Card and piece2 is Card):
		shuffleable = true
	
	var stack = add_stack_empty(name, transform, shuffleable)
	
	stack.add_piece(piece1_mesh, piece1_shape)
	stack.add_piece(piece2_mesh, piece2_shape)
	
	piece1.queue_free()
	piece2.queue_free()

puppet func add_stack_empty(name: String, transform: Transform,
	shuffleable: bool = false) -> Stack:
	
	if get_tree().get_rpc_sender_id() != 1:
		return null
	
	var stack: Stack = null
	if shuffleable:
		stack = preload("res://Pieces/ShuffleableStack.tscn").instance()
	else:
		stack = preload("res://Pieces/Stack.tscn").instance()
	
	stack.name = name
	stack.transform = transform
	
	_pieces.add_child(stack)
	
	# Attach the signal for when it wants to stack with another piece.
	stack.connect("stack_requested", self, "_on_stack_requested")
	
	return stack

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
	if stack1.get_pieces_count() == 0:
		return
	
	# We need to determine in which order to add the children of the first stack
	# to the second stack.
	# NOTE: In stacks, children are stored bottom-first.
	var reverse = false
	
	if stack1.transform.origin.y > stack2.transform.origin.y:
		reverse = stack1.transform.basis.y.dot(Vector3.DOWN) > 0
	else:
		reverse = stack1.transform.basis.y.dot(Vector3.UP) > 0
	
	# Next we need to supply a unit collision shape to the second stack.
	var shape = _get_stack_piece_shape(stack1)
	var new_shape: Shape = null
	
	if shape is BoxShape:
		new_shape = BoxShape.new()
		new_shape.extents = shape.extents
		new_shape.extents.y /= stack1.get_pieces_count()
	else:
		push_error("Stack " + stack1_name + " has an unsupported collision shape!")
	
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
		
		stack2.add_piece(piece, new_shape)
	
	# Finally, delete the first stack.
	_pieces.remove_child(stack1)
	stack1.queue_free()

func get_camera_hover_position() -> Vector3:
	return _camera_controller.get_hover_position()

func get_piece_with_name(name: String) -> Piece:
	return _pieces.get_node(name)

func get_pieces() -> Array:
	return _pieces.get_children()

func get_piece_count() -> int:
	return _pieces.get_child_count()

func get_state() -> Dictionary:
	var out = {}
	
	var piece_dict = {}
	var stack_dict = {}
	for piece in _pieces.get_children():
		if piece is Stack:
			var stack_meta = {
				"is_shuffleable": piece is ShuffleableStack,
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
				"piece_entry": piece.piece_entry,
				"transform": piece.transform
			}
			
			piece_dict[piece.name] = piece_meta
	
	out["pieces"] = piece_dict
	out["stacks"] = stack_dict
	return out

master func request_hover_piece(piece_name: String) -> void:
	
	var piece = _pieces.get_node(piece_name)
	
	if not piece:
		push_error("Piece " + piece_name + " does not exist!")
		return
	
	if not piece is Piece:
		push_error("Object " + piece_name + " is not a piece!")
		return
	
	var player_id = get_tree().get_rpc_sender_id()
	
	if piece.srv_start_hovering(player_id):
		rpc_id(player_id, "request_hover_piece_accepted", piece_name)

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
	
	_camera_controller.set_is_hovering_piece(true)
	_hovering_piece = piece
	
	# Immediately set the piece's hover position.
	piece.rpc_unreliable_id(1, "set_hover_position", _camera_controller.get_hover_position())
	
	if piece is Card:
		emit_signal("started_hovering_card", piece)

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
	
	if stack.get_pieces_count() == 0:
		return
	elif stack.get_pieces_count() == 1:
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
		var new_origin = stack.transform.origin + piece_instance.transform.origin
		
		# If this piece will hover, get it away from the stack so it doesn't
		# immediately collide with it again.
		# TODO: Use the stack's unit height!
		if hover:
			new_origin.y += 2
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
	if stack.get_pieces_count() == 1:
		request_pop_stack(stack_name, false)

remotesync func request_pop_stack_accepted(piece_name: String) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	# The server has allowed us to hover the piece that has just poped off the
	# stack!
	request_hover_piece_accepted(piece_name)

puppet func set_state(state: Dictionary) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	# Delete all the pieces on the board currently before we begin.
	for child in _pieces.get_children():
		remove_child(child)
	
	if state.has("pieces"):
		for piece_name in state["pieces"]:
			var piece_meta = state["pieces"][piece_name]
			
			if not piece_meta.has("transform"):
				push_error("Piece " + piece_name + " in new state has no transform!")
				return
			
			if not piece_meta["transform"] is Transform:
				push_error("Piece " + piece_name + " transform is not a transform!")
				return
			
			if not piece_meta.has("piece_entry"):
				push_error("Piece " + piece_name + " in new state has no piece entry!")
				return
			
			if not piece_meta["piece_entry"] is Dictionary:
				push_error("Piece " + piece_name + " entry is not a dictionary!")
				return
			
			add_piece(piece_name, piece_meta["transform"], piece_meta["piece_entry"])
	
	if state.has("stacks"):
		for stack_name in state["stacks"]:
			var stack_meta = state["stacks"][stack_name]
			
			if not stack_meta.has("is_shuffleable"):
				push_error("Stack " + stack_name + " in new state has no is shuffleable value!")
				return
			
			if not stack_meta["is_shuffleable"] is bool:
				push_error("Stack " + stack_name + " is shuffleable value is not a boolean!")
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
			
			var stack = add_stack_empty(stack_name, stack_meta["transform"],
				stack_meta["is_shuffleable"])
			
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

func srv_get_next_piece_name() -> String:
	var next_name = str(_srv_next_piece_name)
	_srv_next_piece_name += 1
	return next_name

func _build_piece(piece: Spatial) -> Piece:
	var out = Piece.new()
	out.add_child(piece)
	
	# Find the first MeshInstance in the piece scene, so we can get it's mesh
	# data to create a collision shape.
	var mesh_instance = _find_first_mesh_instance(piece)
	if mesh_instance:
		var collision_shape = CollisionShape.new()
		collision_shape.shape = mesh_instance.mesh.create_convex_shape()
		out.add_child(collision_shape)
	else:
		push_error(piece.name + " does not have a mesh instance!")
	
	return out

func _find_first_mesh_instance(piece: Spatial):
	if piece is MeshInstance:
		return piece
	
	for child in piece.get_children():
		var found = _find_first_mesh_instance(child)
		if found is MeshInstance:
			return found
	
	return null

func _get_stack_piece_mesh(piece: StackablePiece) -> StackPieceInstance:
	var piece_mesh = StackPieceInstance.new()
	piece_mesh.name = piece.name
	piece_mesh.transform = piece.transform
	piece_mesh.piece_entry = piece.piece_entry
	
	var piece_mesh_inst = piece.get_node("MeshInstance")
	if not piece_mesh_inst:
		push_error("Piece " + piece.name + " does not have a MeshInstance child!")
		return null
	
	# Get the scale from the mesh instance (since the rigid body itself won't be
	# scaled).
	piece_mesh.scale = piece_mesh_inst.scale
	
	piece_mesh.mesh = piece_mesh_inst.mesh
	piece_mesh.set_surface_material(0, piece_mesh_inst.get_surface_material(0))
	
	return piece_mesh

func _get_stack_piece_shape(piece: StackablePiece) -> Shape:
	var piece_collision_shape = piece.get_node("CollisionShape")
	if not piece_collision_shape:
		push_error("Piece " + piece.name + " does not have a CollisionShape child!")
		return null
	
	return piece_collision_shape.shape

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

func _scale_piece(piece: Spatial, scale: Vector3) -> void:
	if piece is CollisionShape or piece is MeshInstance:
		piece.scale = scale
	
	for child in piece.get_children():
		_scale_piece(child, scale)

func _on_CameraController_flipped_piece():
	if _hovering_piece:
		_hovering_piece.rpc_id(1, "flip_vertically")

func _on_CameraController_new_hover_position(position: Vector3):
	if _hovering_piece:
		_hovering_piece.rpc_unreliable_id(1, "set_hover_position", position)

func _on_CameraController_reset_piece():
	if _hovering_piece:
		_hovering_piece.rpc_id(1, "reset_orientation")

func _on_CameraController_started_hovering(piece: Piece, fast: bool):
	if piece is Stack and fast:
		rpc_id(1, "request_pop_stack", piece.name)
	else:
		rpc_id(1, "request_hover_piece", piece.name)

func _on_CameraController_stopped_hovering():
	if _hovering_piece:
		if _hovering_piece is Card:
			emit_signal("stopped_hovering_card", _hovering_piece)
		
		_hovering_piece.rpc_id(1, "stop_hovering")
		_hovering_piece = null
