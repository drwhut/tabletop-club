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

extends StackablePiece

class_name Card

# Used by hands so they know to release the card.
signal card_exiting_tree(card)

var over_hands: Array = []

# Check if the card will collide with other pieces.
# Returns: If the card will collide with other pieces.
func is_collisions_on() -> bool:
	return collision_mask == 1

# Called by the server to set whether the card will collide with other pieces.
# on: If the card will collide with other pieces.
remotesync func set_collisions_on(on: bool) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	var mask = 4
	if on:
		mask = 1
	collision_mask = mask

func _ready():
	connect("tree_exiting", self, "_on_tree_exiting")

func _on_tree_exiting():
	emit_signal("card_exiting_tree", self)
