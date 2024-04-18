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

class_name DataReceiver
extends Node

## Gives clients the ability to send large amounts of data to the host.
##
## To send data, the client must first send a request to the server, which can
## either accept or deny the request. Once the request is accepted, then the
## client can start sending chunks of the data one at a time, after the server
## has acknowledged each packet.
##
## TODO: Test this class fully once it is complete.


## Fired on the client when a request has been sent to the server.
signal request_sent(data_size)

## Fired on the server when a request has been received from a client.
## NOTE: Requests are accepted or denied automatically.
signal request_received(client_id, data_size)

## Fired on both the client and server when a request is accepted.
signal request_accepted()

## Fired on both the client and server when a request is denied.
signal request_denied()


## Fired on the client when a packet has been sent to the server.
signal packet_sent(packet_id)

## Fired on the server when a packet has been received.
signal packet_received(packet_id)

## Fired on both the client and server when a packet has been acknowledged.
signal packet_acknowledged(packet_id)


## Fired on both the client and server when the transfer is complete.
signal transfer_complete(data_ref)

## Fired on both the client and server when the transfer has failed.
signal transfer_failed()


## The maximum size of a chunk of data, in bytes.
## TODO: Test what happens if multiple clients start sending multiple packets of
## data for different [DataReceiver] nodes.
const MAX_PACKET_SIZE_BYTES := 50000


## The maximum size of data that clients can send, in kilobytes.
export(int, 1000000) var max_size_kb := 100

## TODO: Add reference or NodePath to DataBroadcaster here.


# The current state of the transfer, or null if no transfer is happening.
var _state: TransferState = null


func _process(delta: float):
	if _state == null:
		return
	
	_state.time_since_last_message_sec += delta
	
	# TODO: Do stuff if timeout has been reached.


## Check if the node is active, that is, a transfer is currently ongoing.
func is_active() -> bool:
	return _state != null


## As a client, create a request to send data to the server.
## Returns [code]true[/code] if the request was sent successfully.
func create_request(data_ref: DataRef) -> bool:
	if data_ref == null:
		push_error("%s: Cannot create request, reference is null" % name)
		return false
	
	if data_ref.data.empty():
		push_error("%s: Cannot create request, data is empty" % name)
		return false
	
	if _state != null:
		push_error("%s: Cannot create request, transfer is ongoing" % name)
		return false
	
	if get_tree().get_network_unique_id() == 1:
		push_error("%s: Cannot create request, this is the server" % name)
		return false
	
	# TODO: As the server, check if we are sending data via a DataBroadcaster.
	
	_state = TransferState.new()
	_state.other_id = 1
	_state.data_ref = data_ref
	_state.data_size = data_ref.data.size()
	
	print("%s: Requesting to send %d bytes of data to the server..." % [name,
			_state.data_size])
	rpc("send_request", _state.data_size)
	emit_signal("request_sent", _state.data_size)
	return true


## Send a transfer request to the server.
master func send_request(data_size: int) -> void:
	var client_id := get_tree().get_rpc_sender_id()
	print("%s: Received request to send %d bytes of data from client %d..." % [
			name, data_size, client_id])
	emit_signal("request_received", client_id, data_size)
	
	if data_size <= 0:
		print("%s: Denying request, invalid data size" % name)
		rpc_id(client_id, "deny_request")
		emit_signal("request_denied")
		return
	
	if data_size / 1000 > max_size_kb:
		print("%s: Denying request, data is too large" % name)
		rpc_id(client_id, "deny_request")
		emit_signal("request_denied")
		return
	
	if _state != null:
		print("%s: Denying request, transfer is currently ongoing" % name)
		rpc_id(client_id, "deny_request")
		emit_signal("request_denied")
		return
	
	_state = TransferState.new()
	_state.other_id = client_id
	_state.receiver_accepted = true
	_state.data_ref = DataRef.new()
	_state.data_size = data_size
	
	print("%s: Accepting transfer request..." % name)
	rpc_id(client_id, "accept_request")
	emit_signal("request_accepted")


## Called by the server when it has accepted our request.
puppet func accept_request() -> void:
	if _state == null:
		push_warning("%s: Server accepted our request, but not request is pending" % name)
		return
	
	if _state.receiver_accepted:
		push_warning("%s: Server accepted our request more than once" % name)
		return
	
	print("%s: Server accepted our request" % name)
	emit_signal("request_accepted")
	_state.receiver_accepted = true
	
	# TODO: Send the first packet.


## Called by the server when it has denied our request.
puppet func deny_request() -> void:
	if _state == null:
		push_warning("%s: deny_request was called, but no request is pending" % name)
		return
	
	# TODO: Should this be a warning, or its own UI element?
	push_warning("%s: Server denied our request. Please wait a moment and try again." % name)
	emit_signal("request_denied")
	_state = null
