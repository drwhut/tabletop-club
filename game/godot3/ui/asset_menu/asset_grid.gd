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

class_name AssetGrid
extends GridContainer

## A grid of [AssetButton].


## Fired when the user has pressed a folder button.
signal node_selected(node_id)

## Fired when the user has pressed an asset button.
signal asset_selected(asset_entry)


## The different layouts that the asset grid can have.
enum GridLayout {
	ICON,
	LIST,
}


## The number of characters that can be on one line in a tooltip before a new
## line needs to be used.
const MAX_CHARS_PER_HINT_LINE := 80


## The layout that the asset grid uses to display assets.
export(GridLayout) var layout := GridLayout.ICON setget set_layout

## The zoom level for the grid, which determines how big the buttons are.
export(int, 3) var zoom := 1 setget set_zoom


## The [AssetNode] whose contents the grid will display when refreshed.
var asset_node: AssetNode = null


## Refresh the grid to display the contents of [member asset_node] with the
## current settings. This will queue the current nodes to be deleted, and create
## a new set to be added to the scene tree.
func refresh() -> void:
	if asset_node == null:
		push_error("Cannot refresh grid, asset_node is null")
		return
	
	for element in get_children():
		var child: Node = element
		child.queue_free()
	
	# Display directories first.
	# TODO: Make sure these arrays are sorted first, depending on how the user
	# wants us to sort them.
	for element in asset_node.get_children():
		var child_node: AssetNode = element
		
		var dir_button := AssetButton.new()
		dir_button.name = child_node.id
		# TODO: Make sure changing the locale globally changes the name.
		dir_button.text = AssetTree.get_node_name(child_node.id)
		# TODO: Set button icon.
		dir_button.hint = AssetTree.get_node_hint(child_node.id)
		dir_button.folder = true
		dir_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dir_button.connect("pressed", self, "_on_node_button_pressed",
				[ child_node.id ])
		add_child(dir_button)
	
	# Display assets after.
	for element in asset_node.entry_list:
		var asset_entry: AssetEntry = element
		
		var asset_button := AssetButton.new()
		asset_button.name = asset_entry.id
		asset_button.text = asset_entry.name
		# TODO: Create thumbnails for assets, use here.
		asset_button.hint = _add_newlines(asset_entry.desc)
		asset_button.stack = (asset_entry is AssetEntryCollection)
		asset_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		asset_button.connect("pressed", self, "_on_asset_button_pressed",
				[ asset_entry ])
		add_child(asset_button)
	
	# Set the appearance of the new buttons.
	_apply_layout_and_zoom()


## Have the first button in the grid take focus.
func take_focus() -> void:
	for element in get_children():
		var button: AssetButton = element
		if button.is_queued_for_deletion():
			continue
		
		button.take_focus()
		break


func set_layout(new_value: int) -> void:
	if new_value < GridLayout.ICON or new_value > GridLayout.LIST:
		push_error("Invalid value '%d' for grid layout" % new_value)
		return
	
	layout = new_value
	_apply_layout_and_zoom()


func set_zoom(new_value: int) -> void:
	if new_value < 0 or new_value > 3:
		push_error("Invalid value '%d' for grid zoom" % new_value)
		return
	
	zoom = new_value
	_apply_layout_and_zoom()


# Use the configured layout and zoom to adjust the appearance of the buttons.
func _apply_layout_and_zoom() -> void:
	var button_type := 0
	var button_height := 0.0
	var button_font := preload("res://fonts/res/asset_menu_font.tres")
	match layout:
		GridLayout.ICON:
			button_type = AssetButton.ButtonType.VERTICAL
			
			match zoom:
				0:
					columns = 5
					button_height = 100.0
					button_font = preload("res://fonts/res/asset_menu_font_minor.tres")
				1:
					columns = 4
					button_height = 125.0
				2:
					columns = 3
					button_height = 167.0
					button_font = preload("res://fonts/res/asset_menu_font_major.tres")
				3:
					columns = 2
					button_height = 250.0
					button_font = preload("res://fonts/res/asset_menu_font_major.tres")
		GridLayout.LIST:
			button_type = AssetButton.ButtonType.HORIZONTAL
			
			match zoom:
				0:
					columns = 3
					button_height = 50.0
				1:
					columns = 2
					button_height = 50.0
				2:
					columns = 2
					button_height = 80.0
					button_font = preload("res://fonts/res/asset_menu_font_major.tres")
				3:
					columns = 1
					button_height = 80.0
					button_font = preload("res://fonts/res/asset_menu_font_major.tres")
	
	for element in get_children():
		var button: AssetButton = element
		button.appearance = button_type
		button.font_override = button_font
		button.rect_min_size = Vector2(0.0, button_height)


# Add new-line characters to a hint if they are needed to make sure that the
# entire hint is visible on the screen.
func _add_newlines(text: String) -> String:
	var line_length := 0
	for index in range(text.length()):
		var c := text[index]
		if c == "\n":
			line_length = 0
		else:
			line_length += 1
			if c == " " and line_length >= MAX_CHARS_PER_HINT_LINE:
				text[index] = "\n"
				line_length = 0
	
	return text


func _on_asset_button_pressed(asset_entry: AssetEntry):
	emit_signal("asset_selected", asset_entry)


func _on_node_button_pressed(node_id: String):
	emit_signal("node_selected", node_id)
