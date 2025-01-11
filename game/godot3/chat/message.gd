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

class_name Message
extends Reference

## A message that is sent and stored in the MessageHub.


## All the possible types of messages that can be sent.
enum {
	TYPE_SAY, ## A public message from a player or the system.
	TYPE_WHISPER, ## A private message from one player to another.
	TYPE_INFO, ## Information regarding a change of state in the game.
	TYPE_WARNING, ## System warnings thrown by the engine.
	TYPE_ERROR, ## System errors thrown by the engine.
	TYPE_MAX ## Used for validation only.
}


## The type of message this is. See the [code]TYPE_*[/code] constants for
## possible values.
var type := TYPE_SAY setget set_type

## The ID of the player this message came from. If the value is [code]0[/code],
## the system generated the message.
var origin := 0 setget set_origin

## The contents of the message.
## [b]NOTE:[/b] When set, the edges of the message are stripped, and all escape
## characters are removed, guaranteeing that the message is only one line.
## [b]WARNING:[/b] This text can potentially be set by players, so always treat
## it as if it was malicious data.
var text := "" setget set_text


func _init(p_type: int, p_text: String, p_origin: int = 0):
	set_type(p_type)
	set_origin(p_origin)
	set_text(p_text)


func set_type(value: int) -> void:
	if value < 0 or value >= TYPE_MAX:
		push_error("Invalid value '%d' for message type" % value)
		return
	
	type = value


func set_origin(value: int) -> void:
	if value < 0:
		value = 0
	
	origin = value


func set_text(value: String) -> void:
	text = value.strip_edges().strip_escapes()
