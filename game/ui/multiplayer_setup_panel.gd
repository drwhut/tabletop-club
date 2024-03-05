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

extends AttentionPanel

## A panel for setting up a multiplayer network, either by requesting the master
## server using a room code, or with an IP address for a direct connection.


## Fired when the network setup has been completed, and we can enter the game.
## [b]NOTE:[/b] If the network is using ENet instead of WebRTC, [param room_code]
## will be empty.
signal setup_completed(room_code, show_code)


## The list of possible configurations for setting up the network.
enum {
	SETUP_HOST_USING_ROOM_CODE,
	SETUP_HOST_USING_IP_ADDRESS,
	SETUP_JOIN_USING_ROOM_CODE,
	SETUP_JOIN_USING_IP_ADDRESS,
	SETUP_MAX ## Used for validation only.
}


## Does the player want the room code to be visible on the screen?
var show_room_code: bool setget set_show_room_code, get_show_room_code


# Describes how we setup the multiplayer network.
var _setup_mode := SETUP_HOST_USING_ROOM_CODE

# The last room code that we received from the NetworkManager.
var _last_room_code_received := ""


onready var _host_icon := $MarginContainer/MainContainer/PrimaryContainer/OptionContainer/HostIcon
onready var _join_icon := $MarginContainer/MainContainer/PrimaryContainer/OptionContainer/JoinIcon
onready var _code_enter_container := $MarginContainer/MainContainer/PrimaryContainer/OptionContainer/CodeEnterContainer
onready var _code_edit_0 := $MarginContainer/MainContainer/PrimaryContainer/OptionContainer/CodeEnterContainer/CharEditContainer/CodeEdit0
onready var _code_edit_1 := $MarginContainer/MainContainer/PrimaryContainer/OptionContainer/CodeEnterContainer/CharEditContainer/CodeEdit1
onready var _code_edit_2 := $MarginContainer/MainContainer/PrimaryContainer/OptionContainer/CodeEnterContainer/CharEditContainer/CodeEdit2
onready var _code_edit_3 := $MarginContainer/MainContainer/PrimaryContainer/OptionContainer/CodeEnterContainer/CharEditContainer/CodeEdit3
onready var _code_error_label := $MarginContainer/MainContainer/PrimaryContainer/OptionContainer/CodeEnterContainer/CodeErrorLabel
onready var _show_code_check_box := $MarginContainer/MainContainer/PrimaryContainer/OptionContainer/ShowCodeCheckBox

# TODO: Make array typed in 4.x.
onready var _code_edit_list: Array = [ _code_edit_0, _code_edit_1, _code_edit_2,
		_code_edit_3 ]

onready var _info_label := $MarginContainer/MainContainer/PrimaryContainer/InfoLabel

onready var _host_button := $MarginContainer/MainContainer/SecondaryContainer/HostButton
onready var _join_button := $MarginContainer/MainContainer/SecondaryContainer/JoinButton
onready var _status_container := $MarginContainer/MainContainer/SecondaryContainer/StatusContainer
onready var _status_label := $MarginContainer/MainContainer/SecondaryContainer/StatusContainer/StatusLabel
onready var _error_container := $MarginContainer/MainContainer/SecondaryContainer/ErrorContainer
onready var _error_label := $MarginContainer/MainContainer/SecondaryContainer/ErrorContainer/ErrorLabel
onready var _retry_button := $MarginContainer/MainContainer/SecondaryContainer/ErrorContainer/RetryButton

onready var _back_button := $MarginContainer/MainContainer/TertiaryContainer/BackButton
onready var _cancel_button := $MarginContainer/MainContainer/TertiaryContainer/CancelButton


