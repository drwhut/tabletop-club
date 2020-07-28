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

extends StackablePiece

class_name Stack

signal collect_all_requested(stack, collect_stacks)

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
onready var _pieces = $Pieces

var _collision_unit_height = 0
var _mesh_unit_height = 0

func add_context_to_control(control: Control) -> void:
	var collect_individuals_button = Button.new()
	collect_individuals_button.text = "Collect individuals"
	collect_individuals_button.connect("pressed", self, "_on_collect_individuals_pressed")
	control.add_child(collect_individuals_button)
	
	var collect_all_button = Button.new()
	collect_all_button.text = "Collect all"
	collect_all_button.connect("pressed", self, "_on_collect_all_pressed")
	control.add_child(collect_all_button)
	
	var orient_up_button = Button.new()
	orient_up_button.text = "Orient all up"
	orient_up_button.connect("pressed", self, "_on_orient_up_pressed")
	control.add_child(orient_up_button)
	
	var orient_down_button = Button.new()
	orient_down_button.text = "Orient all down"
	orient_down_button.connect("pressed", self, "_on_orient_down_pressed")
	control.add_child(orient_down_button)
	
	.add_context_to_control(control)

func add_piece(piece: StackPieceInstance, shape: CollisionShape,
	on: int = STACK_AUTO, flip: int = FLIP_AUTO) -> void:
	
	var on_top = false
	
	if on == STACK_AUTO:
		if transform.origin.y < piece.transform.origin.y:
			on_top = transform.basis.y.dot(Vector3.UP) > 0
		else:
			on_top = transform.basis.y.dot(Vector3.UP) < 0
	elif on == STACK_BOTTOM:
		on_top = false
	elif on == STACK_TOP:
		on_top = true
	else:
		push_error("Invalid stack option " + str(on) + "!")
		return
	
	var pos = 0
	if on_top:
		pos = _pieces.get_child_count()
	
	_add_piece_at_pos(piece, shape, pos, flip)

# NOTE: If you plan to remove the stack, but get the pieces of the stack (e.g.
# when putting one stack on top of another), use this function!
# This function exists as a workaround to a bug where the engine crashes when
# you change the collision shape of a rigidbody before removing it from the
# tree.
# See: https://github.com/godotengine/godot/issues/40283
func empty() -> Array:
	var out = []
	
	for piece in _pieces.get_children():
		_pieces.remove_child(piece)
		out.push_back(piece)
	
	return out

func get_pieces() -> Array:
	return _pieces.get_children()

func get_piece_count() -> int:
	return _pieces.get_child_count()

func get_total_height() -> float:
	if _collision_shape.shape is BoxShape:
		return _collision_shape.shape.extents.y * 2
	elif _collision_shape.shape is CylinderShape:
		return _collision_shape.shape.height
	
	return 0.0

func get_unit_height() -> float:
	return _collision_unit_height

func is_piece_flipped(piece: StackPieceInstance) -> bool:
	return transform.basis.y.dot(piece.transform.basis.y) < 0

remotesync func orient_pieces(up: bool) -> void:
	for piece in get_pieces():
		var current_basis = piece.transform.basis
		
		if up and current_basis.y.dot(Vector3.UP) < 0:
			piece.transform.basis = current_basis.rotated(Vector3.BACK, PI)
		
		elif not up and current_basis.y.dot(Vector3.UP) > 0:
			piece.transform.basis = current_basis.rotated(Vector3.BACK, PI)

func pop_piece(from: int = STACK_AUTO) -> StackPieceInstance:
	if _pieces.get_child_count() == 0:
		return null
	
	var pos = 0
	
	if from == STACK_AUTO:
		if transform.basis.y.dot(Vector3.UP) > 0:
			pos = _pieces.get_child_count() - 1
		else:
			pos = 0
	elif from == STACK_BOTTOM:
		pos = 0
	elif from == STACK_TOP:
		pos = _pieces.get_child_count() - 1
	else:
		push_error("Invalid from option " + str(from) + "!")
		return null
	
	return _remove_piece_at_pos(pos)

func remove_piece(piece: StackPieceInstance) -> void:
	if _pieces.is_a_parent_of(piece):
		_remove_piece_at_pos(piece.get_index())
	else:
		push_error("Piece " + piece.name + " is not a child of this stack!")
		return

puppet func remove_piece_by_name(name: String) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	var piece = _pieces.get_node(name)
	
	if not piece:
		push_error("Piece " + name + " is not in the stack!")
		return
	
	remove_piece(piece)

master func request_orient_pieces(up: bool) -> void:
	# If the stack is upside down, orient the opposite direction.
	if transform.basis.y.dot(Vector3.UP) < 0:
		up = !up
	
	rpc("orient_pieces", up)

func _add_piece_at_pos(piece: StackPieceInstance, shape: CollisionShape,
	pos: int, flip: int) -> void:
	
	_pieces.add_child(piece)
	_pieces.move_child(piece, pos)
	
	if _pieces.get_child_count() == 1:
		piece_entry = piece.piece_entry
		
		_mesh_unit_height = piece.scale.y
		
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
	else:
		var current_height = get_total_height()
		var new_height = _mesh_unit_height * _pieces.get_child_count()
		var extra_height = max(new_height - current_height, 0)
		
		if _collision_shape.shape is BoxShape:
			_collision_shape.shape.extents.y += (extra_height / 2)
		elif _collision_shape.shape is CylinderShape:
			_collision_shape.shape.height += extra_height
	
	var n = _pieces.get_child_count()
	var is_flipped = false
	
	if flip == FLIP_AUTO:
		if is_piece_flipped(piece):
			is_flipped = true
		else:
			is_flipped = false
	elif flip == FLIP_NO:
		is_flipped = false
	elif flip == FLIP_YES:
		is_flipped = true
	else:
		push_error("Invalid flip option " + str(flip) + "!")
		return
	
	var basis = Basis.IDENTITY
	if is_flipped:
		basis = basis.rotated(Vector3.BACK, PI)
	
	var piece_scale = piece.scale
	piece.transform = Transform(basis, Vector3.ZERO)
	piece.scale = piece_scale
	
	_set_piece_heights()

func _on_collect_all_pressed() -> void:
	emit_signal("collect_all_requested", self, true)

func _on_collect_individuals_pressed() -> void:
	emit_signal("collect_all_requested", self, false)

func _on_orient_down_pressed() -> void:
	rpc_id(1, "request_orient_pieces", false)

func _on_orient_up_pressed() -> void:
	rpc_id(1, "request_orient_pieces", true)

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
	
	_set_piece_heights()
	
	return piece

func _set_piece_heights() -> void:
	var height = _mesh_unit_height * _pieces.get_child_count()
	var i = 0
	for piece in _pieces.get_children():
		piece.transform.origin.y = (_mesh_unit_height * (i + 0.5)) - (height / 2)
		i += 1
