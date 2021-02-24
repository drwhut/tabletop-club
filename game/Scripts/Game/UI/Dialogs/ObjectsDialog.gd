# open-tabletop
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

extends WindowDialog

signal piece_requested(piece_entry)

onready var _add_button = $VBoxContainer/HBoxContainer/AddButton
onready var _preview_filter = $VBoxContainer/PreviewFilter
onready var _status = $VBoxContainer/HBoxContainer/StatusLabel

func _on_AddButton_pressed():
	var previews_selected = get_tree().get_nodes_in_group("preview_selected")
	
	var num_pieces = 0
	var piece_name = ""
	for preview in previews_selected:
		if preview is ObjectPreview:
			var piece_entry = preview.get_piece_entry()
			
			num_pieces += 1
			if piece_name.empty():
				piece_name = piece_entry["name"]
			
			emit_signal("piece_requested", piece_entry)
	
	if num_pieces == 0:
		pass
	elif num_pieces == 1:
		_status.text = "Added %s." % piece_name
	else:
		_status.text = "Added %d objects." % previews_selected.size()

func _on_PreviewFilter_preview_clicked(_preview: ObjectPreview, _event: InputEventMouseButton):
	var none_selected = get_tree().get_nodes_in_group("preview_selected").empty()
	_add_button.disabled = none_selected
