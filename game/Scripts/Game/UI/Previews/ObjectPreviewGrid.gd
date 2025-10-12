# tabletop-club
# Copyright (c) 2020-2025 Benjamin 'drwhut' Beddows.
# Copyright (c) 2021-2025 Tabletop Club contributors (see game/CREDITS.tres).
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

# The reason this is an editor script is so that we can adjust the number of
# rows and columns in the container and be able to immediately see the result
# in the editor.
tool
extends VBoxContainer

class_name ObjectPreviewGrid

signal preview_clicked(preview, event)
signal requesting_objects(start, length)

export(int, 1, 10) var columns: int = 1 setget set_columns, get_columns
export(int, 1, 10) var rows: int = 1 setget set_rows, get_rows
export(String) var empty_text: String = "" setget set_empty_text, get_empty_text

var _page_index: int = 0
var _page_last: int = 0
var _start: int = 0

var _empty_label: Label
var _preview_container: GridContainer

var _first_button: Button
var _previous_button: Button
var _page_label: Label
var _next_button: Button
var _last_button: Button

var _object_preview = preload("res://Scenes/Game/UI/Previews/ObjectPreview.tscn")

# Get the number of columns in the grid.
# Returns: The number of columns being displayed.
func get_columns() -> int:
	return _preview_container.columns

# Get the text that is displayed when there a no objects being shown.
# Returns: The text shown when there are no objects.
func get_empty_text() -> String:
	return _empty_label.text

# Get the number of previews in the grid.
# Returns: The number of previews being displayed.
func get_preview_count() -> int:
	return get_columns() * get_rows()

# Get the number of rows in the grid.
# Returns: The number of rows being displayed.
func get_rows() -> int:
	return rows

# Provide the preview grid with the set of objects it requested.
# objects: The array of objects the grid wanted. It can be made up of both
# orphan piece nodes and piece entries. If empty, the empty text is displayed.
# after: The number of pieces that should come after this array. This is used
# to calculate the total number of pages.
func provide_objects(objects: Array, after: int) -> void:
	if Engine.editor_hint:
		return
	
	_empty_label.visible = objects.empty()
	_preview_container.visible = not objects.empty()
	
	# Make sure none of the previews are selected.
	if is_inside_tree():
		get_tree().call_group("preview_selected", "set_selected", false)
	
	for i in range(get_preview_count()):
		var preview: ObjectPreview = _preview_container.get_child(i)
		if i < objects.size():
			var piece = objects[i]
			if piece is Piece:
				if not piece.is_inside_tree():
					preview.set_piece(piece)
				else:
					push_error("Piece %d in object array is not an orphan node!" % i)
			elif piece is Dictionary:
				preview.set_entry(piece)
			else:
				push_error("Element %d in object array is not a piece or piece entry!" % i)
		else:
			preview.clear()
	
	_page_index = _start / get_preview_count()
	_page_last = _page_index + int(ceil(floor(after) / get_preview_count()))
	
	_page_label.text = tr("Page %d/%d") % [_page_index+1, _page_last+1]
	
	_first_button.disabled = true
	_previous_button.disabled = true
	_next_button.disabled = true
	_last_button.disabled = true
	
	if _page_index > 0:
		_first_button.disabled = false
		_previous_button.disabled = false
	if _page_index < _page_last:
		_next_button.disabled = false
		_last_button.disabled = false

# Reset the preview grid. This should be called when it is about to be
# displayed.
func reset() -> void:
	if Engine.editor_hint:
		return
	
	_request_objects(0)

# Set the number of columns in the grid.
# num_cols: The number of columns to display.
func set_columns(num_cols: int) -> void:
	assert(num_cols > 0)
	_preview_container.columns = num_cols
	
	_setup_previews()

# Set the text that is displayed when there a no objects being shown.
# text: The text shown when there are no objects.
func set_empty_text(text: String) -> void:
	_empty_label.text = text

# Set the number of rows in the grid.
# num_rows: The number of rows to display.
func set_rows(num_rows: int) -> void:
	assert(num_rows > 0)
	rows = num_rows
	
	_setup_previews()

func _init():
	# If we're in the editor, make sure there are no children when we start.
	for child in get_children():
		remove_child(child)
		child.queue_free()
	
	_empty_label = Label.new()
	_empty_label.visible = false
	_empty_label.align = Label.ALIGN_CENTER
	_empty_label.valign = Label.VALIGN_CENTER
	_empty_label.size_flags_horizontal = SIZE_EXPAND_FILL
	_empty_label.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(_empty_label)
	
	_preview_container = GridContainer.new()
	_preview_container.size_flags_horizontal = SIZE_EXPAND_FILL
	_preview_container.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(_preview_container)
	
	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = SIZE_EXPAND_FILL
	add_child(hbox)
	
	_first_button = Button.new()
	_first_button.text = "<<"
	_first_button.connect("pressed", self, "_on_first_button_pressed")
	hbox.add_child(_first_button)
	
	_previous_button = Button.new()
	_previous_button.text = "<"
	_previous_button.connect("pressed", self, "_on_previous_button_pressed")
	hbox.add_child(_previous_button)
	
	_page_label = Label.new()
	_page_label.align = Label.ALIGN_CENTER
	_page_label.size_flags_horizontal = SIZE_EXPAND_FILL
	hbox.add_child(_page_label)
	
	_next_button = Button.new()
	_next_button.text = ">"
	_next_button.connect("pressed", self, "_on_next_button_pressed")
	hbox.add_child(_next_button)
	
	_last_button = Button.new()
	_last_button.text = ">>"
	_last_button.connect("pressed", self, "_on_last_button_pressed")
	hbox.add_child(_last_button)

# Request objects from a given start index.
# start: The start index to request.
func _request_objects(start: int) -> void:
	assert(start >= 0)
	
	_start = start
	emit_signal("requesting_objects", _start, get_preview_count())

# Setup the previews in the grid container.
func _setup_previews() -> void:
	var current_children = _preview_container.get_child_count()
	var target_children = get_preview_count()
	
	while current_children < target_children:
		var preview = _object_preview.instance()
		if not Engine.editor_hint:
			preview.allow_multiple_select = true
		preview.connect("clicked", self, "_on_preview_clicked")
		_preview_container.add_child(preview)

		current_children += 1
	
	while current_children > target_children:
		var child = _preview_container.get_child(current_children - 1)
		_preview_container.remove_child(child)
		child.queue_free()
		
		current_children -= 1

func _on_first_button_pressed():
	_request_objects(0)

func _on_previous_button_pressed():
	_request_objects(int(max(0, _start - get_preview_count())))

func _on_next_button_pressed():
	var max_start = _page_last * get_preview_count()
	_request_objects(int(min(_start + get_preview_count(), max_start)))

func _on_last_button_pressed():
	_request_objects(_page_last * get_preview_count())

func _on_preview_clicked(preview: ObjectPreview, event: InputEventMouseButton):
	# Forward the signal outside the grid.
	emit_signal("preview_clicked", preview, event)
