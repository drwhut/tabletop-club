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

# Usually, these would be onready variables, but since this object is always
# made in code, we set these variables before we need them.
var _collision_shape: CollisionShape = null
var _pieces: Spatial = null

var _collision_unit_height = 0

func add_piece_bottom(piece: StackPieceInstance, shape: Shape) -> void:
	_collision_shape = $CollisionShape
	_pieces = $Pieces
	_add_piece_at_pos(piece, shape, 0)

func add_piece_top(piece: StackPieceInstance, shape: Shape) -> void:
	_collision_shape = $CollisionShape
	_pieces = $Pieces
	_add_piece_at_pos(piece, shape, _pieces.get_child_count())

func _add_piece_at_pos(piece: StackPieceInstance, shape: Shape, pos: int) -> void:
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
	if transform.basis.y.dot(piece.transform.basis.y) < 0:
		basis = Basis.FLIP_Y
	
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
