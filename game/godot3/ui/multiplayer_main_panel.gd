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

## The main multiplayer panel, where players can choose whether they want to
## either host, or join, a room.


## Fired when the player wants to host a room.
signal hosting_room()

## Fired when the player wants to join a room.
signal joining_room()


## If [code]true[/code], the player wants to either share the room, or join
## another room, using an IPv4 address instead of a room code.
var use_ip_address: bool setget set_use_ip_address, get_use_ip_address

## If [code]true[/code], the host and join buttons will not be visible, and the
## player must wait for the importing process to be complete before continuing.
var waiting_for_import: bool setget set_waiting_for_import, is_waiting_for_import


onready var _host_or_join_container := $MainContainer/HostOrJoinContainer
onready var _waiting_container := $MainContainer/WaitingContainer

onready var _use_ip_address_button := $MainContainer/HostOrJoinContainer/IPAddressButton
onready var _host_code_label := $MainContainer/HostOrJoinContainer/GridContainer/HostCodeLabel
onready var _host_ip_label := $MainContainer/HostOrJoinContainer/GridContainer/HostIPLabel
onready var _join_code_label := $MainContainer/HostOrJoinContainer/GridContainer/JoinCodeLabel
onready var _join_ip_label := $MainContainer/HostOrJoinContainer/GridContainer/JoinIPLabel


func get_use_ip_address() -> bool:
	return _use_ip_address_button.pressed


func set_use_ip_address(value: bool) -> void:
	_use_ip_address_button.pressed = value
	
	_host_ip_label.visible = value
	_join_ip_label.visible = value
	_host_code_label.visible = not value
	_join_code_label.visible = not value


func is_waiting_for_import() -> bool:
	return _waiting_container.visible


func set_waiting_for_import(value: bool) -> void:
	_waiting_container.visible = value
	_host_or_join_container.visible = not value


func _on_HostButton_pressed():
	visible = false
	emit_signal("hosting_room")


func _on_JoinButton_pressed():
	visible = false
	emit_signal("joining_room")


func _on_IPAddressButton_toggled(button_pressed: bool):
	set_use_ip_address(button_pressed)


func _on_CloseButton_pressed():
	visible = false
