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

## Allows the server to send data over multiple packets to clients.
##
## This global class is needed in order to overcome a limitation in the WebRTC
## library that the game uses for multiplayer - the size of the buffer that is
## used to process incoming packets is a hardcoded value of 64 KiB. This means
## that large sets of data (for example, hard-to-compress game states, or paint
## images) need to be split up into multiple chunks in order to be sent over
## the network and processed.
##
## Since the hard-coded buffer size is for the entire game, all instances where
## large amounts of data can be sent to clients should come through this node
## and this node alone in order to prevent the buffer from being overwritten
## from multiple large writes at the same time.
##
## Therefore, there is also a queue system in place for planned future transfers
## of data using the [TransferPlan] class, so that two transfers cannot occur
## at the same time.
##
## TODO: Test this class fully once it is complete.


## Fired on all clients that were involved in the transfer (including the
## server) when it is complete.
## [b]NOTE:[/b] This also includes if clients skipped the transfer.
signal transfer_complete(data)


## The number of bytes sent per chunk to clients.
const CHUNK_SIZE := 50000 # = 50 KB

## The maximum amount of data that can be sent over the course of one transfer.
const MAX_COMPRESSED_DATA_SIZE := 4194304 # = 4.2 MB

## The maximum allowed size of data after it is uncompressed.
const MAX_UNCOMPRESSED_DATA_SIZE := 16777216 # = 16.8 MB

## The maximum amount of time that the server and clients will wait for each
## other's messages.
const MESSAGE_TIMEOUT_MS := 10000 # = 10s


## The [NodePath] that points to the game's "Room" node.
## This is required in order to retrieve the game state when starting a transfer.
const ROOM_NODE_PATH := @"/root/Game/Room"

## The name of the function that retrieves the game state from the "Room" node.
## This is required in order to retrieve the game state when starting a transfer.
const ROOM_STATE_METHOD_NAME := "get_state_compressed"


# The queue of transfers that should take place after the current transfer is
# complete.
# TODO: Make array typed in 4.x
var _transfer_queue: Array = []

# The list of transfers that are currently in progress.
# Note that, all of these will be transferring the same data, just to different
# clients. The reason the transfer states are separated is because some clients
# may be slower to send back acknowledgements than others.
# TODO: Make array typed in 4.x
var _active_transfer_arr: Array = []

# A flag that is set when the server needs to wait for all clients to activate
# the StateFreeze system before starting any transfers. For more information,
# refer to the StateFreeze class documentation.
var _waiting_for_state_freeze := false


func _ready():
	StateFreeze.connect("all_clients_frozen", self,
			"_on_StateFreeze_all_clients_frozen")


func _process(_delta):
	# Check to see if the server/clients are taking too long to respond.
	var current_time_ms := OS.get_ticks_msec()
	for index in range(_active_transfer_arr.size() - 1, -1, -1):
		var state: TransferState = _active_transfer_arr[index]
		if current_time_ms - state.last_message_time_ms > MESSAGE_TIMEOUT_MS:
			push_error("Data transfer from '%d' to '%d' timed out" % [
					state.sender_id, state.receiver_id])
			
			_active_transfer_arr.remove(index)
			
			# This may have been the last client we were waiting on to send or
			# receive a message.
			check_if_transfers_complete()
	
	if not _active_transfer_arr.empty():
		return
	
	if _transfer_queue.empty():
		return
	
	init_transfer(_transfer_queue.pop_front())


## Add a transfer to the queue. If no transfers are currently ongoing, then it
## will be initialised in the next frame. Otherwise, it will be initialised once
## the previous transfer in the queue has been completed.
## [b]NOTE:[/b] This operation will only work on the server.
func add_to_queue(plan: TransferPlan) -> void:
	# NOTE: Checks will be done when the plan is taken from the queue.
	_transfer_queue.push_back(plan)


