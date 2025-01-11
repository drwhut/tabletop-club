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

extends WindowDialog

## A settings menu for the AssetWindow.


## Fired when the user changes the layout.
signal layout_changed(new_layout)

## Fired when the user changes the zoom level.
signal zoom_changed(new_zoom)


## The file path to the config file used by this class.
const CONFIG_PATH := "user://assets.cfg"


## The category to use when saving this window's settings.
var category := ""

## The layout chosen by the user.
var layout: int setget set_layout, get_layout

## The zoom chosen by the user.
var zoom: int setget set_zoom, get_zoom


onready var _layout_button: OptionButton = $MarginContainer/GridContainer/LayoutButton
onready var _zoom_slider: Slider = $MarginContainer/GridContainer/ZoomSlider


func _ready():
	# Set up the items for the layout button.
	_layout_button.add_item("", AssetGrid.GridLayout.ICON)
	_layout_button.set_item_icon(0, preload("res://icons/grid_icon.svg"))
	
	_layout_button.add_item("", AssetGrid.GridLayout.LIST)
	_layout_button.set_item_icon(1, preload("res://icons/list_icon.svg"))
	
	_set_layout_button_text()


## Check to see if this window's settings have been saved from a previous
## playthrough, and emit the changed signals if they have.
func check_if_saved() -> void:
	if category.empty():
		push_warning("Cannot check if settings were saved, category not given")
		return
	
	var file := File.new()
	if not file.file_exists(CONFIG_PATH):
		return
	
	var config := AdvancedConfigFile.new()
	var err := config.load(CONFIG_PATH)
	if err != OK:
		push_error("Failed to load '%s' (error: %d)" % [CONFIG_PATH, err])
		return
	
	if config.has_section_key(category, "layout"):
		var prev_layout: int = config.get_value_strict(category, "layout", 0)
		set_layout(prev_layout)
		emit_signal("layout_changed", prev_layout)
	
	if config.has_section_key(category, "zoom"):
		var prev_zoom: int = config.get_value(category, "zoom", 0)
		set_zoom(prev_zoom)
		emit_signal("zoom_changed", prev_zoom)


func get_layout() -> int:
	return _layout_button.get_selected_id()


func get_zoom() -> int:
	return int(_zoom_slider.value)


func set_layout(new_value: int) -> void:
	for index in range(_layout_button.get_item_count()):
		if _layout_button.get_item_id(index) == new_value:
			_layout_button.select(index)
			return
	
	push_error("Item not found for layout ID '%d'" % new_value)


func set_zoom(new_value: int) -> void:
	_zoom_slider.value = new_value


# Set the text for each item in the layout button. This should be called each
# time the locale is changed.
func _set_layout_button_text() -> void:
	_layout_button.set_item_text(0, tr("Icons"))
	_layout_button.set_item_text(1, tr("List"))


func _on_AssetWindowSettings_about_to_show():
	_layout_button.call_deferred("grab_focus")


func _on_AssetWindowSettings_popup_hide():
	if category.empty():
		push_warning("Cannot save settings, category not given")
		return
	
	var cfg_file := ConfigFile.new()
	var file := File.new()
	
	if file.file_exists(CONFIG_PATH):
		var err := cfg_file.load(CONFIG_PATH)
		if err != OK:
			push_error("Failed to load '%s' (error: %d)" % [CONFIG_PATH, err])
			return
	
	cfg_file.set_value(category, "layout", get_layout())
	cfg_file.set_value(category, "zoom", get_zoom())
	
	var err := cfg_file.save(CONFIG_PATH)
	if err != OK:
		push_error("Failed to save '%s' (error: %d)" % [CONFIG_PATH, err])


func _on_LayoutButton_item_selected(_index):
	emit_signal("layout_changed", get_layout())


func _on_ZoomSlider_value_changed(_value):
	emit_signal("zoom_changed", get_zoom())
