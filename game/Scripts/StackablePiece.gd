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

const DISTANCE_THRESHOLD = 1.0
const DOT_STACK_THRESHOLD = 0.9

func _ready():
	connect("body_entered", self, "_on_body_entered")

func _can_stack(body) -> bool:
	var me = transform
	var you = body.transform
	
	if (me.origin - you.origin).length() < DISTANCE_THRESHOLD:
		if abs(me.basis.y.dot(you.basis.y)) > DOT_STACK_THRESHOLD:
			if abs(me.basis.z.dot(you.basis.z)) > DOT_STACK_THRESHOLD:
				return true
	
	return false

func _on_body_entered(body):
	if get_tree().is_network_server():
		
		# We can't write "if body is StackablePiece", since according to Godot
		# that would cause a cyclic reference. So instead, we'll check to see
		# if it is a generic Piece, then check if the model used for the piece
		# is the same as ours, since we only want to stack items of the same
		# shape.
		if body is Piece:
			if body.piece_entry.model_path == piece_entry.model_path:
				if _can_stack(body):
					print("Stacking!")
