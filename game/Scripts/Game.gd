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

extends Node

onready var _connecting_dialog = $ConnectingDialog
onready var _room = $Room
onready var _ui = $GameUI

var _player_name: String
var _player_color: Color

# Apply options from the options menu.
# config: The options to apply.
func apply_options(config: ConfigFile) -> void:
	_room.apply_options(config)
	_ui.apply_options(config)
	
	_player_name = config.get_value("multiplayer", "name")
	_player_color = config.get_value("multiplayer", "color")
	
	if not get_tree().is_network_server():
		if not _connecting_dialog.visible:
			Lobby.rpc_id(1, "request_modify_self", _player_name, _player_color)

# Initialise a client peer.
# server: The server to connect to.
# port: The port number to connect to.
func init_client(server: String, port: int) -> void:
	print("Connecting to ", server, ":", port, " ...")
	var peer = NetworkedMultiplayerENet.new()
	peer.create_client(server, port)
	get_tree().network_peer = peer
	
	_connecting_dialog.popup_centered()

# Initialise a server peer.
# max_players: The maximum number of peers (excluding the server) that can
# connect to the server.
# port: The port number to host the server on.
func init_server(max_players: int, port: int) -> void:
	print("Starting server on port ", port, " with ", max_players, " max players...")
	var peer = NetworkedMultiplayerENet.new()
	peer.create_server(port, max_players + 1)
	get_tree().network_peer = peer

# Initialise a singleplayer game, which is a server that refuses connections.
func init_singleplayer() -> void:
	print("Starting singleplayer...")
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	init_server(0, rng.randi_range(10000, 65535))

# Request the server to put a card in the game into your hand.
# card_name: The name of the card.
master func request_card_in_hand(card_name: String) -> void:
	var card = _room.get_piece_with_name(card_name)
	var player_id = get_tree().get_rpc_sender_id()
	
	if not card:
		push_error("Card " + card_name + " does not exist!")
		return
	
	if not card is Card:
		push_error("Piece " + card_name + " is not a card!")
		return
	
	var placed_aside = card.is_placed_aside()
	var hovering = card.srv_is_hovering()
	var player_is_hovering = card.srv_get_hovering_player() == player_id
	
	if (not placed_aside) and ((not hovering) or player_is_hovering):
		card.rpc("place_aside", player_id)
		rpc_id(player_id, "request_card_in_hand_accepted", card_name)

# Called if the server accepted our request to put a card in our hand.
# card_name: The name of the card.
remotesync func request_card_in_hand_accepted(card_name: String) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	var card = _room.get_piece_with_name(card_name)
	
	if not card:
		push_error("Card " + card_name + " does not exist!")
		return
	
	if not card is Card:
		push_error("Piece " + card_name + " is not a card!")
		return
	
	_ui.add_card_to_hand(card, card.transform.basis.y.dot(Vector3.UP) > 0)

# Request the server to remove a card that is in our hand, and put it back into
# the game.
# card_name: The name of the card to put back into the game.
# transform: The transform the card should have once it is back in the game.
master func request_card_out_hand(card_name: String, transform: Transform) -> void:
	var card = _room.get_piece_with_name(card_name)
	var player_id = get_tree().get_rpc_sender_id()
	
	if not card:
		push_error("Card " + card_name + " does not exist!")
		return
	
	if not card is Card:
		push_error("Piece " + card_name + " is not a card!")
		return
	
	# Ensure the player requesting is the one that set the card aside.
	if card.srv_get_place_aside_player() != player_id:
		return
	
	card.rpc("bring_back", transform)
	
	rpc_id(player_id, "request_card_out_hand_accepted", card.name)

# Called if the server accepted our request to take a card out of our hand.
# card_name: The name of the card.
remotesync func request_card_out_hand_accepted(card_name: String) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	var card = _room.get_piece_with_name(card_name)
	
	if not card:
		push_error("Card " + card_name + " does not exist!")
		return
	
	if not card is Card:
		push_error("Piece " + card_name + " is not a card!")
		return
	
	# Kindly ask the server if we can start hovering the piece.
	_room.rpc_id(1, "request_hover_piece", card_name, card.transform.origin, Vector3())
	
	_ui.remove_card_from_hand(card)

