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

extends Spatial

onready var _area = $Area

var _srv_cards = []

# Add a card to the hand. The card must not be hovering, as the operation makes
# the card hover.
# Returns: If the operation was successful.
# card: The card to add to the hand.
func srv_add_card(card: Card) -> bool:
	var init_pos = _area.global_transform.origin
	var success = card.srv_start_hovering(owner_id(), init_pos, Vector3.ZERO)
	if success:
		_srv_cards.append(card)
		card.connect("client_set_hover_position", self, "_on_client_set_card_position")
		
		# Set the rotation of the card to be in line with the hand.
		var new_basis = transform.basis
		if card.transform.basis.y.y < 0:
			new_basis = new_basis.rotated(transform.basis.z, PI)
		card.srv_hover_basis = new_basis
	return success

# Remove a card from the hand. This does not stop the card from hovering.
# card: The card to remove from the hand.
func srv_remove_card(card: Card) -> void:
	_srv_cards.erase(card)
	card.disconnect("client_set_hover_position", self, "_on_client_set_card_position")

# Get the ID of the player who owns this hand. The ID is based of the name of
# the node.
# Returns: The player's ID.
func owner_id() -> int:
	return int(name)

func _on_Area_body_entered(body: Node):
	if body.get("over_hand") != null:
		body.over_hand = owner_id()

func _on_Area_body_exited(body: Node):
	if body.get("over_hand") != null:
		body.over_hand = 0

func _on_client_set_card_position(card: Card):
	srv_remove_card(card)
