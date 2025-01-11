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

class_name Player
extends Reference

## Contains details about a player in the lobby, like their name and colour.


## The ID of the player within the multiplayer network.
var id := 1 setget set_id

## The name of the player, without any filtering applied.
var name := "Player" setget set_name

## The player's chosen colour.
var color := Color.white setget set_color


func _init(player_id: int, player_name: String, player_color: Color):
	set_id(player_id)
	set_name(player_name)
	set_color(player_color)


func set_id(value: int) -> void:
	if value < 1:
		push_error("Invalid player ID '%d'" % value)
		return
	
	id = value


func set_name(value: String) -> void:
	# TODO: Find a way to make sure the GameConfig does the exact same set of
	# operations.
	
	# The maximum length of the name is 100 characters.
	value = value.substr(0, 100)
	
	# No leading or trailing spaces, and no escape characters.
	value = value.strip_edges().strip_escapes()
	
	# After whitespace has been cleared, name should not be empty.
	if value.empty():
		push_error("Player name cannot be empty")
		return
	
	name = value


func set_color(value: Color) -> void:
	if not SanityCheck.is_valid_color(value):
		return
	
	# Player colours are always opaque.
	value.a = 1.0
	
	color = value
