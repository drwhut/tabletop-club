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

func add_piece_bottom(piece: StackablePiece) -> void:
	_collision_shape = $CollisionShape
	_pieces = $Pieces
	_add_piece_at_pos(piece, 0)

func add_piece_top(piece: StackablePiece) -> void:
	_collision_shape = $CollisionShape
	_pieces = $Pieces
	_add_piece_at_pos(piece, _pieces.get_child_count())

func _add_piece_at_pos(piece: StackablePiece, pos: int) -> void:
	_pieces.add_child(piece)
	_pieces.move_child(piece, pos)
	
	# Set the piece to static mode so it doesn't move on its own.
	piece.mode = RigidBody.MODE_STATIC
	
	# Set the layer and mask to 0 so it doesn't affect the collisions of any
	# other piece.
	piece.collision_layer = 0
	piece.collision_mask = 0
	
	if _pieces.get_child_count() == 1:
		piece_entry = piece.piece_entry
		
		var piece_collision_shape = piece.get_node("CollisionShape")
		if piece_collision_shape:
			var piece_shape = piece_collision_shape.shape
			
			if piece_shape is BoxShape:
				var new_shape = BoxShape.new()
				new_shape.extents = piece_shape.extents
				_collision_unit_height = piece_shape.extents.y * 2
				
				_collision_shape.shape = new_shape
			else:
				push_error("Piece " + piece.name + " has an unsupported collision shape!")
		else:
			push_error("Piece " + piece.name + " does not have a child CollisionShape!")
	else:
		if _collision_shape.shape is BoxShape:
			_collision_shape.shape.extents.y += (_collision_unit_height / 2)
	
	var n = _pieces.get_child_count()
	
	var y_pos = _collision_unit_height * (n - 1)
	piece.transform = Transform(Basis.IDENTITY, Vector3(0, y_pos, 0))
	
	# Adjust the collision shape's translation to match up with the pieces.
	# = Sum(Y-position of pieces) / #Pieces
	_collision_shape.translation.y = _collision_unit_height * (n - 1) / 2
