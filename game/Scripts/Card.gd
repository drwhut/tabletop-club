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

extends StackablePiece

class_name Card

var _srv_place_aside_player: int = 0

# Bring back the card if it has been set aside.
# new_transform: The transform of the card once it has been brought back.
remotesync func bring_back(new_transform: Transform) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	_srv_place_aside_player = 0
	
	transform = new_transform
	mode = MODE_RIGID
	
	# Delete the last saved server state, otherwise the card will lerp to the
	# new position.
	_last_server_state = {}

# Place aside the card so that it is out of sight, and it will not move.
# player_id: The ID of the player setting aside the card. The card can only be
# brought back by the player with the same ID.
remotesync func place_aside(player_id: int) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	if get_tree().is_network_server():
		_srv_place_aside_player = player_id
	
	transform.origin = Vector3(9999, 9999, 9999)
	mode = MODE_STATIC

# Get the player that set aside the card.
# Returns: The player that set aside the card. 0 if the card has not been set
# aside.
func srv_get_place_aside_player() -> int:
	return _srv_place_aside_player

# Has the card been set aside?
# Returns: If the card has been set aside.
func srv_is_placed_aside() -> bool:
	return _srv_place_aside_player > 0

func _ready():
	_mesh_instance = $CollisionShape/MeshInstance
