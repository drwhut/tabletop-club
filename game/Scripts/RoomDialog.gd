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

extends WindowDialog

signal requesting_room_details()
signal setting_skybox(skybox_entry)

onready var _apply_button = $VBoxContainer/HBoxContainer2/ApplyButton
onready var _skyboxes = $VBoxContainer/HBoxContainer/VBoxContainer/ScrollContainer/Skyboxes

# Set the room database contents, based on the database given.
# assets: The database from the AssetDB.
func set_piece_db(assets: Dictionary) -> void:
	for child in _skyboxes.get_children():
		_skyboxes.remove_child(child)
		child.queue_free()
	
	# Create a skybox preview for the "default" skybox.	
	_add_skybox_preview("OpenTabletop", {
		"description": "The default skybox for OpenTabletop.",
		"name": "Default",
		"texture_path": ""
	})
	
	for pack_name in assets:
		if assets[pack_name].has("skyboxes"):
			for skybox_entry in assets[pack_name]["skyboxes"]:
				_add_skybox_preview(pack_name, skybox_entry)

# Set the room details in the room dialog.
# skybox_path: The texture path to the skybox texture.
func set_room_details(skybox_path: String) -> void:
	for skybox in _skyboxes.get_children():
		var texture_path = skybox.get_skybox_entry()["texture_path"]
		skybox.set_selected(texture_path == skybox_path)

# Add a skybox preview to the list.
# pack_name: The name of the pack the skybox belongs to.
# skybox_entry: The skybox's entry in the asset database.
func _add_skybox_preview(pack_name: String, skybox_entry: Dictionary) -> void:
	var preview = preload("res://Scenes/SkyboxPreview.tscn").instance()
	_skyboxes.add_child(preview)
	
	preview.set_skybox(pack_name, skybox_entry)
	
	preview.connect("clicked", self, "_on_preview_clicked")

func _on_ApplyButton_pressed():
	_apply_button.disabled = true
	
	var skyboxes_selected = get_tree().get_nodes_in_group("skyboxes_selected")
	if skyboxes_selected.size() > 0:
		emit_signal("setting_skybox", skyboxes_selected[0].get_skybox_entry())

func _on_preview_clicked():
	_apply_button.disabled = false

func _on_RoomDialog_about_to_show():
	_apply_button.disabled = true
	emit_signal("requesting_room_details")
