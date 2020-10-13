# open-tabletop
# Copyright (c) 2020 Benjamin 'drwhut' Beddows
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

signal clicked()

onready var _description = $HBoxContainer/VBoxContainer/Description
onready var _name = $Name
onready var _pack = $HBoxContainer/VBoxContainer/Pack
onready var _texture = $HBoxContainer/Texture

var _skybox_entry: Dictionary = {}

# Check if the preview is selected.
# Returns: If the preview is selected.
func is_selected() -> bool:
	return "[u]" in _name.bbcode_text

# Get the skybox entry associated with this preview.
# Returns: The skybox entry this preview is representing.
func get_skybox_entry() -> Dictionary:
	return _skybox_entry

# Set the preview to be selected or not.
# selected: Whether the preview should be selected.
func set_selected(selected: bool) -> void:
	if is_selected() and not selected:
		_name.bbcode_text = _name.bbcode_text.replace("[u]", "").replace("[/u]", "")
		remove_from_group("skyboxes_selected")
	elif not is_selected() and selected:
		_name.bbcode_text = "[u]" + _name.bbcode_text + "[/u]"
		add_to_group("skyboxes_selected")

# Set the skybox preview details using an entry from the AssetDB.
# pack_name: The name of the pack the skybox belongs to.
# skybox_entry: The skybox this preview should represent.
func set_skybox(pack_name: String, skybox_entry: Dictionary) -> void:
	_skybox_entry = skybox_entry
	
	_name.bbcode_text = skybox_entry["name"].replace("[", "[ ") # Security!
	_pack.text = "from " + pack_name
	_description.text = skybox_entry["description"]
	
	var texture: Texture = load(skybox_entry["texture_path"])
	_texture.texture = texture

func _on_SkyboxPreview_gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT and event.pressed:
			emit_signal("clicked")
			
			for selected in get_tree().get_nodes_in_group("skyboxes_selected"):
				if selected != self:
					selected.set_selected(false)
			
			set_selected(true)