func _ready():
	MasterServer.connect("connection_established", self,
			"_on_MasterServer_connection_established")
	
	NetworkManager.connect("connection_to_host_established", self,
			"_on_NetworkManager_connection_to_host_established")
	NetworkManager.connect("connection_to_host_failed", self,
			"_on_NetworkManager_connection_to_host_failed")
	NetworkManager.connect("connection_to_host_closed", self,
			"_on_NetworkManager_connection_to_host_closed")
	NetworkManager.connect("connection_to_host_lost", self,
			"_on_NetworkManager_connection_to_host_lost")
	
	NetworkManager.connect("network_init", self, "_on_NetworkManager_network_init")
	NetworkManager.connect("setup_failed", self, "_on_NetworkManager_setup_failed")
	NetworkManager.connect("lobby_server_disconnected", self,
			"_on_NetworkManager_lobby_server_disconnected")
	
	Lobby.connect("failed_to_add_self", self, "_on_Lobby_failed_to_add_self")
	
	# NetworkManager.network_init is also connected to the lobby, and if we are
	# the host, then it will automatically add us as a player. Connect this in
	# deferred mode so that we have time to grab the room code from network_init.
	Lobby.connect("self_added", self, "_on_Lobby_self_added", [], CONNECT_DEFERRED)


## Reset the panel to its default state. Depending on the [code]SETUP_*[/code]
## mode that is provided, information will be displayed to the player, and
## certain options may become visible.
func reset(setup_mode: int) -> void:
	if setup_mode < 0 or setup_mode >= SETUP_MAX:
		push_error("Invalid setup mode '%d'" % setup_mode)
		return
	
	_setup_mode = setup_mode
	
	_host_icon.visible = (
		setup_mode == SETUP_HOST_USING_ROOM_CODE or
		setup_mode == SETUP_HOST_USING_IP_ADDRESS
	)
	
	_join_icon.visible = (
		setup_mode == SETUP_JOIN_USING_ROOM_CODE or
		setup_mode == SETUP_JOIN_USING_IP_ADDRESS
	)
	
	_code_enter_container.visible = (setup_mode == SETUP_JOIN_USING_ROOM_CODE)
	_code_error_label.visible = false
	
	_show_code_check_box.visible = (
		setup_mode == SETUP_HOST_USING_ROOM_CODE or
		setup_mode == SETUP_JOIN_USING_ROOM_CODE
	)
	
	_host_button.visible = (
		setup_mode == SETUP_HOST_USING_ROOM_CODE or
		setup_mode == SETUP_HOST_USING_IP_ADDRESS
	)
	
	_join_button.visible = (
		setup_mode == SETUP_JOIN_USING_ROOM_CODE or
		setup_mode == SETUP_JOIN_USING_IP_ADDRESS
	)
	
	_status_container.visible = false
	_error_container.visible = false
	
	_back_button.visible = true
	_cancel_button.visible = false
	
	close_on_cancel = true
	
	var info_text := ""
	match setup_mode:
		SETUP_HOST_USING_ROOM_CODE:
			info_text += tr("The game will connect to the lobby server and ask it to create a room for you.")
			info_text += "\n\n" + tr("Once it is created, you can then invite other players to the room by sharing the room code with them.")
			info_text += "\n\n" + tr("NOTE: An internet connection is required. Your system may ask for permission to allow incoming connections from other players.")
		SETUP_HOST_USING_IP_ADDRESS:
			pass
		SETUP_JOIN_USING_ROOM_CODE:
			info_text += tr("The game will connect to the lobby server and ask it to join the room with the given room code.")
			info_text += "\n\n" + tr("The lobby server will then attempt to establish a connection between your client and the host's.")
			info_text += "\n\n" + tr("NOTE: An internet connection is required. Your system may ask for permission to allow incoming connections from the host.")
		SETUP_JOIN_USING_IP_ADDRESS:
			pass
	
	_info_label.text = info_text


## If the panel is currently trying to set up the multiplayer network, cancel
## the attempt and show the [param error_text] to the player.
func show_error(error_text: String) -> void:
	if not visible:
		print("MultiplayerSetupPanel: Error could not be shown, panel not visible. (%s)" % error_text)
		return
	
	if not _status_container.visible:
		print("MultiplayerSetupPanel: Error is already being shown. (%s)" % error_text)
		return
	
	_status_container.visible = false
	_error_container.visible = true
	_retry_button.grab_focus()
	
	_back_button.visible = true
	_cancel_button.visible = false
	
	# No longer trying to connect, Esc key can close the window again.
	close_on_cancel = true
	
	_error_label.text = error_text


