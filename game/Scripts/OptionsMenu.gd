# open-tabletop
# Copyright (c) 2020 drwhut
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

signal applying_options(config)

const OPTIONS_FILE_PATH = "user://options.cfg"

onready var _reimport_confirm = $ReimportConfirm
onready var _tab_container = $MarginContainer/VBoxContainer/TabContainer

func _ready():
	var config = _create_config_from_current()
	_load_file(config)
	_set_current_with_config(config)
	_apply_config(config)
 
# Apply the changes made and save them in the options file.
func _apply_changes() -> void:
	var config = _create_config_from_current()
	_save_file(config)
	_apply_config(config)

# Apply the given options. Not all settings can be applied here, e.g. the
# controls settings will need to be applied by the camera controller.
# It can be assumed that the entire list of values are in the config.
# config: The options to apply.
func _apply_config(config: ConfigFile) -> void:
	emit_signal("applying_options", config)
	
	var window_mode_id = config.get_value("video", "window_mode")
	var borderless = false
	var fullscreen = false
	var maximized = false
	
	if window_mode_id >= 1:
		borderless = true
		if window_mode_id == 1:
			maximized = true
		elif window_mode_id == 2:
			fullscreen = true
	
	OS.window_fullscreen = fullscreen
	OS.window_borderless = borderless
	OS.window_maximized = maximized
	
	OS.vsync_enabled = config.get_value("video", "vsync")

# Create a config file from the current options.
# Returns: A config file whose values are based on the current options.
func _create_config_from_current() -> ConfigFile:
	var config = ConfigFile.new()
	
	for tab in _tab_container.get_children():
		var tab_name = _keyify_string(tab.name)
		
		var grid = tab.get_node("GridContainer")
		
		if not grid:
			push_error("Tab " + tab.name + " has no GridContainer child!")
			continue
		
		for i in range(0, grid.get_child_count(), 2):
			# Skip over children that aren't actually options.
			if not grid.get_child(i) is Label:
				continue
			
			var key: Label = grid.get_child(i)
			var value: Control = grid.get_child(i + 1)
			
			var key_name = _keyify_string(key.text)
			var key_value = null
			
			if value is CheckBox:
				key_value = value.pressed
			elif value is OptionButton:
				key_value = value.selected
			else:
				push_error(value.name + " is an unknown type!")
			
			config.set_value(tab_name, key_name, key_value)
	
	return config

# Make a string suitable to be a key in a config file.
# Returns: A key-string.
# string: The string to keyify.
func _keyify_string(string: String) -> String:
	return string.strip_edges().to_lower().replace(" ", "_")

# Load the options from the options file to the given config file.
# config: The config to overwrite.
func _load_file(config: ConfigFile) -> void:
	var file = ConfigFile.new()
	var err = file.load(OPTIONS_FILE_PATH)
	
	if err == OK:
		for section in file.get_sections():
			if config.has_section(section):
				for key in file.get_section_keys(section):
					if config.has_section_key(section, key):
						var old_value = config.get_value(section, key)
						var new_value = file.get_value(section, key)
						
						if typeof(old_value) == typeof(new_value):
							config.set_value(section, key, new_value)
						else:
							push_warning("Option " + section + "/" + key + " is the wrong type, ignoring.")
	else:
		push_error("Failed to load options (error " + str(err) + ")")

# Save the given options to the option file.
# config: The options to save.
func _save_file(config: ConfigFile) -> void:
	config.save(OPTIONS_FILE_PATH)

# Set the current values with the given config file.
# It is assumed that the options are all validated.
# config: The values to set.
func _set_current_with_config(config: ConfigFile) -> void:
	for tab in _tab_container.get_children():
		var tab_name = _keyify_string(tab.name)
		
		var grid = tab.get_node("GridContainer")
		
		if not grid:
			push_error("Tab " + tab.name + " has no GridContainer child!")
			continue
		
		for i in range(0, grid.get_child_count(), 2):
			# Skip over children that aren't actually options.
			if not grid.get_child(i) is Label:
				continue
			
			var key: Label = grid.get_child(i)
			var value: Control = grid.get_child(i + 1)
			
			var key_name = _keyify_string(key.text)
			var key_value = config.get_value(tab_name, key_name)
			
			if key_value:
				if value is CheckBox:
					value.pressed = key_value
				elif value is OptionButton:
					value.selected = key_value
				else:
					push_error(value.name + " is an unknown type!")

func _on_OKButton_pressed():
	_apply_changes()
	visible = false

func _on_ApplyButton_pressed():
	_apply_changes()

func _on_BackButton_pressed():
	visible = false

func _on_ReimportButton_pressed():
	_reimport_confirm.popup_centered()

func _on_ReimportConfirm_confirmed():
	var dir = Directory.new()
	var err = dir.open("user://.import")
	
	if err == OK:
		dir.list_dir_begin(true, true)
		
		var file = dir.get_next()
		while file:
			err = dir.remove(file)
			if err:
				push_error("Failed to remove " + file + " (error " + str(err) + ")")
			file = dir.get_next()
		
		Global.restart_game()
	else:
		push_error("Failed to open the import cache directory (error " + str(err) + ")")