## As the server, initialize the given [TransferPlan].
## [b]NOTE:[/b] This function will fail if there is already a transfer being
## processed, so it is recommended to use [method add_to_queue] instead, so
## that the [param plan] will be initialised once all other transfers have been
## processed to completion.
func init_transfer(plan: TransferPlan) -> void:
	var data: PartialData = null
	
	# If we are about to transfer a game state, we need to retrieve the data for
	# it by accessing the Room node manually. This can't be done from within the
	# TransferPlan, as it is a Reference, not a Node.
	# TODO: If we don't ever override TransferPlan.get_data(), should we
	# re-think this strategy?
	if plan is TransferPlanState:
		var room_node := get_node(ROOM_NODE_PATH)
		data = room_node.call(ROOM_STATE_METHOD_NAME)
	else:
		data = plan.get_data()
	
	if data == null:
		push_error("Cannot initialise transfer, data is null")
		return
	
	if data.size_compressed <= 0:
		push_error("Cannot initialise transfer, compressed size is 0")
		return
	
	if data.size_uncompressed <= 0:
		push_error("Cannot initialise transfer, uncompressed size is 0")
		return
	
	if not _active_transfer_arr.empty():
		push_error("Cannot initialise transfer, another transfer is currently ongoing")
		return
	
	print("DataBroadcaster: Initialising transfer of data '%s' (T: %d, C: %d, U: %d) ..." % [
			data.name, data.type, data.size_compressed, data.size_uncompressed])
	
	# If we are about to transfer a game state, all clients need to freeze their
	# current state so that the players cannot modify the state while it is
	# being transferred, which could take multiple RPCs.
	_waiting_for_state_freeze = (data.type == PartialData.TYPE_STATE)
	if _waiting_for_state_freeze:
		StateFreeze.broadcast_freeze_signal()
	
	for element in plan.receiver_ids:
		var client_id: int = element
		
		if client_id == 1:
			push_error("Cannot initiate transfer with self")
			continue
		
		if not Lobby.has_player(client_id):
			push_error("Cannot initiate transfer with client '%d', client is not in the lobby" % client_id)
			continue
		
		var state_for_client := TransferState.new()
		state_for_client.sender_id = 1
		state_for_client.receiver_id = client_id
		state_for_client.data = data
		state_for_client.last_message_time_ms = OS.get_ticks_msec()
		_active_transfer_arr.push_back(state_for_client)
		
		rpc_id(client_id, "request_transfer", data.name, data.type,
				data.size_compressed, data.size_uncompressed)
	
	# TODO: Figure out what to do if we don't end up init'ing any transfers.


## Called by the server when it sends a request to initialise a transfer with
## us, the client.
puppet func request_transfer(data_name: String, data_type: int,
		size_compressed: int, size_uncompressed: int) -> void:
	
	# TODO: Check if we already have the data stored in a cache.
	
	if not _active_transfer_arr.empty():
		push_error("Server requested to transfer data '%s', but another transfer is currently ongoing" % data_name)
		return
	
	if data_name.empty():
		push_warning("Transfer data name is empty")
	
	if data_type < 0 or data_type >= PartialData.TYPE_MAX:
		push_error("Transfer data type '%d' is invalid" % data_type)
		return
	
	if size_compressed <= 0 or size_uncompressed <= 0:
		push_error("Invalid transfer data size")
		return
	
	if size_compressed > size_uncompressed:
		push_error("Transfer compressed data size cannot be bigger than uncompressed size")
		return
	
	if size_compressed > MAX_COMPRESSED_DATA_SIZE:
		push_error("Transfer compressed data size is too big (%d > %d)" % [
				size_compressed, MAX_COMPRESSED_DATA_SIZE])
		return
	
	if size_uncompressed > MAX_UNCOMPRESSED_DATA_SIZE:
		push_error("Transfer uncompressed data size is too big (%d > %d)" % [
				size_uncompressed, MAX_UNCOMPRESSED_DATA_SIZE])
		return
	
	print("DataBroadcaster: Accepting request to receive data '%s' (T: %d, C: %d, U: %d)" % [
			data_name, data_type, size_compressed, size_uncompressed])
	
	var data := PartialData.new()
	data.name = data_name
	data.type = data_type
	data.size_uncompressed = size_uncompressed
	data.size_compressed = size_compressed
	
	var state := TransferState.new()
	state.sender_id = 1
	state.receiver_id = get_tree().get_network_unique_id()
	state.receiver_accepted = true
	state.receiver_skipping = false
	state.data = data
	state.last_message_time_ms = OS.get_ticks_msec()
	
	_active_transfer_arr.push_back(state)
	
	rpc_id(1, "accept_transfer_request")


## Sent by the client to accept a transfer request they have just received from
## the server. Once all of the clients have accepted the transfer, then the data
## will start to be transmitted one chunk at a time.
## TODO: Add ability to skip data transfer, but still receive signals.
master func accept_transfer_request() -> void:
	var client_id := get_tree().get_rpc_sender_id()
	var transfer_state: TransferState = _get_active_transfer(client_id)
	if transfer_state == null:
		push_error("Client '%d' accepted transfer request that did not exist" % client_id)
		return
	
	if transfer_state.receiver_accepted:
		push_warning("Client '%d' has already accepted transfer request" % client_id)
		return
	
	transfer_state.receiver_accepted = true
	transfer_state.last_message_time_ms = OS.get_ticks_msec()
	print("DataBroadcaster: Client '%d' has accepted the transfer request." % client_id)
	
	# Since the client has accepted, we'll check to see if all other clients
	# have accepted as well. If they have, then we can start it!
	check_if_can_start_transfer()


