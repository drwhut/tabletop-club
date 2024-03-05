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


## Fired when an error occured in trying to join the lobby as a client.
signal failed_to_add_self(err)


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
	REASON_DISCONNECTED, ## Connection to peer closed or lost.
	REASON_LOBBY_SEALED, ## Received signal from the master server.
	REASON_LOBBY_CLOSED, ## Lobby closed by the client manually.
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


func _ready():
	# Although the host will probably tell us faster than the master server, we
	# do need to deal with the case that the master server tells us the host has
	# sealed the room before the host's connection drops.
	MasterServer.connect("room_sealed", self, "_on_MasterServer_room_sealed")
	
	# While we don't use this signal to add the player to the lobby (the main
	# game script needs to perform checks first), as the host we will want to
	# start a timer for clients to add themselves to the lobby after they have
	# connected to us.
	NetworkManager.connect("connection_to_peer_established", self,
			"_on_NetworkManager_connection_to_peer_established")
	
	# We don't need to connect the 'connection_to_host_*' signals, since host
	# connections are also peer connections.
	NetworkManager.connect("connection_to_peer_closed", self,
			"_on_NetworkManager_connection_to_peer_closed")
	
	# We also don't need to connect 'setup_failed' and 'lobby_server_disconnected'
	# as those only affect the state of the network during setup.
	NetworkManager.connect("network_init", self, "_on_NetworkManager_network_init")


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
	if old_id == new_id:
		return
	
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
	if _player_list.empty():
		return
	
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


## Close the lobby. This removes all players (including this client's) from the
## lobby, and asks the NetworkManager to shut down the network if it is active.
func close() -> void:
	print("Lobby: Closing the lobby...")
	clear(REASON_LOBBY_CLOSED)
	NetworkManager.stop()


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


## Get the old details of the player with the ID [param player_id]. Use this
## instead of [method get_player] if you want to get the details of a player who
## is no longer in the lobby, or to get their details prior to modification.
## Return [code]null[/code] if no old details exist for the given player.
func get_player_old(player_id: int) -> Player:
	return _old_details.get(player_id, null)


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


## As a client, request the server to add us to the lobby.
## If the request is accepted, then the server will send our details to all of
## the other players in the lobby via [method reverb_add_player], then it will
## send the details of all of the other players to us via
## [method response_add_self_accepted].
## [b]NOTE:[/b] This is called from the main Game script soon after we have
## established a connection to the host and have checked our client's version 
## against the host's.
master func request_add_self(client_name: String, client_color: Color) -> void:
	# We know the client_id exists in the network because of this call.
	var client_id := get_tree().get_rpc_sender_id()
	print("Lobby: Client with ID '%d' has requested to join the lobby..." % client_id)
	
	if has_player(client_id):
		push_error("Cannot add client with ID '%d' to the lobby, ID already exists" % client_id)
		rpc_id(client_id, "response_add_self_denied")
		return
	
	# The player is now about to join the lobby, so we can stop the join timer
	# so that they do not get kicked when it runs out.
	_stop_join_timer(client_id)
	
	# NOTE: The [Player] will automatically validate the details that the client
	# has sent us, so use the values from it afterwards.
	var player := Player.new(client_id, client_name, client_color)
	add_player(player)
	
	print("Lobby: Sending the details of the client with ID '%d' to the other players..." % client_id)
	# We can't use an 'rpc' call here, since that would also send the details to
	# the client that is adding themselves.
	for element in _player_list:
		var send_to: Player = element
		if send_to.id == 1 or send_to.id == client_id:
			continue
		
		rpc_id(send_to.id, "reverb_add_player", client_id, player.name,
				player.color)
	
	print("Lobby: Sending the lobby details to the client with ID '%d'..." % client_id)
	var lobby_dict := {}
	for element in _player_list:
		# NOTE: This will also include the player that was just added.
		var lobby_player: Player = element
		lobby_dict[lobby_player.id] = {
			"name": lobby_player.name,
			"color": lobby_player.color
		}
	
	rpc_id(client_id, "response_add_self_accepted", lobby_dict)


