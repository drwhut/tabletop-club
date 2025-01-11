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

## Freeze the current state of the game to allow certain operations to occur.
##
## This system guarantees that when a game state is being transferred from the
## server to a client (e.g. if a player has just joined), then another client
## cannot modify the state after it has been read by the server, which would
## put the two clients out of sync with each other.
##
## This was previously not a potential issue in v0.1.x, as the game state was
## always transferred in one RPC, so any requests that came from clients that
## reached the server after the server read the state would propagate their way
## to the new client, and those messages would arrive [i]after[/i] the state
## RPC, allowing the new client to get in sync with the rest of the clients
## before receiving any state-modifying messages.
##
## However, now that state transfers occur over potentially multiple RPCs, the
## possibility exists that a state-modifying request could arrive from another
## client during the transfer. This is what this freeze system is for - to avoid
## requests being made while transfers are happening. However, a modified client
## can still potentially send messages during transfers. This system does not
## "solve" the issue, but rather it makes it much less likely to happen.


## Fired when the status of state freezing has changed.
signal freeze_active_changed(new_status)

## Fired on the server when all clients have acknowledged the freeze request,
## or when the timer runs out, whichever comes first.
## Use this signal to know when to safely read and transfer the game state.
signal all_clients_frozen()


## The maximum amount of time that the server will wait for clients to
## acknowledge the freeze request.
const MAX_ACK_WAIT_TIME_MSEC := 3000


## Is the state currently frozen?
var freeze_active := false setget set_freeze_active


# The IDs of clients that have yet to acknowledge the server's freeze request.
# Once all clients have acknowledged the request, [signal all_clients_frozen]
# will be fired.
# TODO: Make typed in 4.x
var _clients_to_ack: Array = []

# The time at which the request to freeze the state was sent to all clients.
# If too much time passes, then continue anyways - we don't want a client
# blocking execution by not responding.
# NOTE: A negative value indicates that we are not waiting for acknowledgements.
var _freeze_request_time_msec := -1


func _ready():
	# We want this node to keep processing even if the state is frozen.
	pause_mode = PAUSE_MODE_PROCESS
	
	NetworkManager.connect("connection_to_peer_closed", self,
			"_on_NetworkManager_connection_to_peer_closed")


func _process(_delta):
	if not get_tree().is_network_server():
		return
	
	if _freeze_request_time_msec < 0:
		return
	
	var current_time := OS.get_ticks_msec()
	if current_time - _freeze_request_time_msec > MAX_ACK_WAIT_TIME_MSEC:
		print("StateFreeze: Acknowledge timeout reached, continuing...")
		_freeze_request_time_msec = -1
		_clients_to_ack.clear()
		
		emit_signal("all_clients_frozen")


func set_freeze_active(value: bool) -> void:
	var has_changed := (value != freeze_active)
	freeze_active = value
	
	if freeze_active:
		print("StateFreeze: State has been frozen.")
	else:
		print("StateFreeze: State is no longer frozen.")
	
	# Pausing the scene tree will get certain node structures to stop processing
	# and getting input, but not all structures, as we want some nodes to keep
	# working in the event that the freeze does not end. In essense, we want the
	# user to be able to exit the game gracefully if this ends up happening.
	get_tree().paused = freeze_active
	
	if has_changed:
		emit_signal("freeze_active_changed", freeze_active)


## As the server, send a request to all clients to freeze the game state.
## Once the clients have frozen their game state, they should send an
## acknowledgement back to the server. Once all connected clients have done so,
## [signal all_clients_frozen] will be fired. It will also be fired after a
## given amount of time in the event that a client does not send an
## acknowledgement to prevent execution from being blocked.
func broadcast_freeze_signal() -> void:
	set_freeze_active(true)
	
	var clients_to_signal := get_tree().get_network_connected_peers()
	
	# If we are the only player in the game, then we can continue straight away.
	if clients_to_signal.empty():
		print("StateFreeze: No other clients connected, continuing...")
		emit_signal("all_clients_frozen")
		return
	
	_clients_to_ack.clear()
	for id in clients_to_signal:
		_clients_to_ack.push_back(id)
	
	_freeze_request_time_msec = OS.get_ticks_msec()
	
	print("StateFreeze: Sending freeze signal to clients...")
	rpc("client_freeze_state")


## Called by the server from [method broadcast_freeze_signal] to freeze the
## current state of the game.
puppet func client_freeze_state() -> void:
	print("StateFreeze: Received freeze signal from the server.")
	
	if freeze_active:
		print("StateFreeze: State is already frozen.")
	else:
		set_freeze_active(true)
	
	# Send the acknowledgement back to the server.
	print("StateFreeze: Sending acknowledgement back to the server...")
	rpc_id(1, "acknowledge_freeze")


## Called by clients to let the server know that they have received the freeze
## signal and have frozen their local state.
master func acknowledge_freeze() -> void:
	# Don't do anything if we are not expecting ack's.
	if _freeze_request_time_msec < 0:
		return
	
	var client_id := get_tree().get_rpc_sender_id()
	_clients_to_ack.erase(client_id)
	
	print("StateFreeze: Client with ID '%d' has ackowledged the freeze signal." % client_id)
	
	if _clients_to_ack.empty():
		print("StateFreeze: All clients have acknowledged the freeze signal, continuing...")
		_freeze_request_time_msec = -1
		emit_signal("all_clients_frozen")


## As the server, send a request to all clients to unfreeze the state of the
## game.
## [b]NOTE:[/b] Unlike [method broadcast_freeze_signal], no acknowledgements are
## needed from the clients.
func broadcast_unfreeze_signal() -> void:
	set_freeze_active(false)
	
	print("StateFreeze: Sending unfreeze signal to clients...")
	rpc("client_unfreeze_state")


## Called by the server from [method broadcast_unfreeze_signal] to unfreeze the
## current state of the game.
puppet func client_unfreeze_state() -> void:
	print("StateFreeze: Received unfreeze signal from the server.")
	
	if freeze_active:
		set_freeze_active(false)
	else:
		print("StateFreeze: State is already unfrozen.")


func _on_NetworkManager_connection_to_peer_closed(peer_id: int):
	if not get_tree().is_network_server():
		return
	
	if not _clients_to_ack.has(peer_id):
		return
	
	print("StateFreeze: Client with ID '%d' disconnected before they acknowledged freeze signal." % peer_id)
	_clients_to_ack.erase(peer_id)
	
	if _clients_to_ack.empty():
		print("StateFreeze: All remaining clients have acknowledged the freeze signal, continuing...")
		_freeze_request_time_msec = -1
		emit_signal("all_clients_frozen")