## As the server, check to see if all of the clients have accepted the transfer
## request that we gave them. If we are transferring a game state, also check if
## all of the clients have frozen their game state.
func check_if_can_start_transfer() -> void:
	if _waiting_for_state_freeze:
		return
	
	for element in _active_transfer_arr:
		var other_state: TransferState = element
		if not other_state.receiver_accepted:
			return
	
	print("DataBroadcaster: All clients have accepted transfer request, starting...")
	
	for element in _active_transfer_arr:
		var state: TransferState = element
		
		# TODO: Deal with the client potentially skipping the transfer.
		perform_transfer_pass(state)


## As the server, perform a pass on one of the active transfer states. If the
## transfer is ongoing, this means that the server will send one chunk of data
## to the corresponding client. If the transfer is finished, then nothing
## happens.
func perform_transfer_pass(transfer_state: TransferState) -> void:
	if not transfer_state.receiver_accepted:
		push_error("Cannot perform pass on transfer to client '%d', receiver has not accepted" % transfer_state.receiver_id)
		return
	
	if transfer_state.receiver_skipping:
		push_warning("No need to perform pass on transfer to client '%d', they are skipping" % transfer_state.receiver_id)
		return
	
	var size_total := transfer_state.data.size_compressed
	var chunk_start := transfer_state.num_packets_sent * CHUNK_SIZE
	
	if chunk_start > size_total - 1:
		print("DataBroadcaster: Transfer to client '%d' is complete." % transfer_state.receiver_id)
		return
	
	var chunk_end := chunk_start + CHUNK_SIZE - 1
	if chunk_end > size_total - 1:
		chunk_end = size_total - 1
	
	print("DataBroadcaster: Sending chunk #%d to client '%d' (bytes %d-%d)..." % [
			transfer_state.num_packets_sent + 1, transfer_state.receiver_id,
			chunk_start, chunk_end])
	var chunk := transfer_state.data.bytes.subarray(chunk_start, chunk_end)
	rpc_id(transfer_state.receiver_id, "send_chunk", chunk)
	
	transfer_state.num_packets_sent += 1
	if transfer_state.num_packets_ackd != transfer_state.num_packets_sent - 1:
		push_warning("Number of packets ack'd by client '%d' is not expected value (expected: %d, got: %d)" % [
				transfer_state.receiver_id, transfer_state.num_packets_sent - 1,
				transfer_state.num_packets_ackd])


## Called by the server to send a chunk of data to the client.
puppet func send_chunk(chunk_bytes: PoolByteArray) -> void:
	if chunk_bytes.size() > CHUNK_SIZE:
		push_error("Chunk of data sent by the server is too big (%d)" % chunk_bytes.size())
		return
	
	if _active_transfer_arr.size() != 1:
		push_error("Chunk of data was sent when no transfers are active")
		return
	
	var transfer_state: TransferState = _active_transfer_arr[0]
	# Don't need to check 'receiver_accepted', as it is implied by the transfer
	# being active.
	if transfer_state.receiver_skipping:
		push_warning("Server sent us data when we said to skip transfer")
		return
	
	transfer_state.last_message_time_ms = OS.get_ticks_msec()
	
	var current_bytes := transfer_state.data.bytes
	
	var final_size := transfer_state.data.size_compressed
	var current_size := current_bytes.size()
	
	var expected_chunk_size := CHUNK_SIZE
	if current_size + CHUNK_SIZE > final_size:
		expected_chunk_size = final_size - current_size
	
	if chunk_bytes.size() != expected_chunk_size:
		push_error("Chunk sent by server is wrong size (expected: %d, got: %d)" % [
				expected_chunk_size, chunk_bytes.size()])
		return
	
	print("DataBroadcaster: Received %d bytes of data (total: %d / %d)." % [
			expected_chunk_size, current_size + expected_chunk_size, final_size])
	current_bytes.append_array(chunk_bytes)
	# Since PoolByteArrays are passed by value, we need to manually assign the
	# byte array again.
	transfer_state.data.bytes = current_bytes
	
	print("DataBroadcaster: Sending acknowledge response #%d ..." % (transfer_state.num_packets_ackd + 1))
	rpc_id(1, "acknowledge_chunk")
	
	transfer_state.num_packets_sent += 1
	transfer_state.num_packets_ackd += 1
	
	if transfer_state.num_packets_sent != transfer_state.num_packets_ackd:
		push_warning("Number of packets sent (%d) does not match number of packets acknowledged (%d)" % [
				transfer_state.num_packets_sent, transfer_state.num_packets_ackd])


