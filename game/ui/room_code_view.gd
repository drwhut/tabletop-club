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

extends Control

## Shows the room code to the player.
##
## The room code can be copied to the clipboard, and it can also be made secret,
## which hides the characters from the UI.


## The room code that should be displayed to the player.
var room_code := "" setget set_room_code

## Should the room code be hidden from the player?
var secret := false setget set_secret


onready var _room_code_label := $RoomCodeLabel
onready var _clipboard_button := $ButtonContainer/ClipboardButton
onready var _clipboard_timer := $ClipboardTimer
onready var _toggle_secret_button := $ButtonContainer/ToggleSecretButton


func _ready():
	# Don't translate the room code, as it should always be shown as is.
	_room_code_label.set_message_translation(false)


func set_room_code(value: String) -> void:
	room_code = value
	_update_label()


func set_secret(value: bool) -> void:
	secret = value
	_update_label()
	
	if secret:
		_toggle_secret_button.icon = preload("res://icons/show_icon.svg")
	else:
		_toggle_secret_button.icon = preload("res://icons/hidden_area_icon.svg")


func _update_label() -> void:
	if secret:
		_room_code_label.text = "****"
	else:
		_room_code_label.text = room_code


func _on_ClipboardButton_pressed():
	OS.clipboard = room_code
	
	_clipboard_button.icon = preload("res://icons/tick_icon.svg")
	_clipboard_timer.start()


func _on_ToggleSecretButton_pressed():
	set_secret(not secret)


func _on_ClipboardTimer_timeout():
	_clipboard_button.icon = preload("res://icons/copy_icon.svg")
