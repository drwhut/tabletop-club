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

signal requesting_room_details()
signal setting_lighting(lamp_color, lamp_intensity, lamp_sunlight)
signal setting_skybox(skybox_entry)

onready var _apply_button = $VBoxContainer/HBoxContainer2/ApplyButton
onready var _lamp_color_picker = $VBoxContainer/HBoxContainer/VBoxContainer2/ColorPickerButton
onready var _lamp_intensity_slider = $VBoxContainer/HBoxContainer/VBoxContainer2/HBoxContainer/IntensitySlider
onready var _lamp_intensity_value_label = $VBoxContainer/HBoxContainer/VBoxContainer2/HBoxContainer/IntensityValueLabel
onready var _lamp_type_button = $VBoxContainer/HBoxContainer/VBoxContainer2/TypeButton
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
# lamp_color: The color of the room lamp.
# lamp_intensity: The intensity of the room lamp.
# lamp_sunlight: If the room lamp is emitting sunlight.
func set_room_details(skybox_path: String, lamp_color: Color,
	lamp_intensity: float, lamp_sunlight: bool) -> void:
	
	for skybox in _skyboxes.get_children():
		var texture_path = skybox.get_skybox_entry()["texture_path"]
		skybox.set_selected(texture_path == skybox_path)
	
	_lamp_color_picker.color = lamp_color
	_lamp_intensity_slider.value = lamp_intensity
	_set_lamp_intensity_value_label(lamp_intensity)
	_lamp_type_button.selected = 0 if lamp_sunlight else 1

# Add a skybox preview to the list.
# pack_name: The name of the pack the skybox belongs to.
# skybox_entry: The skybox's entry in the asset database.
func _add_skybox_preview(pack_name: String, skybox_entry: Dictionary) -> void:
	var preview = preload("res://Scenes/Game/UI/Previews/SkyboxPreview.tscn").instance()
	_skyboxes.add_child(preview)
	
	preview.set_skybox(pack_name, skybox_entry)
	
	preview.connect("clicked", self, "_on_preview_clicked")

# Set the lamp intensity value label as a percentage value.
# value: The value to display in the label.
func _set_lamp_intensity_value_label(value: float) -> void:
	_lamp_intensity_value_label.text = str(round(value * 100)) + "%"

func _on_ApplyButton_pressed():
	_apply_button.disabled = true
	
	var skyboxes_selected = get_tree().get_nodes_in_group("skyboxes_selected")
	if skyboxes_selected.size() > 0:
		emit_signal("setting_skybox", skyboxes_selected[0].get_skybox_entry())
	
	emit_signal("setting_lighting", _lamp_color_picker.color,
		_lamp_intensity_slider.value, _lamp_type_button.selected == 0)

func _on_ColorPickerButton_color_changed(_color: Color):
	_apply_button.disabled = false

func _on_preview_clicked():
	_apply_button.disabled = false

func _on_RoomDialog_about_to_show():
	_apply_button.disabled = true
	emit_signal("requesting_room_details")

func _on_IntensitySlider_value_changed(value: float):
	_apply_button.disabled = false
	_set_lamp_intensity_value_label(value)

func _on_TypeButton_item_selected(_index: int):
	_apply_button.disabled = false