## Called by the client to acknowledge a chunk that was just sent by the server.
## This will get the server to send the next chunk, or if all of the data has
## been sent, wait until all other clients transfers are complete.
master func acknowledge_chunk() -> void:
	var client_id := get_tree().get_rpc_sender_id()
	var transfer_state: TransferState = _get_active_transfer(client_id)
	if transfer_state == null:
		push_error("Client '%d' acknowledged chunk for transfer that does not exist" % client_id)
		return
	
	if not transfer_state.receiver_accepted:
		push_error("Client '%d' acknowledged chunk before they accepted transfer" % client_id)
		return
	
	if transfer_state.receiver_skipping:
		push_warning("Client '%d' acknowledged chunk even though they are skipping" % client_id)
		return
	
	if transfer_state.num_packets_ackd != transfer_state.num_packets_sent - 1:
		push_error("Did not expect acknowledge signal from client '%d' (#sent: %d, #ackd: %d)" % [
				client_id, transfer_state.num_packets_sent, transfer_state.num_packets_ackd])
		return
	
	transfer_state.num_packets_ackd += 1
	transfer_state.last_message_time_ms = OS.get_ticks_msec()
	print("DataBroadcaster: Client '%d' acknowledged chunk #%d." % [client_id,
			transfer_state.num_packets_ackd])
	
	# Now that the number of acknowledged packets matches the number sent, we
	# can check to see if we need to send another chunk - if not, then the
	# transfer is complete for this client, and we wait until all other clients
	# are done as well before finalising the transfer.
	var total_size := transfer_state.data.size_compressed
	var next_chunk_start := transfer_state.num_packets_sent * CHUNK_SIZE
	
	if next_chunk_start > total_size - 1:
		print("DataBroadcaster: Transfer to client '%d' is complete." % client_id)
		check_if_transfers_complete()
	else:
		perform_transfer_pass(transfer_state)


## As the server, check if all of the transfers are complete.
func check_if_transfers_complete() -> void:
	if _active_transfer_arr.empty():
		return
	
	var first_state: TransferState = _active_transfer_arr[0]
	var data: PartialData = first_state.data
	
	for element in _active_transfer_arr:
		var transfer_state: TransferState = element
		
		# TODO: Some clients may have skipped the transfer.
		var total_size := transfer_state.data.size_compressed
		var next_chunk_start := transfer_state.num_packets_ackd * CHUNK_SIZE
		
		if next_chunk_start <= total_size - 1:
			return
	
	print("DataBroadcaster: Transfer of data '%s' to all clients is complete." % data.name)
	
	# Send an RPC only to the clients that we sent data to...
	for element in _active_transfer_arr:
		var transfer_state: TransferState = element
		rpc_id(transfer_state.receiver_id, "finalise_transfer", data.name)
	
	# ... and then call it ourselves.
	finalise_transfer(data.name)
	
	# If the data being transferred was a game state, then the clients can now
	# unfreeze their game state, as the new state should have been loaded before
	# this signal is sent.
	if data.type == PartialData.TYPE_STATE:
		StateFreeze.broadcast_unfreeze_signal()


## Called by the server on all clients (including themselves), once all clients
## have received all chunks of data.
puppet func finalise_transfer(data_name: String) -> void:
	var transfer_state: TransferState = null
	
	for element in _active_transfer_arr:
		var possible_state: TransferState = element
		if possible_state.data.name == data_name:
			transfer_state = possible_state
			break
	
	if transfer_state == null:
		push_error("No transfer of data '%s' found in active transfers" % data_name)
		return
	
	# TODO: Check state fully.
	
	print("DataBroadcaster: Finalising transfer of data '%s' ..." % data_name)
	
	# The transfers are no longer active, so remove all of them from the list.
	# Next frame, if there is a TransferPlan in the queue, it will be init'd
	# as the next active transfer.
	_active_transfer_arr.clear()
	
	emit_signal("transfer_complete", transfer_state.data)


# Get the [TransferState] for the receiver with the given [param client_id].
# If none exists, [code]null[/code] is returned.
func _get_active_transfer(client_id: int) -> TransferState:
	for element in _active_transfer_arr:
		var state: TransferState = element
		if state.receiver_id == client_id:
			return state
	
	return null


func _on_StateFreeze_all_clients_frozen():
	# NOTE: This signal is only fired on the server.
	_waiting_for_state_freeze = false
	check_if_can_start_transfer()
