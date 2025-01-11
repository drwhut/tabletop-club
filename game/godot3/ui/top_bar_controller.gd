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

## The bar shown at the top of the in-game UI, when a controller is being used.


## Fired when the player wants to open the objects window.
signal open_objects_window()

## Fired when the player wants to open the game menu.
signal open_game_menu()


## Sets whether the internal viewport should detect input from the player.
export var input_disabled := false setget set_input_disabled


onready var _controller_scroll: ControllerScrollContainer = \
		$HBoxContainer/ViewportContainer/Viewport/ControllerScrollContainer
onready var _viewport: Viewport = $HBoxContainer/ViewportContainer/Viewport


func _ready():
	# Exported variable is set before viewport is ready.
	set_input_disabled(input_disabled)
	
	_controller_scroll.add_button("objects", preload("res://icons/pawn_icon.svg"))
	_controller_scroll.add_button("games", preload("res://icons/collection_icon.svg"))
	_controller_scroll.add_button("room", preload("res://icons/table_icon.svg"))
	_controller_scroll.add_button("notebook", preload("res://icons/notebook_icon.svg"))
	_controller_scroll.add_button("undo", preload("res://icons/undo_icon.svg"))
	_controller_scroll.add_button("redo", preload("res://icons/undo_icon_flipped.svg"))
	_controller_scroll.add_button("load", preload("res://icons/load_icon.svg"))
	_controller_scroll.add_button("save", preload("res://icons/save_icon.svg"))
	_controller_scroll.add_button("menu", preload("res://icons/menu_icon.svg"))
	
	_set_button_text()


func set_input_disabled(new_value: bool) -> void:
	input_disabled = new_value
	
	if _viewport == null:
		return
	
	_viewport.gui_disable_input = input_disabled


# Set the names of the buttons based on the current locale.
func _set_button_text() -> void:
	for element in _controller_scroll.get_buttons():
		var button: VerticalButton = element
		
		var text := "#ERROR#"
		match button.name:
			"objects":
				text = tr("Objects")
			"games":
				text = tr("Games")
			"room":
				text = tr("Room")
			"notebook":
				text = tr("Notebook")
			"undo":
				text = tr("Undo")
			"redo":
				text = tr("Redo")
			"load":
				text = tr("Load")
			"save":
				text = tr("Save")
			"menu":
				text = tr("Menu")
		
		button.vertical_text = text


func _on_ControllerScrollContainer_button_pressed(button_id: String):
	match button_id:
		"objects":
			emit_signal("open_objects_window")
		"games":
			pass
		"room":
			pass
		"notebook":
			pass
		"undo":
			pass
		"redo":
			pass
		"load":
			pass
		"save":
			pass
		"menu":
			emit_signal("open_game_menu")
		_:
			push_error("Unknown button name '%s'" % button_id)
