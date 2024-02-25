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


# Describes how we setup the multiplayer network.
var _setup_mode := SETUP_HOST_USING_ROOM_CODE


onready var _host_icon := $MarginContainer/MainContainer/PrimaryContainer/OptionContainer/HostIcon
onready var _join_icon := $MarginContainer/MainContainer/PrimaryContainer/OptionContainer/JoinIcon

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
