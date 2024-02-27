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


onready var _host_icon := $MarginContainer/MainContainer/PrimaryContainer/OptionContainer/HostIcon
onready var _join_icon := $MarginContainer/MainContainer/PrimaryContainer/OptionContainer/JoinIcon
onready var _code_enter_container := $MarginContainer/MainContainer/PrimaryContainer/OptionContainer/CodeEnterContainer
onready var _code_edit_0 := $MarginContainer/MainContainer/PrimaryContainer/OptionContainer/CodeEnterContainer/CharEditContainer/CodeEdit0
onready var _code_edit_1 := $MarginContainer/MainContainer/PrimaryContainer/OptionContainer/CodeEnterContainer/CharEditContainer/CodeEdit1
onready var _code_edit_2 := $MarginContainer/MainContainer/PrimaryContainer/OptionContainer/CodeEnterContainer/CharEditContainer/CodeEdit2
onready var _code_edit_3 := $MarginContainer/MainContainer/PrimaryContainer/OptionContainer/CodeEnterContainer/CharEditContainer/CodeEdit3
onready var _show_code_check_box := $MarginContainer/MainContainer/PrimaryContainer/OptionContainer/ShowCodeCheckBox

# TODO: Make array typed in 4.x.
onready var _code_edit_list: Array = [ _code_edit_0, _code_edit_1, _code_edit_2,
		_code_edit_3 ]

onready var _info_label := $MarginContainer/MainContainer/PrimaryContainer/InfoLabel


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
	
	_show_code_check_box.visible = (
		setup_mode == SETUP_HOST_USING_ROOM_CODE or
		setup_mode == SETUP_JOIN_USING_ROOM_CODE
	)
	
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


func get_show_room_code() -> bool:
	return _show_code_check_box.pressed


func set_show_room_code(value: bool) -> void:
	_show_code_check_box.pressed = value


func _on_MultiplayerSetupPanel_about_to_show():
	# Set the focus manually to the control that the player will most likely
	# want to interact with at the start.
	match _setup_mode:
		SETUP_HOST_USING_ROOM_CODE:
			pass
		SETUP_JOIN_USING_ROOM_CODE:
			_code_edit_0.call_deferred("take_focus")
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


func _on_CodeEdit_text_entered(new_text: String, index: int):
	pass # Replace with function body.


func _on_ShowCodeCheckBox_toggled(button_pressed: bool):
	for element in _code_edit_list:
		var code_edit: CharEdit = element
		code_edit.secret = not button_pressed