func get_show_room_code() -> bool:
	return _show_code_check_box.pressed


func set_show_room_code(value: bool) -> void:
	_show_code_check_box.pressed = value


func _on_MultiplayerSetupPanel_about_to_show():
	# Set the focus manually to the control that the player will most likely
	# want to interact with at the start.
	match _setup_mode:
		SETUP_HOST_USING_ROOM_CODE:
			_host_button.call_deferred("grab_focus")
		SETUP_JOIN_USING_ROOM_CODE:
			for index in range(_code_edit_list.size()):
				var code_edit: CharEdit = _code_edit_list[index]
				if code_edit.text.empty() or index + 1 == _code_edit_list.size():
					code_edit.call_deferred("take_focus")
					break
		SETUP_HOST_USING_IP_ADDRESS:
			pass
		SETUP_JOIN_USING_IP_ADDRESS:
			pass


func _on_CodeEdit_text_change_rejected(rejected_substring: String, index: int):
	# This most likely means that the user wants to paste the full four-letter
	# code all at once. We can help by taking the substring that went over the
	# maximum length and passing each character to subsequent CharEdits.
	var rest_of_code := rejected_substring.to_upper()
	var substr_index := 0
	
	while index + substr_index + 1 < _code_edit_list.size():
		if substr_index >= rest_of_code.length():
			break
		
		var current_char := rest_of_code[substr_index]
		if not current_char in CharEdit.VALID_CHARACTERS:
			break
		
		var code_index := index + substr_index + 1
		var code_edit: CharEdit = _code_edit_list[code_index]
		code_edit.text = current_char
		
		substr_index += 1
	
	# The 'text_changed' signal will be fired just after this, which will end up
	# setting the focus to the (index+1)th CharEdit. So afterwards, we'll re-set
	# the focus to the CharEdit that was last affected by this callback.
	if substr_index > 0:
		var send_focus_to: CharEdit = _code_edit_list[index + substr_index]
		
		# Have the CharEdit take focus two frames in the future. This is
		# required for take_focus() to be called after 'text_changed'.
		send_focus_to.call_deferred("call_deferred", "take_focus")


func _on_CodeEdit_text_changed(new_text: String, index: int):
	if new_text.empty():
		# The character was just removed, so we want to move the focus to the
		# previous CharEdit so that the user can immediately backspace that
		# character.
		if index <= 0:
			return
		
		var to_focus: CharEdit = _code_edit_list[index - 1]
		to_focus.take_focus()
	else:
		# A character was just set, so move the focus to the next CharEdit so
		# that the user can immediately type in the next character.
		if index + 1 >= _code_edit_list.size():
			return
		
		var to_focus: CharEdit = _code_edit_list[index + 1]
		to_focus.take_focus()


func _on_CodeEdit_text_entered(_new_text: String, index: int):
	if index + 1 == _code_edit_list.size():
		_on_JoinButton_pressed()


func _on_ShowCodeCheckBox_toggled(button_pressed: bool):
	for element in _code_edit_list:
		var code_edit: CharEdit = element
		code_edit.secret = not button_pressed


func _on_HostButton_pressed():
	_host_button.visible = false
	_status_container.visible = true
	_error_container.visible = false
	
	_back_button.visible = false
	_cancel_button.visible = true
	_cancel_button.grab_focus()
	
	# The Esc key should not close the window while we are trying to connect.
	close_on_cancel = false
	
	if _setup_mode == SETUP_HOST_USING_ROOM_CODE:
		_status_label.text = tr("Connecting to the lobby server…")
		NetworkManager.start_server_webrtc()


