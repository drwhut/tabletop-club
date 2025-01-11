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

## A panel that appears if the client disconnects from the master server while
## in the middle of a multiplayer game.


## Is the panel being shown to a client, as opposed to the host?
export(bool) var client := false setget set_client, is_client

## The close code given for the disconnection.
export(int) var close_code := MasterServer.CODE_NORMAL setget set_close_code


onready var _connection_closed_label := $MarginContainer/MainContainer/LabelContainer/ConnectionClosedLabel
onready var _result_client_label := $MarginContainer/MainContainer/LabelContainer/ResultClientLabel
onready var _result_host_label := $MarginContainer/MainContainer/LabelContainer/ResultHostLabel


func is_client() -> bool:
	return _result_client_label.visible


func set_client(value: bool) -> void:
	_result_client_label.visible = value
	_result_host_label.visible = not value


func set_close_code(value: int) -> void:
	close_code = value
	
	if close_code == MasterServer.CODE_UNREACHABLE:
		_connection_closed_label.text = tr("The connection to the lobby server was lost.")
	else:
		_connection_closed_label.text = tr("The connection to the lobby server was closed with code %d.") % close_code


func _on_BackButton_pressed():
	visible = false
