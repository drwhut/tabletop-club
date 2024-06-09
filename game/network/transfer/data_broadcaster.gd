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


## The maximum amount of data that can be sent over the course of one transfer.
const MAX_COMPRESSED_DATA_SIZE := 5000000 # = 5 MB

## The maximum allowed size of data after it is uncompressed.
const MAX_UNCOMPRESSED_DATA_SIZE := 20000000 # = 20 MB


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


func _process(_delta):
	# TODO: Check timeouts for each of the transfers.
	
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
	var data := plan.get_data()
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
	
	# TODO: Activate StateFreeze for state data. Figure out a clean way to wait
	# for the acknowledge signal from that global script before starting any of
	# the transfers. Note that we do not want to do this for all types of data,
	# so ideally we have a nice solution for all cases.
	
	for element in plan.transfer_ids:
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
	
	# TODO: Send the accept signal to the server.
