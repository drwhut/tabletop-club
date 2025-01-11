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

class_name AssetBreadcrumb
extends HBoxContainer

## A display of where the user currently is in a directory of assets.


## Fired when one of the directory buttons is pressed.
signal dir_selected(dir_path)


## The font to use for the text in the breadcrumb.
const FONT := preload("res://fonts/res/asset_menu_font_minor.tres")


## Append a button representing a directory to the end of the list.
func append_dir(dir_path: String, take_focus: bool = false) -> void:
	# Check to see if there is already a node that isn't queued for deletion -
	# if so, we need to add a divider before we add the button.
	var node_exists := false
	for element in get_children():
		var child: Node = element
		if not child.is_queued_for_deletion():
			node_exists = true
			break
	
	if node_exists:
		var divider := Label.new()
		divider.text = "/"
		divider.valign = Label.VALIGN_CENTER
		divider.size_flags_vertical = Control.SIZE_EXPAND_FILL
		divider.add_font_override("font", FONT)
		add_child(divider)
	
	var dir_button := Button.new()
	dir_button.text = AssetTree.get_node_name(dir_path.get_file())
	dir_button.add_font_override("font", FONT)
	dir_button.connect("pressed", self, "_on_button_pressed", [ dir_path ])
	add_child(dir_button)
	
	if take_focus:
		dir_button.grab_focus()


## Set the directory represented by the list.
func set_dir(dir_path: String) -> void:
	var index_with_focus := -1
	for index in range(get_child_count()):
		var child: Control = get_child(index)
		if child.has_focus():
			index_with_focus = index
		child.queue_free()
	
	# Add an extra "/" to the end so that the last element counts as a directory
	# for the purposes of the next step.
	dir_path += "/"
	
	# Skip the first "/" character.
	var num_added := 0
	for sub_length in range(1, dir_path.length()):
		if dir_path[sub_length] != "/":
			continue
		
		append_dir(dir_path.substr(0, sub_length), num_added == index_with_focus)
		num_added += 1


func _on_button_pressed(dir_path: String):
	emit_signal("dir_selected", dir_path)