## Called by the server when our request to add ourselves to the lobby was
## accepted.
puppet func response_add_self_accepted(server_lobby: Dictionary) -> void:
	print("Lobby: Received the entire lobby from the server.")
	
	var lobby_contains_host := false
	var lobby_contains_client := false
	
	var valid_dicts := []
	for key in server_lobby:
		if not key is int:
			push_error("Key received in server lobby is not an integer")
			continue
		
		var player_id: int = key
		if player_id < 1:
			push_error("Player ID received in server lobby is invalid (%d)" % player_id)
			continue
		elif player_id == 1:
			lobby_contains_host = true
		elif player_id == get_tree().get_network_unique_id():
			lobby_contains_client = true
		
		var value = server_lobby[key]
		if not value is Dictionary:
			push_error("Value received in server lobby is not a dictionary")
			continue
		
		var player_dict: Dictionary = value
		var dict_parse := DictionaryParser.new(player_dict)
		
		# If the details are invalid, then they will become valid when they are
		# placed in a [Player].
		var player_name: String = dict_parse.expect_strict_type("name", "")
		var player_color: Color = dict_parse.expect_strict_type("color",
				Color.white)
		
		valid_dicts.push_back({
			"id": player_id,
			"name": player_name,
			"color": player_color
		})
	
	# Something went wrong - at the very least, the server's lobby should have
	# at the very least the host and our client.
	if not (lobby_contains_host and lobby_contains_client):
		push_error("Lobby received from the server does not include both the host and our client.")
		
		# Things are about to go very wrong, so close the network.
		emit_signal("failed_to_add_self", ERR_INVALID_DATA)
		NetworkManager.stop()
		return
	
	for element in valid_dicts:
		var player_dict: Dictionary = element
		var player_id: int = player_dict["id"]
		var player_name: String = player_dict["name"]
		var player_color: Color = player_dict["color"]
		
		# This provides extra checks for the player details before we add them.
		reverb_add_player(player_id, player_name, player_color)


## Called by the server when our request to add ourselves to the lobby was
## denied.
puppet func response_add_self_denied() -> void:
	push_error("Server denied our request to be added to the lobby.")
	
	# There is nothing we can do now, so close the network.
	emit_signal("failed_to_add_self", ERR_QUERY_FAILED)
	NetworkManager.stop()


## Called by the server when a new player has been added to the lobby.
puppet func reverb_add_player(player_id: int, player_name: String,
		player_color: Color) -> void:
	
	if player_id != get_tree().get_network_unique_id():
		var peer_id_list := NetworkManager.get_peer_ids()
		if not peer_id_list.has(player_id):
			push_error("Cannot add player with ID '%d' to lobby, ID not in network" % player_id)
			return
	
	# NOTE: The [Player] will automatically validate the details if the data the
	# server sent to us is invalid, and the call will fail if the ID already
	# exists in the lobby.
	var player := Player.new(player_id, player_name, player_color)
	add_player(player)


## Called by the server when a player has been removed from the lobby.
puppet func reverb_remove_player(player_id: int) -> void:
	# TODO: What if the server is removing US?
	remove_player(player_id, REASON_DISCONNECTED)


# Convert the lobby from a multiplayer instance to a singleplayer one.
# This will remove all players from the lobby that are not this client, and it
# will set the remaining [Player]'s ID to 1.
# The lobby will also attempt to start the network in singleplayer mode, which
# will throw an error if the network is still alive.
func _try_convert_to_singleplayer(reason: int) -> void:
	print("Lobby: Converting to a singleplayer instance...")
	
	# Remove all players except this client's.
	clear(reason, true)
	if _client_player == null:
		print("Lobby: No players left in lobby, not converting to singleplayer.")
		return
	
	# Set this client's ID to 1. If it is already 1, then we don't need to do
	# anything else, as we should already have a network set up.
	if _client_player.id == 1:
		print("Lobby: Client is already ID 1, no need to convert to singleplayer.")
		return
	change_player_id(_client_player.id, 1)
	
	# Give the NetworkManager time to close the network fully, so that we can
	# start it in singleplayer mode after.
	NetworkManager.call_deferred("start_server_solo")


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


