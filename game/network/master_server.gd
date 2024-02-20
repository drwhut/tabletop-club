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

## The interface for the master server, which is a central server that keeps
## track of all of the multiplayer lobbies that are currently open.
##
## You can find the source code for the master server here:
## [url]https://github.com/drwhut/tabletop_club_master_server[/url]
##
## [b]NOTE:[/b] This script is a modified version of the webrtc_signalling demo,
## which is licensed under the MIT license, and can be found here:
## [url]https://github.com/godotengine/godot-demo-projects/blob/master/networking/webrtc_signaling/client/ws_webrtc_client.gd[/url]


## Fired when the connection to the master server is established successfully.
signal connection_established()

## Fired when the connection to the master server is closed gracefully.
signal connection_closed(code)

## Fired when an attempt to connect to the master server fails.
signal connection_failed()

## Fired when the connection to the master server is lost unexpectedly.
signal connection_lost()


## The location of the official master server.
const OFFICIAL_URL := "wss://tabletop-club.duckdns.org:9080"


## The web socket client that connects to the master server.
var client := WebSocketClient.new()

## The last disconnect code that was sent by the master server.
var last_close_code := 1000


func _ready():
	client.verify_ssl = true
	
	client.connect("connection_closed", self, "_on_client_connection_closed")
	client.connect("connection_error", self, "_on_client_connection_error")
	client.connect("connection_established", self, "_on_client_connection_established")
	client.connect("data_received", self, "_on_client_data_received")
	client.connect("server_close_request", self, "_on_client_server_close_request")


func _process(_delta: float):
	var conn_status := client.get_connection_status()
	if conn_status != NetworkedMultiplayerPeer.CONNECTION_DISCONNECTED:
		client.poll() # This allows for data transfer each frame.


## Connect to the official master server. Returns [code]OK[/code] on success,
## or an error code otherwise.
## TODO: Make a similar function for connecting to a custom server.
func connect_to_official_server() -> int:
	var conn_status := client.get_connection_status()
	if conn_status != NetworkedMultiplayerPeer.CONNECTION_DISCONNECTED:
		push_error("Cannot connect to the master server, connection already exists or is being made")
		return ERR_ALREADY_IN_USE
	
	print("MasterServer: Connecting to the official master server at '%s'..." % OFFICIAL_URL)
	var err := client.connect_to_url(OFFICIAL_URL)
	if err != OK:
		push_error("Failed to connect to the master server (error: %d)" % err)
	
	return err


## Returns the status of the client's connection to the master server.
## The value will be one of the [NetworkedMultiplayerPeer] constants.
func get_connection_status() -> int:
	return client.get_connection_status()


## Close the connection to the master server if it exists. No error is thrown if
## the connection is already closed.
func close_connection() -> void:
	var conn_status := client.get_connection_status()
	if conn_status != NetworkedMultiplayerPeer.CONNECTION_DISCONNECTED:
		print("MasterServer: Closing the connection...")
		
		# The code 1000 represents a clean disconnect.
		client.disconnect_from_host(1000)
	else:
		print("MasterServer: Cannot close connection, already disconnected.")


func _on_client_connection_closed(was_clean_close: bool):
	if was_clean_close:
		print("MasterServer: Connection was closed cleanly.")
		emit_signal("connection_closed", last_close_code)
	else:
		print("MasterServer: Connection was closed unexpectedly.")
		emit_signal("connection_lost")


func _on_client_connection_error():
	print("MasterServer: Failed to connect to the master server.")
	emit_signal("connection_failed")


func _on_client_connection_established(_protocol: String):
	print("MasterServer: Connection was successfully established.")
	
	# Set the write mode to text only, since we only communicate with the master
	# server using plain text.
	client.get_peer(1).set_write_mode(WebSocketPeer.WRITE_MODE_TEXT)
	
	emit_signal("connection_established")


func _on_client_data_received():
	print("MasterServer: Received a packet from the master server...")


func _on_client_server_close_request(code: int, _reason: String):
	print("MasterServer: Received a close request with code %d." % code)
	
	# The connection will be closed a little bit later, so save the close code
	# for when that happens.
	last_close_code = code
