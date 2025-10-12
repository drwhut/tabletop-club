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

signal entry_requested(pack, type, entry)

onready var _load_button = $VBoxContainer/HBoxContainer/LoadButton
onready var _preview_filter = $VBoxContainer/PreviewFilter
onready var _status = $VBoxContainer/HBoxContainer/StatusLabel

export(Dictionary) var db_types = {}
export(String) var load_button_text = "Load"
export(String) var status_text_one = "Loaded %s."
export(String) var status_text_multiple = "Loaded %d assets."

# Re-configure the preview filter, forcing it to read the AssetDB again.
# Use this if you know the AssetDB contents have changed.
func reconfigure() -> void:
	_preview_filter.setup()

func _ready():
	_preview_filter.db_types = db_types
	_load_button.text = load_button_text
	connect("gui_input", self, "_on_gui_input")
	
func _on_gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.doubleclick and event.button_index == BUTTON_LEFT:
		_on_LoadButton_pressed()

func _on_LoadButton_pressed():
	var previews_selected = get_tree().get_nodes_in_group("preview_selected")
	
	var num_pieces = 0
	var entry_name = ""
	for preview in previews_selected:
		if preview is Preview:
			var entry = preview.get_entry()
			
			num_pieces += 1
			if entry_name.empty():
				entry_name = entry["name"]
			
			var pack = _preview_filter.get_pack()
			var type = _preview_filter.get_type()
			emit_signal("entry_requested", pack, type, entry)
	
	if num_pieces == 0:
		pass
	elif num_pieces == 1:
		_status.text = status_text_one % entry_name
	else:
		_status.text = status_text_multiple % previews_selected.size()

func _on_PreviewDialog_about_to_show():
	_preview_filter.display_previews()

func _on_PreviewDialog_popup_hide():
	_preview_filter.clear_previews()

func _on_PreviewFilter_preview_clicked(_preview: ObjectPreview, _event: InputEventMouseButton):
	var none_selected = get_tree().get_nodes_in_group("preview_selected").empty()
	_load_button.disabled = none_selected
