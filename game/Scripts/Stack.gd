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

extends StackablePiece

class_name Stack

enum {
	STACK_AUTO,
	STACK_BOTTOM,
	STACK_TOP
}

enum {
	FLIP_AUTO,
	FLIP_NO,
	FLIP_YES
}

# Usually, these would be onready variables, but since this object is always
# made in code, we set these variables before we need them.
onready var _collision_shape = $CollisionShape
onready var _pieces = $CollisionShape/Pieces

var _collision_unit_height = 0
var _mesh_unit_height = 0

# Add a piece to the stack.
# piece: The stack piece instance to add.
# shape: The shape of the piece.
# on: Where to add the piece in the stack.
# flip: Whether the piece should be flipped when entering the stack.
func add_piece(piece: StackPieceInstance, shape: CollisionShape,
	on: int = STACK_AUTO, flip: int = FLIP_AUTO) -> void:
	
	var on_top = false
	
	match on:
		STACK_AUTO:
			if transform.origin.y < piece.transform.origin.y:
				on_top = transform.basis.y.y > 0
			else:
				on_top = transform.basis.y.y < 0
		STACK_BOTTOM:
			on_top = false
		STACK_TOP:
			on_top = true
		_:
			push_error("Invalid stack option " + str(on) + "!")
			return
	
	var pos = 0
	if on_top:
		pos = _pieces.get_child_count()
	
	_add_piece_at_pos(piece, shape, pos, flip)

# Empty the stack.
# NOTE: If you plan to remove the stack, but get the pieces of the stack (e.g.
# when putting one stack on top of another), use this function!
# This function exists as a workaround to a bug where the engine crashes when
# you change the collision shape of a rigidbody before removing it from the
# tree.
# See: https://github.com/godotengine/godot/issues/40283
# Returns: The stack piece instances.
func empty() -> Array:
	var out = []
	
	for piece in _pieces.get_children():
		_pieces.remove_child(piece)
		out.push_back(piece)
	
	return out

# Get the pieces in the stack.
# Returns: The pieces in the stack.
func get_pieces() -> Array:
	return _pieces.get_children()

# Get the number of pieces in the stack.
# Returns: The number of pieces in the stack.
func get_piece_count() -> int:
	return _pieces.get_child_count()

# Get the height of the collision shape.
# Returns: The height of the collision shape.
func get_total_height() -> float:
	if _collision_shape.shape is BoxShape:
		return _collision_shape.shape.extents.y * 2
	elif _collision_shape.shape is CylinderShape:
		return _collision_shape.shape.height
	
	return 0.0

# Get the unit height of the collision shape, i.e. how much height one piece
# contributes to the total height.
# Returns: The unit collision height.
func get_unit_height() -> float:
	return _collision_unit_height

# Is the piece's orientation flipped relative to the stack's orientation?
# Returns: If the piece's orientation if flipped.
# piece: The stack piece instance to query.
func is_piece_flipped(piece: StackPieceInstance) -> bool:
	return transform.basis.y.dot(piece.transform.basis.y) < 0

# Called by the server to orient all of the pieces in the stack in a particular
# direction.
# up: Should all of the pieces be facing up?
remotesync func orient_pieces(up: bool) -> void:
	for piece in get_pieces():
		var current_basis = piece.transform.basis
		
		if up and current_basis.y.y < 0:
			piece.transform.basis = current_basis.rotated(Vector3.BACK, PI)
		
		elif not up and current_basis.y.y > 0:
			piece.transform.basis = current_basis.rotated(Vector3.BACK, PI)

# Pop a piece from the stack.
# Returns: The stack piece instance that was poped.
# from: Where to pop the stack from.
func pop_piece(from: int = STACK_AUTO) -> StackPieceInstance:
	if _pieces.get_child_count() == 0:
		return null
	
	var pos = 0
	
	match from:
		STACK_AUTO:
			if transform.basis.y.y > 0:
				pos = _pieces.get_child_count() - 1
			else:
				pos = 0
		STACK_BOTTOM:
			pos = 0
		STACK_TOP:
			pos = _pieces.get_child_count() - 1
		_:
			push_error("Invalid from option " + str(from) + "!")
			return null
	
	return _remove_piece_at_pos(pos)

