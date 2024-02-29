# tabletop-club
# Copyright (c) 2020-2024 Benjamin 'drwhut' Beddows.
# Copyright (c) 2021-2024 Tabletop Club contributors (see game/CREDITS.tres).
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

## The list of currently connected players, and their details.
##
## - If not in-game, then no players should be assigned to the lobby.
## - If in singleplayer, the player should be the only one assigned, with ID 1.
## - If hosting a multiplayer game, the player should start off as the only one
## assigned, with ID 1. Other players can join over time and request to be added
## to the lobby once the post-connection checks have succeeded.
## - If joining a multiplayer game, no players are added to the lobby until the
## host has sent us the lobby data after we have requested to join it.
##
## [b]NOTE:[/b] This script is the highest level script of the networking stack,
## right above the NetworkManager. It is highly recommended for other scripts to
## connect to this script's signals if at all possible, unless you want to know
## specific details about events that happen in the network, in which case
## NetworkManager might suit you better.
##
## TODO: Test this class once it is complete.


## Fired when a [Player] has been added to the lobby.
signal player_added(player)

## Fired when a [Player]'s ID has changed. This can occur, for example, when a
## client has disconnected from the host and continues in singleplayer.
signal player_id_changed(player, old_id)

## Fired when a [Player]'s name or colour has been modified.
signal player_modified(player)

## Fired when a [Player] is about to be removed from the lobby.
signal player_removing(player, reason)

## Fired when a [Player] has been removed from the lobby.
signal player_removed(player, reason)


## Fired when this client has been added to the lobby.
signal self_added()

## Fired when this client has been removed from the lobby.
signal self_removed()


## The various reasons why a player might be removed from the lobby.
enum {
	REASON_DISCONNECTED,
	REASON_LOBBY_SEALED,
}


# The list of players, in no particular order.
# TODO: Make array typed in 4.x.
var _player_list: Array = []

# The [Player] that corresponds to this client.
var _client_player: Player = null

# If player details have been removed or modified, a copy of them is kept here
# so that the previous details can be retrieved and shown later.
# NOTE: The keys are the IDs, and the values are the [Player] objects.
var _old_details := {}


## Add the [param player] to the lobby. If a player with the same ID is already
## in the lobby, an error is thrown.
func add_player(player: Player) -> void:
	if _get_index_of_id(player.id) >= 0:
		push_error("Cannot add player '%s' to the lobby, player with ID '%d' already exists" %
				[player.name, player.id])
		return
	
	# If old details were stored for a player with the same ID (usually the
	# host, with ID 1), then remove them, as this is no longer the same player.
	_old_details.erase(player.id)
	
	print("Lobby: Adding player '%s' (ID: %d, Colour: %s)..." % [player.name,
			player.id, player.color.to_html(false)])
	_player_list.push_back(player)
	emit_signal("player_added", player)
	
	var m := Message.new(Message.TYPE_INFO,
			tr("<player %d> has joined the game.") % player.id)
	MessageHub.add_message(m)
	
	if get_tree().has_network_peer():
		if get_tree().get_network_unique_id() == player.id:
			_client_player = player
			emit_signal("self_added")
	else:
		push_warning("Player was added to the lobby before network peer was initialised - cannot check if it was self that was added.")


## Change the ID of one of the players currently in the lobby. Note that
## [param old_id] must already exist in the lobby, and [param new_id] cannot.
func change_player_id(old_id: int, new_id: int) -> void:
	var player_index := _get_index_of_id(old_id)
	if player_index < 0:
		push_error("Cannot change ID '%d' of player that is not in the lobby" % old_id)
		return
	
	var should_be_neg := _get_index_of_id(new_id)
	if should_be_neg >= 0:
		push_error("Cannot change player ID '%d' to '%d', target ID already exists in the lobby" %
				[old_id, new_id])
		return
	
	var player: Player = _player_list[player_index]
	
	print("Lobby: Changing ID of player '%s' from %d to %d..." % [player.name,
			old_id, new_id])
	player.id = new_id
	
	emit_signal("player_id_changed", player, old_id)