func _on_JoinButton_pressed():
	# First, we need to check if the room code the player has given us is valid.
	var room_code := ""
	for element in _code_edit_list:
		var code_edit: CharEdit = element
		var code_char: String = code_edit.text
		if code_char.empty():
			_code_error_label.visible = true
			return
		
		if not code_char in CharEdit.VALID_CHARACTERS:
			_code_error_label.visible = true
			return
		
		room_code += code_char
	
	_code_error_label.visible = false
	
	_join_button.visible = false
	_status_container.visible = true
	_error_container.visible = false
	
	_back_button.visible = false
	_cancel_button.visible = true
	_cancel_button.grab_focus()
	
	# The Esc key should not close the window while we are trying to connect.
	close_on_cancel = false
	
	if _setup_mode == SETUP_JOIN_USING_ROOM_CODE:
		_status_label.text = tr("Connecting to the lobby server…")
		NetworkManager.start_client_webrtc(room_code)


func _on_RetryButton_pressed():
	if (
		_setup_mode == SETUP_HOST_USING_ROOM_CODE or
		_setup_mode == SETUP_HOST_USING_IP_ADDRESS
	):
		_on_HostButton_pressed()
	else:
		_on_JoinButton_pressed()


func _on_BackButton_pressed():
	visible = false


func _on_CancelButton_pressed():
	# Close all connections and reset to the default UI state.
	NetworkManager.stop()
	reset(_setup_mode)
	
	# The cancel button will be hidden, so move the focus to a button that is
	# now visible.
	if _host_button.visible:
		_host_button.grab_focus()
	elif _join_button.visible:
		_join_button.grab_focus()
	else:
		_back_button.grab_focus()


func _on_MasterServer_connection_established():
	if _setup_mode == SETUP_HOST_USING_ROOM_CODE:
		_status_label.text = tr("Creating a new room…")
	elif _setup_mode == SETUP_JOIN_USING_ROOM_CODE:
		_status_label.text = tr("Joining the room…")


func _on_NetworkManager_connection_to_host_established():
	# The setup is not quite done yet - we still need to check the host's client
	# version (in the main Game script), as well as add ourselves to the Lobby.
	_status_label.text = tr("Sending client details to the host…")


func _on_NetworkManager_connection_to_host_failed():
	var text := tr("Failed to connect to the host. Make sure that your are still connected to the internet, and that the connection isn't being blocked by your system's firewall settings.")
	if _setup_mode == SETUP_JOIN_USING_IP_ADDRESS:
		# Internet connection isn't necessary.
		text = tr("Failed to connect to the host. Make sure the connection isn't being blocked by your system's firewall settings.")
	
	show_error(text)


func _on_NetworkManager_connection_to_host_closed():
	# Do not continue if we are no longer in setup.
	if not visible:
		return
	
	# It's likely that this was caused by us, the client, after we checked that
	# the client versions did not match. This error message should not be shown,
	# as the Game script should show one before us, but try to set one anyway
	# just in case something else caused the connection to be closed.
	show_error(tr("The connection to the host was closed during setup."))


func _on_NetworkManager_connection_to_host_lost():
	# Do not continue if we are no longer in setup.
	if not visible:
		return
	
	# This will be very rare, but we'll deal with it in case it happens.
	show_error(tr("Lost the connection to the host after it was established."))


func _on_NetworkManager_network_init(room_code: String):
	# This signal can be fired in singleplayer as well.
	if not visible:
		return
	
	_last_room_code_received = room_code
	
	if (
		_setup_mode == SETUP_HOST_USING_ROOM_CODE or
		_setup_mode == SETUP_HOST_USING_IP_ADDRESS
	):
		# We're very close to being done if we are the host - we just need to
		# wait to add ourselves to the lobby.
		pass
	else:
		_status_label.text = tr("Establishing a connection to the host…")


