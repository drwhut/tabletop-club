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


func get_bg_color() -> Color:
	var style_normal: StyleBoxFlat = get_stylebox("normal")
	return style_normal.bg_color
