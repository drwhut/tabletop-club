# tabletop-club
# Copyright (c) 2020-2021 Benjamin 'drwhut' Beddows
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

class_name Preview

signal clicked(preview, event)

export(bool) var allow_multiple_select: bool = false
export(bool) var selectable: bool = true

var _entry: Dictionary = {}

# Clear the display.
func clear() -> void:
	_entry = {}
	
	set_selected(false)
	_clear_gui()

# Get the entry that the preview is displaying.
# Returns: The entry the preview is displaying, empty if it isn't displaying
# anything.
func get_entry() -> Dictionary:
	return _entry

# Check if the preview is selected.
# Returns: If the preview is selected.
func is_selected() -> bool:
	return is_in_group("preview_selected")

# Set the entry the preview will display.
# entry: The entry the preview will display.
func set_entry(entry: Dictionary) -> void:
	if entry.empty():
		return
	
	_entry = entry
	
	_set_entry_gui(entry)

# Set if the preview should be selected.
# selected: If the preview should be selected.
func set_selected(selected: bool) -> void:
	if not selectable:
		return
	
	if selected and (not is_in_group("preview_selected")):
		add_to_group("preview_selected")
	elif (not selected) and is_in_group("preview_selected"):
		remove_from_group("preview_selected")
	
	_set_selected_gui(selected)

func _ready():
	connect("gui_input", self, "_on_gui_input")
	connect("visibility_changed", self, "_on_visibility_changed")

# Called when the preview is cleared.
func _clear_gui() -> void:
	pass

# Called when the preview entry is changed.
# _new_entry: The new entry to display. It is guaranteed to not be empty.
func _set_entry_gui(_new_entry: Dictionary) -> void:
	pass

# Called when the selected flag has been changed.
# _selected: If the preview is now selected.
func _set_selected_gui(_selected: bool) -> void:
	pass

func _on_gui_input(event):
	# Completely ignore any events if the preview isn't displaying anything.
	if _entry.empty():
		return
	
	if event is InputEventMouseButton:
		emit_signal("clicked", self, event)
		
		# If the preview has been clicked, register it as selected.
		if event.pressed:
			if event.button_index == BUTTON_LEFT:
				if not (allow_multiple_select and event.control):
					get_tree().call_group("preview_selected", "set_selected", false)
				set_selected(not is_selected())

func _on_visibility_changed():
	set_selected(false)
