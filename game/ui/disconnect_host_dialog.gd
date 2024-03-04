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

## A panel that appears when a client disconnects from the host in the middle of
## a multiplayer game.


## Fired if the player wants to save and return to the main menu.
signal save_and_return_to_main_menu()


## Explain that the room was sealed, instead of the connection being lost.
export(bool) var room_sealed: bool setget set_room_sealed, is_room_sealed


onready var _connection_lost_label := $MarginContainer/MainContainer/LabelContainer/ConnectionLostLabel
onready var _room_sealed_label := $MarginContainer/MainContainer/LabelContainer/RoomSealedLabel


func is_room_sealed() -> bool:
	return _room_sealed_label.visible


func set_room_sealed(value: bool) -> void:
	_room_sealed_label.visible = value
	_connection_lost_label.visible = not value


func _on_ContinueButton_pressed():
	visible = false


func _on_ReturnButton_pressed():
	visible = false
	emit_signal("save_and_return_to_main_menu")