func _on_NetworkManager_setup_failed(err: int):
	var desc: String
	match err:
		ERR_UNAVAILABLE:
			desc = tr("Could not connect to the lobby server. Make sure you are connected to the internet, and that the system's firewall allows the connection.")
		ERR_CANT_CREATE:
			desc = tr("Not enough information was given to create the network.")
		ERR_ALREADY_IN_USE:
			desc = tr("Network was already created, please try again.")
		_:
			desc = tr("<No Description>")
	
	var text := tr("Network setup failed. (Error %d: %s)" % [err, desc])
	show_error(text)


func _on_NetworkManager_lobby_server_disconnected(exit_code: int):
	# Do not continue if we are no longer in setup.
	if not visible:
		return
	
	var desc: String
	match exit_code:
		# TODO: Add standard exit codes as well?
		MasterServer.CODE_GENERIC_ERROR:
			desc = tr("The connection was closed due to a generic error.")
		MasterServer.CODE_UNREACHABLE:
			# This particular code shouldn't be shown, as 'setup_failed' should
			# be fired first with ERR_UNAVAILABLE.
			desc = tr("The connection could not be established.")
		MasterServer.CODE_NOT_IN_LOBBY:
			desc = tr("Sent an invalid request, had not joined a lobby yet.")
		MasterServer.CODE_HOST_DISCONNECTED:
			desc = tr("The host has disconnected from the lobby.")
		MasterServer.CODE_ONLY_HOST_CAN_SEAL:
			desc = tr("Sent an invalid request, only the host can close the lobby.")
		MasterServer.CODE_TOO_MANY_LOBBIES:
			desc = tr("The maximum number of lobbies has been reached, please try again later.")
		MasterServer.CODE_ALREADY_IN_LOBBY:
			desc = tr("Sent an invalid request, had already joined a lobby.")
		MasterServer.CODE_LOBBY_DOES_NOT_EXIST:
			desc = tr("Lobby does not exist. Make sure you have entered the room code correctly.")
		MasterServer.CODE_LOBBY_IS_SEALED:
			desc = tr("Lobby has been closed by the host.")
		MasterServer.CODE_INVALID_FORMAT:
			desc = tr("Sent a request with an invalid format.")
		MasterServer.CODE_LOBBY_REQUIRED:
			desc = tr("Sent an invalid request, room code was missing.")
		MasterServer.CODE_SERVER_ERROR:
			desc = tr("An internal server error occured.")
		MasterServer.CODE_INVALID_DESTINATION:
			desc = tr("Sent an invalid request, destination was invalid.")
		MasterServer.CODE_INVALID_COMMAND:
			desc = tr("Sent an invalid request, unknown command.")
		MasterServer.CODE_TOO_MANY_PEERS:
			desc = tr("The maximum number of clients has been reached, please try again later.")
		MasterServer.CODE_INVALID_MODE:
			desc = tr("Sent an invalid request, used binary mode instead of text mode.")
		MasterServer.CODE_TOO_MANY_CONNECTIONS:
			desc = tr("Too many connections from one location.")
		MasterServer.CODE_RECONNECT_TOO_QUICKLY:
			desc = tr("Connection was rate limited. Please wait a few seconds before trying again.")
		_:
			desc = tr("<No Description>")
	
	var text := tr("The lobby server has disconnected. (Code %d: %s)" % [
			exit_code, desc])
	show_error(text)


func _on_Lobby_failed_to_add_self(err: int):
	var desc: String
	match err:
		ERR_QUERY_FAILED:
			desc = tr("The host denied our request to be added to the lobby.")
		ERR_INVALID_DATA:
			desc = tr("The lobby data sent to us by the host was invalid.")
		_:
			desc = tr("<No Description>")
	
	var text := tr("Failed to join the host's lobby. (Error %d: %s)" % [err, desc])
	show_error(text)


func _on_Lobby_self_added():
	# This signal can be fired in singleplayer as well.
	if not visible:
		return
	
	# Ladies and gentlemen, boys and girls, cats and dogs... it is time.
	# Let's get this show on the road! \o/
	visible = false
	emit_signal("setup_completed", _last_room_code_received,
			_show_code_check_box.pressed)
