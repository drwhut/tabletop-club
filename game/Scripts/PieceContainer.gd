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

extends Piece

class_name PieceContainer

signal absorbing_piece(container, piece)

onready var _pieces = $Pieces

# TODO: Have this property be configurable.
var opening_cone_angle: float = sin(deg2rad(30))

# Add a piece as a child to the container. Note that the piece cannot already
# have a parent!
# piece: The piece to add to the container.
func add_piece(piece: Piece) -> void:
	_pieces.add_child(piece)
	
	# Move the piece out of the way of the table so it is not visible, and make
	# sure it cannot move.
	piece.transform.origin = Vector3(9999, 9999, 9999)
	piece.mode = MODE_STATIC

func _ready():
	connect("body_entered", self, "_on_body_entered")

func _on_body_entered(body) -> void:
	if get_tree().is_network_server():
		
		# If a piece has collided with this container, then figure out if the
		# piece landed on top of us. If it did, then we can add it to the
		# container!
		if body is Piece:
			var disp = body.transform.origin - transform.origin
			
			# Check if the piece is hitting the top side of the container...
			if disp.dot(transform.basis.y) > 0:
				disp = disp.normalized()
				
				# Check if the piece is within the opening cone...
				if abs(disp.dot(transform.basis.x)) <= opening_cone_angle:
					if abs(disp.dot(transform.basis.z)) <= opening_cone_angle:
						emit_signal("absorbing_piece", self, body)