# Remove a piece from the stack.
# piece: The stack piece instance to remove.
func remove_piece(piece: StackPieceInstance) -> void:
	if _pieces.is_a_parent_of(piece):
		_remove_piece_at_pos(piece.get_index())
	else:
		push_error("Piece " + piece.name + " is not a child of this stack!")
		return

# Called by the server to remove a piece from the stack by it's name.
# name: The name of the stack piece instance to remove.
puppet func remove_piece_by_name(name: String) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	var piece = _pieces.get_node(name)
	
	if not piece:
		push_error("Piece " + name + " is not in the stack!")
		return
	
	remove_piece(piece)

# Request the server to orient all of the pieces in the stack in a particular
# direction.
# up: Should all of the pieces be facing up?
master func request_orient_pieces(up: bool) -> void:
	# If the stack is upside down, orient the opposite direction.
	if transform.basis.y.y < 0:
		up = !up
	
	rpc("orient_pieces", up)

# Request the server to shuffle the stack.
master func request_shuffle() -> void:
	var names = []
	for piece in get_pieces():
		names.push_back(piece.name)
	
	randomize()
	names.shuffle()
	
	rpc("set_piece_order", names)

# Request the server to sort the stack by texture path.
master func request_sort() -> void:
	var items = []
	for piece in get_pieces():
		items.append({
			"name": piece.name,
			"texture_path": piece.piece_entry.texture_path
		})
	var items2 = items.duplicate()
	
	_merge_sort(items, items2, 0, items.size())
	
	var names = []
	for item in items:
		names.push_back(item.name)
	
	rpc("set_piece_order", names)

# Set the stack to appear like it is selected.
# selected: Should the stack appear like it is selected?
func set_appear_selected(selected: bool) -> void:
	for piece in get_pieces():
		piece.set_appear_selected(selected)

# Called by the server to set the order of the pieces in the stack.
# order: The piece names in their new order.
remotesync func set_piece_order(order: Array) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	var i = 0
	for piece_name in order:
		var node = _pieces.get_node(piece_name)
		
		if node:
			_pieces.move_child(node, i)
		
		i += 1
	
	_set_piece_heights()

func _physics_process(delta):
	# If the stack is being shaken, then get the server to send a list of
	# shuffled names to each client (including itself).
	if get_tree().is_network_server() and is_being_shaked():
		request_shuffle()