## Clear all of the players from the lobby. If [param except_self] is set to
## [code]true[/code], then this client's player is kept in.
## This will fire [signal player_removing] and [signal player_removed] for each
## player that is removed.
func clear(reason: int, except_self: bool = false) -> void:
	if except_self:
		print("Lobby: Removing all players except self...")
	else:
		print("Lobby: Removing all players...")
	
	for index in range(_player_list.size() - 1, -1, -1):
		if except_self:
			var player: Player = _player_list[index]
			if player == _client_player:
				continue
		
		_remove_at_index(index, reason)


## Get the details of the player with the ID [param player_id].
## Returns [code]null[/code] if the player is not in the lobby.
func get_player(player_id: int) -> Player:
	var index_to_get := _get_index_of_id(player_id)
	if index_to_get >= 0:
		return _player_list[index_to_get]
	
	return null


## Get the number of players currently in the lobby.
func get_player_count() -> int:
	return _player_list.size()


## Get the [Player] representing this client. Returns [code]null[/code] if this
## client is not in the lobby.
func get_self() -> Player:
	return _client_player


## Check if a player with ID [param player_id] exists in the lobby.
func has_player(player_id) -> bool:
	return _get_index_of_id(player_id) >= 0


## Modify the player with ID [param player_id], by setting a [param new_name]
## and a [param new_color].
func modify_player(player_id: int, new_name: String, new_color: Color) -> void:
	var index := _get_index_of_id(player_id)
	if index < 0:
		push_error("Cannot modify player with ID '%d', not in the lobby" % player_id)
		return
	
	var old_player: Player = _player_list[index]
	
	# Before we overwrite the previous details, we need to save them so that
	# other parts of the game can still access them.
	_old_details[player_id] = old_player
	
	print("Lobby: Modifying player with ID '%d' (Name: '%s' -> '%s', Color: %s -> %s)..." %
			[player_id, old_player.name, new_name,
			old_player.color.to_html(false), new_color.to_html(false)])
	var new_player := Player.new(player_id, new_name, new_color)
	_player_list[index] = new_player
	
	emit_signal("player_modified", new_player)
	
	var m_text := ""
	if new_name == old_player.name:
		m_text = tr("<player %d> changed their favourite colour.") % player_id
	else:
		m_text = tr("<player_old %d> changed their name to <player %d>.") % [
				player_id, player_id]
	
	var m := Message.new(Message.TYPE_INFO, m_text)
	MessageHub.add_message(m)


## Remove the player with ID [param player_id] from the lobby.
func remove_player(player_id: int, reason: int) -> void:
	var index_to_remove := _get_index_of_id(player_id)
	if index_to_remove >= 0:
		_remove_at_index(index_to_remove, reason)


# If a [Player] is in the lobby with the ID [param id], then return its index
# in the list. Otherwise, return [code]-1[/code].
func _get_index_of_id(id: int) -> int:
	for index in range(_player_list.size()):
		var player: Player = _player_list[index]
		if player.id == id:
			return index
	
	return -1


# Remove the player at the given index in the list.
func _remove_at_index(index: int, reason: int) -> void:
	if index < 0 or index >= _player_list.size():
		push_error("Cannot remove player, invalid index '%d'" % index)
		return
	
	var player_to_remove: Player = _player_list[index]
	
	# Store the player details so that they can be shown later if needed.
	_old_details[player_to_remove.id] = player_to_remove
	
	print("Lobby: Removing player '%s' (ID: %d)..." % [player_to_remove.name,
			player_to_remove.id])
	emit_signal("player_removing", player_to_remove, reason)
	_player_list.remove(index)
	emit_signal("player_removed", player_to_remove, reason)
	
	var m_text := ""
	match reason:
		REASON_DISCONNECTED:
			m_text = tr("<player_old %d> has left the game.") % player_to_remove.id
		REASON_LOBBY_SEALED:
			if player_to_remove.id == 1:
				m_text = tr("<player_old 1> has closed the room.")
	
	if not m_text.empty():
		var m := Message.new(Message.TYPE_INFO, m_text)
		MessageHub.add_message(m)
	
	if player_to_remove == _client_player:
		_client_player = null
		emit_signal("self_removed")