# Request the server to add a piece to the game.
# piece_entry: The piece's entry in the PieceDB.
master func request_game_piece(piece_entry: Dictionary) -> void:
	# Is the piece a pre-filled stack?
	if piece_entry.has("texture_paths") and (not piece_entry.has("texture_path")):
		_room.rpc_id(1, "request_add_stack_filled", piece_entry)
	else:
		# Send the call to create the piece to everyone.
		_room.rpc("add_piece",
			_room.srv_get_next_piece_name(),
			Transform(Basis.IDENTITY, Vector3(0, Piece.SPAWN_HEIGHT, 0)),
			piece_entry
		)

func _ready():
	get_tree().connect("network_peer_connected", self, "_player_connected")
	get_tree().connect("network_peer_disconnected", self, "_player_disconnected")
	get_tree().connect("connected_to_server", self, "_connected_ok")
	get_tree().connect("connection_failed", self, "_connected_fail")
	get_tree().connect("server_disconnected", self, "_server_disconnected")
	
	Lobby.connect("players_synced", self, "_on_Lobby_players_synced")
	
	Lobby.clear_players()
	
	# The assets should have been imported at the start of the game.
	_ui.set_piece_tree_from_db(PieceDB.get_db())

func _player_connected(id: int) -> void:
	print("Player with ID ", id, " connected!")
	
	# If a player has connected to the server, let them know of every piece on
	# the board so far.
	if get_tree().is_network_server():
		_room.rpc_id(id, "set_state", _room.get_state())

func _player_disconnected(id: int) -> void:
	print("Player with ID ", id, " disconnected!")
	
	if get_tree().is_network_server():
		Lobby.rpc("remove_self", id)
		
		# If the player had set aside any cards, then we need to get them back,
		# otherwise they're going to be lost in the ether forever.
		var cards = []
		for piece in _room.get_pieces():
			if piece is Card:
				if piece.srv_get_place_aside_player() == id:
					cards.append(piece)
		
		var transform = Transform(Basis.IDENTITY, Vector3(0, Piece.SPAWN_HEIGHT, 0))
		if cards.size() > 1:
			var stack_name = _room.srv_get_next_piece_name()
			_room.rpc("add_stack", stack_name, transform, cards[0].name, cards[1].name)
			for i in range(2, cards.size()):
				_room.rpc("add_piece_to_stack", cards[i].name, stack_name)
		elif cards.size() == 1:
			cards[0].rpc("bring_back", transform)

func _connected_ok() -> void:
	print("Successfully connected to the server!")
	_connecting_dialog.visible = false
	
	Lobby.rpc_id(1, "request_sync_players")
	
	_room.start_sending_cursor_position()

func _connected_fail() -> void:
	print("Failed to connect to the server!")
	Global.start_main_menu_with_error("Failed to connect to the server!")

func _server_disconnected() -> void:
	print("Lost connection to the server!")
	Global.start_main_menu_with_error("Lost connection to the server!")

func _on_GameUI_applying_options(config: ConfigFile):
	apply_options(config)

func _on_GameUI_card_in_hand_requested(card: Card):
	rpc_id(1, "request_card_in_hand", card.name)

func _on_GameUI_card_out_hand_requested(card_texture: CardTextureRect):
	var camera_basis = _room.get_camera_transform().basis
	# Ensure the basis is parallel to the table.
	var basis = Basis.IDENTITY
	basis.x = camera_basis.x
	basis.y = Vector3.UP
	basis.z = basis.x.cross(basis.y)
	basis = basis.orthonormalized()
	if not card_texture.front_face:
		basis = basis.rotated(basis.z, PI)
	
	# Use the camera controller to get the correct transform.
	var transform = Transform(basis, _room.get_camera_hover_position())
	
	rpc_id(1, "request_card_out_hand", card_texture.card.name, transform)

func _on_GameUI_piece_requested(piece_entry: Dictionary):
	rpc_id(1, "request_game_piece", piece_entry)

func _on_Lobby_players_synced():
	if not get_tree().is_network_server():
		Lobby.rpc_id(1, "request_add_self", _player_name, _player_color)

func _on_Room_cards_in_hand_requested(cards: Array):
	# TODO: Send the entire array over the network at once.
	for card in cards:
		if card is Card:
			rpc_id(1, "request_card_in_hand", card.name)
