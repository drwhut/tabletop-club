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

extends Node

const PORT = 26271

onready var _piece_db = $PieceDB
onready var _room = $Room
onready var _ui = $GameUI

func init_client(server: String) -> void:
	var peer = NetworkedMultiplayerENet.new()
	peer.create_client(server, PORT)
	get_tree().network_peer = peer

func init_server(max_players: int) -> void:
	var peer = NetworkedMultiplayerENet.new()
	peer.create_server(PORT, max_players + 1)
	get_tree().network_peer = peer

func init_singleplayer() -> void:
	init_server(0)

master func request_card_in_hand(card_name: String) -> void:
	var card = _room.get_piece_with_name(card_name)
	
	if not card:
		push_error("Card " + card_name + " does not exist!")
		return
	
	if not card is Card:
		push_error("Piece " + card_name + " is not a card!")
		return
	
	# Only accept the request if the card is not being hovered, or the player
	# that is requesting is the one hovering the card.
	if (not card.is_hovering()) or (card.get_hovering_player() == get_tree().get_rpc_sender_id()):
		card.rpc("place_aside")
		rpc_id(get_tree().get_rpc_sender_id(), "request_card_in_hand_accepted", card_name)

remotesync func request_card_in_hand_accepted(card_name: String) -> void:
	var card = _room.get_piece_with_name(card_name)
	
	if not card:
		push_error("Card " + card_name + " does not exist!")
		return
	
	if not card is Card:
		push_error("Piece " + card_name + " is not a card!")
		return
	
	_ui.add_card_to_hand(card, card.transform.basis.y.dot(Vector3.UP) > 0)

master func request_card_out_hand(card_name: String, transform: Transform) -> void:
	var card = _room.get_piece_with_name(card_name)
	
	if not card:
		push_error("Card " + card_name + " does not exist!")
		return
	
	if not card is Card:
		push_error("Piece " + card_name + " is not a card!")
		return
	
	# TODO: Ensure the player requesting is the one that set the card aside.
	card.rpc("bring_back", transform)
	
	rpc_id(get_tree().get_rpc_sender_id(), "request_card_out_hand_accepted", card.name)

remotesync func request_card_out_hand_accepted(card_name: String) -> void:
	var card = _room.get_piece_with_name(card_name)
	
	if not card:
		push_error("Card " + card_name + " does not exist!")
		return
	
	if not card is Card:
		push_error("Piece " + card_name + " is not a card!")
		return
	
	# Kindly ask the server if we can start hovering the piece.
	_room.rpc_id(1, "request_hover_piece", card_name)
	
	_ui.remove_card_from_hand(card)

master func request_game_piece(piece_entry: Dictionary) -> void:
	# Send the call to create the piece to everyone.
	_room.rpc("add_piece",
		_room.get_next_piece_name(),
		Transform(Basis.IDENTITY, Vector3(0, Piece.SPAWN_HEIGHT, 0)),
		piece_entry
	)

func _ready():
	get_tree().connect("network_peer_connected", self, "_player_connected")
	get_tree().connect("network_peer_disconnected", self, "_player_disconnected")
	get_tree().connect("connected_to_server", self, "_connected_ok")
	get_tree().connect("connection_failed", self, "_connected_fail")
	get_tree().connect("server_disconnected", self, "_server_disconnected")
	
	# Import game assets.
	_piece_db.import_all()
	_ui.set_piece_tree_from_db(_piece_db.get_db())
	
	var is_server = true
	
	for arg in OS.get_cmdline_args():
		if arg == "--client":
			is_server = false
			break
	
	if is_server:
		print("Initializing server peer...")
		init_server(10)
	else:
		print("Initializing client peer...")
		init_client("127.0.0.1")

func _player_connected(id: int) -> void:
	print("Player ", id, " connected!")
	
	# If a player has connected to the server, let them know of every piece on
	# the board so far.
	if get_tree().is_network_server():
		_room.rpc_id(id, "set_state", _room.get_state())

func _player_disconnected(id: int) -> void:
	print("Player ", id, " disconnected!")

func _connected_ok() -> void:
	print("Connected OK!")

func _connected_fail() -> void:
	print("Connected FAIL!")

func _server_disconnected() -> void:
	print("Server disconnected!")

func _on_GameUI_card_in_hand_requested(card: Card):
	rpc_id(1, "request_card_in_hand", card.name)

func _on_GameUI_card_out_hand_requested(card_texture: CardTextureRect):
	var basis = Basis.IDENTITY
	if not card_texture.front_face:
		basis = basis.rotated(Vector3.BACK, PI)
	
	# Use the camera controller to get the correct transform.
	var transform = Transform(basis, _room.get_camera_hover_position())
	
	rpc_id(1, "request_card_out_hand", card_texture.card.name, transform)

func _on_GameUI_piece_requested(piece_entry: Dictionary):
	rpc_id(1, "request_game_piece", piece_entry)