# Add a piece to the stack at a given position.
# piece: The stack piece instance to add.
# shape: The piece's collision shape.
# pos: The position of the new piece in the stack.
# flip: Whether the piece should be flipped or not.
func _add_piece_at_pos(piece: StackPieceInstance, shape: CollisionShape,
	pos: int, flip: int) -> void:
	
	_pieces.add_child(piece)
	_pieces.move_child(piece, pos)
	
	if _pieces.get_child_count() == 1:
		piece_entry = piece.piece_entry
		
		var new_shape: Shape = null
		
		if shape.shape is BoxShape:
			new_shape = BoxShape.new()
			new_shape.extents = shape.shape.extents
			new_shape.extents.y *= shape.scale.y
			
			_collision_unit_height = new_shape.extents.y * 2
		elif shape.shape is CylinderShape:
			new_shape = CylinderShape.new()
			new_shape.height = shape.shape.height * shape.scale.y
			new_shape.radius = shape.shape.radius
			
			_collision_unit_height = new_shape.height
		else:
			push_error("Piece " + piece.name + " has an unsupported collision shape!")
		
		if new_shape:
			_collision_shape.shape = new_shape
			_collision_shape.scale = Vector3(shape.scale.x, 1, shape.scale.z)
			
			# We want to keep the collision's shape y-scale at 1 so we can
			# change the collision shape's height easily without having to deal
			# with the scale, but we still need to scale the instances properly,
			# so put the y-scale in the Pieces node.
			_pieces.scale.y = shape.scale.y
			
			_mesh_unit_height = shape.scale.y * piece.scale.y
	else:
		var current_height = get_total_height()
		var new_height = _mesh_unit_height * _pieces.get_child_count()
		var extra_height = max(new_height - current_height, 0)
		
		if _collision_shape.shape is BoxShape:
			_collision_shape.shape.extents.y += (extra_height / 2)
		elif _collision_shape.shape is CylinderShape:
			_collision_shape.shape.height += extra_height
	
	# We just changed the collision shape, so make sure the stack is awake.
	sleeping = false
	
	mass += piece.piece_entry["mass"]
	
	var is_flipped = false
	match flip:
		FLIP_AUTO:
			if is_piece_flipped(piece):
				is_flipped = true
			else:
				is_flipped = false
		FLIP_NO:
			is_flipped = false
		FLIP_YES:
			is_flipped = true
		_:
			push_error("Invalid flip option " + str(flip) + "!")
			return
	
	var basis = Basis.IDENTITY
	if is_flipped:
		basis = basis.rotated(Vector3.BACK, PI)
	
	var piece_scale = piece.scale
	piece.transform = Transform(basis, Vector3.ZERO)
	piece.scale = piece_scale
	
	_set_piece_heights()

# Remove the piece at the given position.
# Returns: The stack piece instance at the given position.
# pos: The position to remove from.
func _remove_piece_at_pos(pos: int) -> StackPieceInstance:
	if pos < 0 or pos >= _pieces.get_child_count():
		push_error("Cannot remove " + str(pos) + "th child from the stack!")
		return null
	
	var piece = _pieces.get_child(pos)
	_pieces.remove_child(piece)
	
	# Re-calculate the stacks collision shape.
	var current_height = get_total_height()
	var new_height = max(_mesh_unit_height * _pieces.get_child_count(), _collision_unit_height)
	var height_lost = max(current_height - new_height, 0)
	
	if _collision_shape.shape is BoxShape:
		_collision_shape.shape.extents.y -= (height_lost / 2)
	elif _collision_shape.shape is CylinderShape:
		_collision_shape.shape.height -= height_lost
	else:
		push_error("Stack has an unsupported collision shape!")
		return null
	
	# We just changed the collision shape, so make sure the stack is awake.
	sleeping = false
	
	mass -= piece.piece_entry["mass"]
	
	_set_piece_heights()
	
	return piece

# Set the y-position of the pieces in the stack.
func _set_piece_heights() -> void:
	var height = _mesh_unit_height * _pieces.get_child_count()
	var i = 0
	for piece in _pieces.get_children():
		piece.transform.origin.y = (_mesh_unit_height * (i + 0.5)) - (height / 2)
		
		# The Pieces node's scale will scale the translation here, so "undo"
		# the scale.
		if _pieces.scale.y != 0:
			piece.transform.origin.y /= _pieces.scale.y
		i += 1

# Use the merge sort algorithm to sort the pieces by their texture paths.
# array: The array to sort.
# copy: A copy of the original array.
# begin: The beginning of the merge sort (inclusive).
# end: The end of the merge sort (exclusive).
func _merge_sort(array: Array, copy: Array, begin: int, end: int) -> void:
	if end - begin <= 1:
		return
	
	var middle = int(float(begin + end) / 2)
	
	_merge_sort(copy, array, begin, middle)
	_merge_sort(copy, array, middle, end)
	
	var i = begin
	var j = middle
	
	for k in range(begin, end):
		# Sort the children by their texture paths.
		if i < middle and (j >= end or copy[i].texture_path <= copy[j].texture_path):
			array[k] = copy[i]
			i += 1
		else:
			array[k] = copy[j]
			j += 1
