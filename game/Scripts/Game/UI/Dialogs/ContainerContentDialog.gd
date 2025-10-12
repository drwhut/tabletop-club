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

extends WindowDialog

signal take_all_from(container)
signal take_from(container, names)

onready var _preview_grid = $VBoxContainer/ObjectPreviewGrid
onready var _take_button = $VBoxContainer/HBoxContainer/TakeButton
onready var _take_all_button = $VBoxContainer/HBoxContainer/TakeAllButton

var _last_container: PieceContainer = null

# Display the contents of the given container.
# container: The container to display the contents of.
func display_contents(container: PieceContainer) -> void:
	_last_container = container
	
	var container_name = container.piece_entry["name"]
	window_title = tr("Contents of %s") % container_name
	
	_take_button.disabled = true
	_take_all_button.disabled = true
	
	_preview_grid.empty_text = tr("%s is empty.") % container_name
	_preview_grid.reset()

func _on_ObjectPreviewGrid_preview_clicked(_preview: ObjectPreview, _event: InputEventMouseButton):
	var none_selected = get_tree().get_nodes_in_group("preview_selected").empty()
	_take_button.disabled = none_selected

func _on_ObjectPreviewGrid_requesting_objects(start: int, length: int):
	var objects = []
	
	var piece_names = _last_container.get_piece_names()
	for i in range(start, start+length):
		if i >= piece_names.size():
			break
		
		var duplicate = _last_container.duplicate_piece(piece_names[i])
		objects.append(duplicate)
	
	_take_all_button.disabled = objects.empty()
	
	var after = max(0, piece_names.size() - start - length)
	_preview_grid.provide_objects(objects, after)

func _on_TakeAllButton_pressed():
	emit_signal("take_all_from", _last_container)

func _on_TakeButton_pressed():
	var previews_selected = get_tree().get_nodes_in_group("preview_selected")
	var take_out_names = []
	for preview in previews_selected:
		if preview is ObjectPreview:
			# The original name of the node should have been duplicated.
			var piece_name = preview.get_piece_name()
			if not piece_name.empty():
				take_out_names.append(piece_name)
	
	emit_signal("take_from", _last_container, take_out_names)