# Start a timer for the player with ID [param player_id], in which that player
# must request to be added to the lobby before the timer runs out. If they fail
# to do so, they will be kicked from the network.
func _start_join_timer(player_id: int) -> void:
	var node_name := "Timeout_%d" % player_id
	if has_node(node_name):
		push_error("Cannot start join timer for player '%d', timer already exists" % player_id)
		return
	
	# Use the same timeout duration that other connections use.
	var timeout_sec: int = ProjectSettings.get_setting(
			"network/limits/tcp/connect_timeout_seconds")
	
	var timer := Timer.new()
	timer.name = node_name
	timer.wait_time = timeout_sec
	timer.one_shot = true
	timer.autostart = true
	
	timer.connect("timeout", self, "_on_join_timer_timeout", [ player_id ])
	
	print("Lobby: Starting join timer for player '%d'..." % player_id)
	add_child(timer)


# Stop the join timer for the player with ID [param player_id], which will stop
# them from being kicked.
func _stop_join_timer(player_id: int) -> void:
	var node_name := "Timeout_%d" % player_id
	if not has_node(node_name):
		push_error("Cannot stop join timer for player '%d', timer does not exist" % player_id)
		return
	
	var timer_node := get_node(node_name)
	if not timer_node is Timer:
		push_error("Join timer for player '%d' is unexpected type" % player_id)
		return
	
	if timer_node.is_queued_for_deletion():
		push_warning("Join timer for player '%d' is already queued for deletion" % player_id)
		return
	
	print("Lobby: Stopping join timer for player '%d'..." % player_id)
	timer_node.queue_free()


# Check if a join timer is currently running for the player with the given
# [param player_id].
func _is_join_timer_running(player_id: int) -> bool:
	var node_name := "Timeout_%d" % player_id
	return has_node(node_name)


func _on_join_timer_timeout(player_id: int):
	print("Lobby: Join timer for player '%d' has run out, kicking them from the network..." % player_id)
	
	# We don't need to free the timer from the scene tree here, as the following
	# call will fire the NetworkManager.connection_to_peer_closed() signal,
	# which will free the timer for us.
	NetworkManager.kick_peer(player_id)


func _on_MasterServer_room_sealed():
	# The room is being closed, so try to convert to a singleplayer instance.
	# Defer the call so that the NetworkManager has time to close the network.
	call_deferred("_try_convert_to_singleplayer", REASON_LOBBY_SEALED)


func _on_NetworkManager_connection_to_peer_established(peer_id: int):
	if peer_id == 1:
		return
	
	# If we are the host, give the client that has just connected a time limit
	# for adding themselves to the lobby.
	_start_join_timer(peer_id)


func _on_NetworkManager_connection_to_peer_closed(peer_id: int):
	# If we are a client that just disconnected from the host...
	if peer_id == 1:
		# ... then if possible, we should try to convert the lobby from
		# multiplayer to singleplayer so the player can keep going with the
		# current state of the room.
		call_deferred("_try_convert_to_singleplayer", REASON_DISCONNECTED)
	
	# If we are a host, and a client just disconnected...
	else:
		# ...and they had added themsevles to the lobby...
		if has_player(peer_id):
			# ... then we need to remove them from the lobby, and let all of the
			# other clients know that they have left, since they do not have a
			# connection to them.
			remove_player(peer_id, REASON_DISCONNECTED)
			
			print("Lobby: Informing the other clients of their departure...")
			rpc("reverb_remove_player", peer_id)
		
		# ...and they had yet to add themselves to the lobby...
		elif _is_join_timer_running(peer_id):
			# ... then stop the join timer for them, as they can no longer be
			# kicked from the network.
			_stop_join_timer(peer_id)


func _on_NetworkManager_network_init(_room_code: String):
	# Don't do anything if we are a client - at this point, we'll be attempting
	# to connect to the host.
	if not get_tree().is_network_server():
		return
	
	# But if we are the server, then there is nothing stopping us from adding
	# ourselves to the lobby and starting the game! :D
	# However, there is a chance that we are already in the lobby, for example,
	# if we were a client and we disconnected from the host, we are now our own
	# host in singleplayer mode.
	if has_player(1):
		print("Lobby: Client is already in the lobby with ID 1, skipped adding.")
		return
	
	var player := Player.new(1, GameConfig.multiplayer_name,
			GameConfig.multiplayer_color)
	add_player(player)
