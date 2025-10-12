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

extends Spatial

onready var _area = $Area
onready var _area_collision_shape = $Area/CollisionShape
onready var _effect_player = $EffectPlayer
onready var _mesh_instance = $Area/CollisionShape/MeshInstance
onready var _name_label = $NamePlate/Viewport/MarginContainer/NameLabel

const CARD_HEIGHT_DIFF = 0.01

# TODO: export(RandomAudioSample)
# See: https://github.com/godotengine/godot/pull/44879
export(Resource) var hand_sounds

var _srv_cards = []

# Get the ID of the player who owns this hand. The ID is based of the name of
# the node.
# Returns: The player's ID.
func owner_id() -> int:
	return int(name)

# Play a random hand sound.
remotesync func play_hand_sound() -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	if _effect_player.playing:
		return
	
	var hand_sound = hand_sounds.random_stream()
	if hand_sound:
		_effect_player.stream = hand_sound
		_effect_player.play()

# Add a card to the hand. The card must not be hovering, as the operation makes
# the card hover.
# Returns: If the operation was successful.
# card: The card to add to the hand.
func srv_add_card(card: Card) -> bool:
	if _srv_cards.has(card):
		return true
	
	var init_pos = _area.global_transform.origin
	var success = card.srv_start_hovering(owner_id(), init_pos, Vector3.ZERO)
	if success:
		var new_lambda = _right_angle_displacement(card)
		var pos = 0
		for hand_card in _srv_cards:
			var card_lambda = _right_angle_displacement(hand_card)
			if card_lambda > new_lambda:
				break
			pos += 1
		
		_srv_cards.insert(pos, card)
		_srv_set_card_positions()
		
		card.connect("client_set_hover_position", self, "_on_client_set_card_position")
		card.connect("card_exiting_tree", self, "_on_card_exiting_tree")
		
		card.rpc("set_collisions_on", false)
		
		_srv_set_card_rotation(card)
		
		rpc("play_hand_sound")
	
	return success

# Remove all cards from the hand. This does not stop the cards from hovering.
# play_sound: Should the hand play a sound effect when removing the cards?
func srv_clear_cards(play_sound: bool = true) -> void:
	for i in range(_srv_cards.size() - 1, -1, -1):
		srv_remove_card(_srv_cards[i], play_sound)

# Remove a card from the hand. This does not stop the card from hovering.
# card: The card to remove from the hand.
# play_sound: Should the hand play a sound effect?
func srv_remove_card(card: Card, play_sound: bool = true) -> void:
	_srv_cards.erase(card)
	_srv_set_card_positions()
	
	card.disconnect("client_set_hover_position", self, "_on_client_set_card_position")
	card.disconnect("card_exiting_tree", self, "_on_card_exiting_tree")
	
	# The card may be removed because the game is exiting!
	if get_tree().has_network_peer():
		card.rpc("set_collisions_on", true)
		if play_sound:
			rpc("play_hand_sound")

# Update the display of the hand to reflect the owner's properties, such as
# their colour.
func update_owner_display() -> void:
	var player = Lobby.get_player(owner_id())
	if player.size() == 0:
		return
	
	var material = _mesh_instance.get_surface_material(0)
	if material:
		var a = material.albedo_color.a
		material.albedo_color = player["color"]
		material.albedo_color.a = a
	
	_name_label.bbcode_text = "[center]" + Lobby.get_name_bb_code(owner_id()) + "[/center]"

# Update the hand's transform, along with the card's.
remotesync func update_transform(new_transform: Transform) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	transform = new_transform
	
	if get_tree().is_network_server():
		_srv_set_card_positions()
		
		for card in _srv_cards:
			_srv_set_card_rotation(card)

func _ready():
	# Each hand should have a different material since they will probably have
	# different albedo colours because of the players ability to pick different
	# colours.
	var material = _mesh_instance.get_surface_material(0)
	if material:
		_mesh_instance.set_surface_material(0, material.duplicate())
	
	Lobby.connect("player_modified", self, "_on_Lobby_player_modified")

