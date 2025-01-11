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

extends MenuButton

## A button visually representing a player in the lobby.


## The background colour of the button.
var bg_color: Color setget set_bg_color, get_bg_color

## Should the host icon be shown next to the player's name?
var host_icon := false setget set_host_icon

## The ID of the player that this button represents. If the value is not zero,
## then the button will automatically adjust it's appearance based on the lobby
## signals. If it is zero, then no automation takes place.
var player_id := 0 setget set_player_id


func _init():
	# If the player's name is still the default "Player", then it may be
	# automatically translated, which we don't want since we want the text to be
	# the player's name exactly as it is written.
	set_message_translation(false)


func _ready():
	# We want each button to have its own instances of styles, as it's pretty
	# likely that each player will have their own colour associated with them.
	var style_hover: StyleBoxFlat = get_stylebox("hover")
	add_stylebox_override("hover", style_hover.duplicate())
	var style_pressed: StyleBoxFlat = get_stylebox("pressed")
	add_stylebox_override("pressed", style_pressed.duplicate())
	var style_focus: StyleBoxFlat = get_stylebox("focus")
	add_stylebox_override("focus", style_focus.duplicate())
	var style_disabled: StyleBoxFlat = get_stylebox("disabled")
	add_stylebox_override("disabled", style_disabled.duplicate())
	var style_normal: StyleBoxFlat = get_stylebox("normal")
	add_stylebox_override("normal", style_normal.duplicate())
	
	# If [member player_id] is not zero, we want to detect the Lobby's signals
	# and adjust the appearance of the button if something changes with the
	# player we are representing.
	Lobby.connect("player_id_changed", self, "_on_Lobby_player_id_changed")
	Lobby.connect("player_modified", self, "_on_Lobby_player_modified")
	Lobby.connect("player_removed", self, "_on_Lobby_player_removed")


func get_bg_color() -> Color:
	var style_normal: StyleBoxFlat = get_stylebox("normal")
	return style_normal.bg_color


func set_bg_color(value: Color) -> void:
	var style_hover: StyleBoxFlat = get_stylebox("hover")
	var style_pressed: StyleBoxFlat = get_stylebox("pressed")
	var style_focus: StyleBoxFlat = get_stylebox("focus")
	var style_disabled: StyleBoxFlat = get_stylebox("disabled")
	var style_normal: StyleBoxFlat = get_stylebox("normal")
	
	style_hover.bg_color = value
	style_pressed.bg_color = value
	style_focus.bg_color = value
	style_disabled.bg_color = value
	style_normal.bg_color = value
	
	var text_color := Color.black if value.get_luminance() > 0.5 else Color.white
	
	add_color_override("font_color", text_color)
	add_color_override("font_color_disabled", text_color)
	add_color_override("font_color_focus", text_color)
	add_color_override("font_color_hover", text_color)
	add_color_override("font_color_pressed", text_color)
	
	style_hover.border_color = text_color
	style_pressed.border_color = text_color
	style_focus.border_color = text_color
	style_disabled.border_color = text_color
	style_normal.border_color = text_color


func set_host_icon(value: bool) -> void:
	host_icon = value
	_update_host_icon()


func set_player_id(value: int) -> void:
	if value < 0:
		push_error("Invalid value for player ID '%d'" % value)
		return
	
	player_id = value
	if player_id == 0:
		return
	
	var player := Lobby.get_player(player_id)
	if player == null:
		push_error("Player with ID '%d' does not exist" % player_id)
		return
	
	set_text(player.name)
	set_bg_color(player.color)
	set_host_icon(player_id == 1)


# Update the appearance of the host icon based on if [member host_icon] is true,
# and the colour of [member bg_color]. Note that if the colour changes, we will
# want to update the icon so that it is clearly visible.
func _update_host_icon() -> void:
	if host_icon:
		if get_bg_color().get_luminance() > 0.5:
			icon = preload("res://icons/host_icon_black.svg")
		else:
			icon = preload("res://icons/host_icon_white.svg")
	else:
		icon = null


func _on_Lobby_player_id_changed(player: Player, old_id: int):
	if old_id != player_id:
		return
	
	player_id = player.id
	
	# The player may have either been the host, or has now become the host.
	set_host_icon(player.id == 1)


func _on_Lobby_player_modified(player: Player):
	if player.id != player_id:
		return
	
	# The ID has not changed, but the name and colour might have.
	set_text(player.name)
	set_bg_color(player.color)
	
	# We may need to change the host icon if the colour has changed luminance.
	_update_host_icon()


func _on_Lobby_player_removed(player: Player, _reason: int):
	if player.id != player_id:
		return
	
	# Remove the button from the scene tree when the player leaves.
	queue_free()
