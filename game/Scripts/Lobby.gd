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

signal player_added(id)
signal player_modified(id)
signal player_removed(id)
signal players_synced()

var _players = {}

# Called by the server when a player has added themselves to the lobby.
# id: The ID of the player.
# name: The name of the player.
# color: The color of the player.
remotesync func add_self(id: int, name: String, color: Color) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	_players[id] = {}
	emit_signal("player_added", id)
	
	modify_self(id, name, color)

# Clear the list of players in the lobby.
func clear_players() -> void:
	_players.clear()

# Get the properties of the player with the given ID.
# Returns: The player's properties, empty if the player does not exist.
# id: The ID of the player.
func get_player(id: int) -> Dictionary:
	if _players.has(id):
		return _players[id]
	return {}

# Get the list of player IDs in the lobby.
# Returns: The list of player IDs in the lobby.
func get_player_list() -> Array:
	return _players.keys()

# Called by the server when a player has modified their properties.
# id: The ID of the player.
# name: The new name of the player.
# color: The new color of the player.
remotesync func modify_self(id: int, name: String, color: Color) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	if _players.has(id):
		var dict = _create_player_dict(name, color)
		_players[id] = dict
		emit_signal("player_modified", id)

# Does the player with the given ID exist?
# Returns: If the player exists.
# id: The ID of the player.
func player_exists(id: int) -> bool:
	return _players.has(id)

# Called by the server when a player has removed themselves from the lobby.
# id: The ID of the player.
remotesync func remove_self(id: int) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	if _players.has(id):
		_players.erase(id)
		emit_signal("player_removed", id)

# Request the server to add you to the network lobby.
# name: Your name.
# color: Your color.
master func request_add_self(name: String, color: Color) -> void:
	var id = get_tree().get_rpc_sender_id()
	rpc("add_self", id, name, color)

# Request the server to modify your network properties.
# name: Your new name.
# color: Your new color.
master func request_modify_self(name: String, color: Color) -> void:
	var id = get_tree().get_rpc_sender_id()
	rpc("modify_self", id, name, color)

# Request the server to remove you from the network lobby.
master func request_remove_self() -> void:
	var id = get_tree().get_rpc_sender_id()
	rpc("remove_self", id)

# Request the server to send you it's list of players.
master func request_sync_players() -> void:
	var id = get_tree().get_rpc_sender_id()
	rpc_id(id, "request_sync_players_accepted", _players)

# Called by the server to let you know of it's list of players.
# players: The list of players.
remotesync func request_sync_players_accepted(players: Dictionary) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	_players = {}
	for id in players.keys():
		var name: String = players[id]["name"]
		var color: Color = players[id]["color"]
		add_self(id, name, color)
	
	emit_signal("players_synced")

# Create a player dictionary to be added to the list of players.
# Returns: The player dictionary.
# name: The name of the player.
# color: The color of the player.
func _create_player_dict(name: String, color: Color) -> Dictionary:
	return {
		"name": name,
		"color": color
	}