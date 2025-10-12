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

extends Stack

class_name StackLasagne

export(NodePath) var pieces_path: String

# Get the number of pieces in the stack.
# Returns: The number of pieces in the stack.
func get_piece_count() -> int:
	return _get_pieces_node().get_child_count()

# Get the current list of pieces in the stack.
# Returns: An array of dictionaries for every piece, containing "piece_entry"
# and "flip_y" elements.
func get_pieces() -> Array:
	var out = []
	for piece in _get_pieces_node().get_children():
		out.append({
			"piece_entry": piece.get_meta("piece_entry"),
			"flip_y": is_piece_flipped(piece.transform)
		})
	return out

# Called by the server to orient all of the pieces in the stack in a particular
# direction.
# up: Should all of the pieces be facing up?
remotesync func orient_pieces(up: bool) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	# Play sound effects.
	.orient_pieces(up)
	
	for piece in _get_pieces_node().get_children():
		var current_basis = piece.transform.basis
		
		if up and current_basis.y.y < 0:
			piece.transform.basis = current_basis.rotated(Vector3.BACK, PI)
		
		elif not up and current_basis.y.y > 0:
			piece.transform.basis = current_basis.rotated(Vector3.BACK, PI)

# Called by the server to set the order of pieces in the stack.
# order: The piece indicies in their new order.
remotesync func set_piece_order(order: Array) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	# Play sound effects.
	.set_piece_order(order)
	
	var pieces_node = _get_pieces_node()
	
	var old_piece_list = pieces_node.get_children()
	var new_piece_list = []
	for index in order:
		new_piece_list.append(old_piece_list[index])
	
	while pieces_node.get_child_count() > 0:
		var piece = pieces_node.get_child(0)
		pieces_node.remove_child(piece)
	
	for piece in new_piece_list:
		pieces_node.add_child(piece)
	
	_set_piece_heights()

# Add a piece to the stack at a given position.
# piece_entry: The piece entry of the piece to add.
# pos: The position of the new piece in the stack.
# flip_y: If the piece should be flipped when entering the stack.
func _add_piece_at_pos(piece_entry: Dictionary, pos: int, flip_y: bool) -> void:
	# TODO: Figure out a way to skip building the piece and directly get the
	# mesh instance.
	var piece = PieceBuilder.build_piece(piece_entry, false)
	var meshes = PieceBuilder.get_piece_meshes(piece)
	
	if meshes.size() != 1:
		push_error("Piece must have one and only one mesh instance!")
		return
	
	var collision_shapes = piece.get_collision_shapes()
	if collision_shapes.size() != 1:
		push_error("Piece must have one and only one collision shape!")
		return
	var collision_shape = collision_shapes[0]
	var collision_shape_scale = collision_shape.scale
	
	piece.free()
	
	var mesh_instance = meshes[0]
	_get_pieces_node().add_child(mesh_instance)
	_get_pieces_node().move_child(mesh_instance, pos)
	
	# The collision shape's y-scale is set to 1.0 so we can easily set the
	# height of the collision shape, but this means we need to put the y-scale
	# somewhere else, so to the pieces node it goes!
	_get_pieces_node().scale.y = collision_shape_scale.y
	
	var basis = mesh_instance.transform.basis
	if flip_y:
		basis = basis.rotated(Vector3.BACK, PI)
	
	var piece_scale = mesh_instance.scale
	mesh_instance.transform = Transform(basis, Vector3.ZERO)
	mesh_instance.scale = piece_scale
	
	_set_piece_heights()

# Get the pieces node that is the parent of all of the pieces.
# Returns: The pieces node.
func _get_pieces_node() -> Node:
	var node = get_node(pieces_path)
	if node is Node:
		return node
	
	return null

# Remove the piece at the given position from the stack.
# Returns: A dictionary containing "piece_entry" and "transform" elements,
# an empty dictionary if the stack is empty.
# pos: The position to remove the piece from.
func _remove_piece_at_pos(pos: int) -> Dictionary:
	var piece = _get_pieces_node().get_child(pos)
	_get_pieces_node().remove_child(piece)
	
	_set_piece_heights()
	
	var piece_transform = Transform.IDENTITY
	if piece.transform.basis.y.y < 0.0: # Was the piece flipped?
		piece_transform = piece_transform.rotated(Vector3.BACK, PI)
	
	var out = {
		"piece_entry": piece.get_meta("piece_entry"),
		"transform": piece_transform
	}
	
	ResourceManager.queue_free_object(piece)
	return out

# Set the y-position of the pieces in the stack.
func _set_piece_heights() -> void:
	var height = _mesh_unit_height * get_piece_count()
	var i = 0
	for piece in _get_pieces_node().get_children():
		piece.transform.origin.y = (_mesh_unit_height * (i + 0.5)) - (height / 2)
		
		# The Pieces node's scale will scale the translation here, so "undo"
		# the scale.
		if _get_pieces_node().scale.y != 0:
			piece.transform.origin.y /= _get_pieces_node().scale.y
		i += 1
