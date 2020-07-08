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

func add_piece(piece: StackPieceInstance, shape: Shape, on: int = STACK_AUTO,
	flip: int = FLIP_AUTO) -> void:
	
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

func get_pieces() -> Array:
	return _pieces.get_children()

func get_pieces_count() -> int:
	return _pieces.get_child_count()

func is_piece_flipped(piece: StackPieceInstance) -> bool:
	return transform.basis.y.dot(piece.transform.basis.y) < 0

func _add_piece_at_pos(piece: StackPieceInstance, shape: Shape, pos: int, flip: int) -> void:
	_pieces.add_child(piece)
	_pieces.move_child(piece, pos)
	
	if _pieces.get_child_count() == 1:
		piece_entry = piece.piece_entry
		
		if shape is BoxShape:
			var new_shape = BoxShape.new()
			new_shape.extents = shape.extents
			_collision_unit_height = shape.extents.y * 2
			
			_collision_shape.shape = new_shape
		else:
			push_error("Piece " + piece.name + " has an unsupported collision shape!")
	else:
		if _collision_shape.shape is BoxShape:
			_collision_shape.shape.extents.y += (_collision_unit_height / 2)
	
	var n = _pieces.get_child_count()
	var basis = Basis.IDENTITY
	
	if flip == FLIP_AUTO:
		if is_piece_flipped(piece):
			basis = Basis.FLIP_Y
		else:
			basis = Basis.IDENTITY
	elif flip == FLIP_NO:
		basis = Basis.IDENTITY
	elif flip == FLIP_YES:
		basis = Basis.FLIP_Y
	else:
		push_error("Invalid flip option " + str(flip) + "!")
		return
	
	piece.transform = Transform(basis, Vector3.ZERO)
	_set_piece_heights()
	
	# Adjust the collision shape's translation to match up with the pieces.
	# Avg(Y-position of pieces) = Sum(Y-position of pieces) / #Pieces
	_collision_shape.translation.y = _collision_unit_height * (n - 1) / 2

func _set_piece_heights() -> void:
	var i = 0
	for piece in _pieces.get_children():
		piece.transform.origin.y = _collision_unit_height * i
		i += 1