# Get the displacement along the hand's "line" to the point where it is closest
# to the given card.
# Returns: The displacement.
# card: The card to get as close as possible to.
func _right_angle_displacement(card: Card) -> float:
	var card_dist = card.transform.origin - _area.global_transform.origin
	var hand_right = transform.basis.x
	return card_dist.dot(hand_right)

# Recursively set the front face visibility of a node by scanning the children
# for mesh instances.
# body: The node to start from.
# visible: Whether the front face should be visible or not.
func _set_front_face_visible_recursive(node: Node, visible: bool) -> void:
	if node is MeshInstance:
		var material = node.get_surface_material(0)
		if material is SpatialMaterial:
			material.uv1_scale = Vector3.ONE if visible else Vector3.ZERO
	
	for child in node.get_children():
		_set_front_face_visible_recursive(child, visible)

# Set the hover positions of the hand's cards.
func _srv_set_card_positions() -> void:
	if _srv_cards.empty() or (not _area.is_inside_tree()):
		return
	
	var total_width = 0
	var widths = []
	for card in _srv_cards:
		var card_width = card.piece_entry["scale"].x
		total_width += card_width
		widths.append(card_width)
	
	var hand_width = _area_collision_shape.scale.x
	var offset_begin = max((hand_width-total_width) / 2, 0) + (widths[0] / 2)
	var offset_other = 0
	if _srv_cards.size() > 1:
		offset_other = min((hand_width-total_width) / (_srv_cards.size()-1), 0)
	
	var dir = _area.global_transform.basis.x
	if total_width > hand_width:
		dir.y += CARD_HEIGHT_DIFF
		dir = dir.normalized()
	var origin = _area.global_transform.origin - dir * (hand_width / 2)
	
	_srv_cards[0].srv_set_hover_position(origin + dir * offset_begin)
	
	var cumulative_width = widths[0]
	for i in range(1, _srv_cards.size()):
		var k = offset_begin + cumulative_width + offset_other
		_srv_cards[i].srv_set_hover_position(origin + dir * k)
		
		cumulative_width += widths[i] + offset_other

# Set the rotation of the given card to be in line with the hand.
# card: The card whose rotation we want to set.
func _srv_set_card_rotation(card: Card) -> void:
	var new_basis = transform.basis
	if card.transform.basis.y.y < 0:
		new_basis = new_basis.rotated(transform.basis.z, PI)
	card.srv_set_hover_rotation(Quat(new_basis))

# Try and set a node's front face visibility.
# body: The node to try and set the front face visibility of.
# visible: Whether the front face should be visible or not.
func _try_set_front_face_visible(body: Node, visible: bool) -> void:
	var valid = false
	if body is Card:
		valid = true
	elif body is Stack:
		valid = body.is_card_stack()
	
	if valid:
		_set_front_face_visible_recursive(body, visible)

func _on_Area_body_entered(body: Node):
	if body.get("over_hands") == null:
		return
	
	var this_id = owner_id()
	if not this_id in body.over_hands:
		body.over_hands.append(this_id)
	
	var player_id = get_tree().get_network_unique_id()
	_try_set_front_face_visible(body, player_id in body.over_hands)

func _on_Area_body_exited(body: Node):
	if body.get("over_hands") == null:
		return
	
	body.over_hands.erase(owner_id())
	
	var show_face = true
	if not body.over_hands.empty():
		show_face = get_tree().get_network_unique_id() in body.over_hands
	_try_set_front_face_visible(body, show_face)

func _on_card_exiting_tree(card: Card):
	srv_remove_card(card)

func _on_client_set_card_position(card: Card):
	srv_remove_card(card)

func _on_Hand_tree_exiting():
	if get_tree().has_network_peer():
		if get_tree().is_network_server():
			for card in _srv_cards:
				card.rpc_id(1, "request_stop_hovering")
	
	srv_clear_cards(false)

func _on_Lobby_player_modified(id: int, _old: Dictionary):
	if id == owner_id():
		update_owner_display()
