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

signal take_all_from(container)
signal take_from(container, names)

onready var _empty_label = $VBoxContainer/EmptyLabel
onready var _preview_container = $VBoxContainer/PreviewGridContainer

onready var _far_left_button = $VBoxContainer/HBoxContainer/FarLeftButton
onready var _left_button = $VBoxContainer/HBoxContainer/LeftButton
onready var _page_label = $VBoxContainer/HBoxContainer/PageLabel
onready var _right_button = $VBoxContainer/HBoxContainer/RightButton
onready var _far_right_button = $VBoxContainer/HBoxContainer/FarRightButton

onready var _take_button = $VBoxContainer/HBoxContainer2/TakeButton
onready var _take_all_button = $VBoxContainer/HBoxContainer2/TakeAllButton

var _last_container: PieceContainer = null
var _last_page: int = 0

# Display the contents of the given container.
# container: The container to display the contents of.
# page: The page number to display.
func display_contents(container: PieceContainer, page: int = 0):
	page = int(max(0, page))
	
	var container_name = container.piece_entry["name"]
	window_title = "Contents of %s" % container_name
	
	_empty_label.visible = false
	_preview_container.visible = false
	
	_far_left_button.disabled = true
	_left_button.disabled = true
	_right_button.disabled = true
	_far_right_button.disabled = true
	
	_take_button.disabled = true
	_take_all_button.disabled = true
	
	var container_count = container.get_piece_count()
	var page_size = _preview_container.get_child_count()
	var last_page = max(0, (container_count - 1) / page_size)
	page = int(min(page, last_page))
	_page_label.text = "Page %d/%d" % [page+1, last_page+1]
	
	if page > 0:
		_far_left_button.disabled = false
		_left_button.disabled = false
	if page < last_page:
		_right_button.disabled = false
		_far_right_button.disabled = false
	
	if container_count == 0:
		_empty_label.text = "%s is empty." % container_name
		_empty_label.visible = true
	else:
		var piece_names = container.get_piece_names()
		for i in range(page_size):
			var preview: ObjectPreview = _preview_container.get_child(i)
			var item_index = (page * page_size) + i
			if item_index < container_count:
				var duplicate = container.duplicate_piece(piece_names[item_index])
				preview.set_piece(duplicate)
			else:
				preview.clear_piece()
		
		_preview_container.visible = true
		_take_all_button.disabled = false
	
	# Make sure none of the previews look selected now that we've generated a
	# new set of them.
	get_tree().call_group("preview_selected", "set_selected", false)
	
	_last_container = container
	_last_page = page

func _ready():
	for child in _preview_container.get_children():
		if child is ObjectPreview:
			child.connect("clicked", self, "_on_preview_clicked")

func _on_FarLeftButton_pressed():
	display_contents(_last_container, 0)

func _on_FarRightButton_pressed():
	# Assume there will never be less than one piece preview per page.
	display_contents(_last_container, _last_container.get_piece_count())

func _on_LeftButton_pressed():
	display_contents(_last_container, _last_page - 1)

func _on_RightButton_pressed():
	display_contents(_last_container, _last_page + 1)

func _on_preview_clicked(_preview: ObjectPreview, _event: InputEventMouseButton):
	var none_selected = get_tree().get_nodes_in_group("preview_selected").empty()
	_take_button.disabled = none_selected

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
