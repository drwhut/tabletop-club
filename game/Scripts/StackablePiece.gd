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

extends Piece

class_name StackablePiece

signal stack_requested(piece1, piece2)

const DISTANCE_THRESHOLD = 1.0
const DOT_STACK_THRESHOLD = 0.9

var _ignore_y_rotation = false

# Check if another piece has a matching shape and scale.
# Returns: If the other piece has a matching shape and scale.
# body: The piece to check against.
func matches(body: Piece) -> bool:
	if body.piece_entry.scene_path == piece_entry.scene_path:
		if body.piece_entry.scale == piece_entry.scale:
			return true
	
	return false

func _ready():
	connect("body_entered", self, "_on_body_entered")

# Can this piece stack with another piece?
# Returns: If the piece can stack with the other piece.
# body: The piece to check against.
func _can_stack(body: Spatial) -> bool:
	var me = transform
	var you = body.transform
	
	# Ignore the y-axis when determining the distance, as stacks can get
	# physically bigger.
	var me_xz = me.origin
	var you_xz = you.origin
	me_xz.y = 0
	you_xz.y = 0
	
	if (me_xz - you_xz).length() < DISTANCE_THRESHOLD:
		if abs(me.basis.y.dot(you.basis.y)) > DOT_STACK_THRESHOLD:
			if _ignore_y_rotation or abs(me.basis.z.dot(you.basis.z)) > DOT_STACK_THRESHOLD:
				return true
	
	return false

func _on_body_entered(body) -> void:
	# This check is needed, as stackable pieces can move in and out of the
	# scene tree when they are being moved in and out of stacks.
	if get_tree() != null:
		if get_tree().is_network_server():
			
			# We can't write "if body is StackablePiece", since according to
			# Godot that would cause a cyclic reference. So instead, we'll check
			# to see if it is a generic Piece, then check if the model used for
			# the piece is the same as ours, since we only want to stack items
			# of the same shape.
			if body is Piece:
				if not (srv_is_hovering() or body.srv_is_hovering()):
					if matches(body) and _can_stack(body):
						emit_signal("stack_requested", self, body)
