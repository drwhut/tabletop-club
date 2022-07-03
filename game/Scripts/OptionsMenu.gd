# tabletop-club
# Copyright (c) 2020-2022 Benjamin 'drwhut' Beddows.
# Copyright (c) 2021-2022 Tabletop Club contributors (see game/CREDITS.tres).
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
signal locale_changed(locale)

var LOCALES = [
	{ "locale": "", "name": tr("System Default") },
	{ "locale": "de", "name": "Deutsch" },
	{ "locale": "en", "name": "English" },
	{ "locale": "fr", "name": "Français" },
	{ "locale": "nl", "name": "Nederlands" },
	{ "locale": "ru", "name": "Русский" }
]

const OPTIONS_FILE_PATH = "user://options.cfg"

onready var _binding_background = $BindingBackground
onready var _key_bindings_parent = $"MarginContainer/VBoxContainer/TabContainer/Key Bindings/GridContainer"
onready var _language_button = $MarginContainer/VBoxContainer/TabContainer/General/GridContainer/LanguageButton
onready var _open_assets_button = $MarginContainer/VBoxContainer/TabContainer/General/GridContainer/OpenAssetsButton
onready var _reimport_confirm = $ReimportConfirm
onready var _reset_bindings_confirm = $ResetBindingsConfirm
onready var _restart_required_dialog = $RestartRequiredDialog
onready var _tab_container = $MarginContainer/VBoxContainer/TabContainer

var _action_to_bind = ""
var _restart_popup_shown = false

func _ready():
	for locale_meta in LOCALES:
		var locale = locale_meta["locale"]
		var name = locale_meta["name"]
		var index = _language_button.get_item_count()
		_language_button.add_item(name)
		_language_button.set_item_metadata(index, locale)
	
	var config = _create_config_from_current()
	_load_file(config)
	_set_current_with_config(config)
	
	# Wait until the end of the frame to apply the changes, so that other nodes
	# have called the ready function as well.
	call_deferred("_apply_config", config)
	
	# Hook up the signal for rebinding an action from all of the BindButtons.
	for node in _key_bindings_parent.get_children():
		if node is BindButton:
			node.connect("rebinding_action", self, "_on_rebinding_action")
	
	# Opening folders is not supported on OSX.
	if OS.get_name() == "OSX":
		_open_assets_button.disabled = true

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
	
	#########
	# AUDIO #
	#########
	
	_apply_audio_config(config)
	
	################
	# KEY BINDINGS #
	################
	
	for action in config.get_section_keys("key_bindings"):
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
			InputMap.action_add_event(action, config.get_value("key_bindings", action))
	
	#########
	# VIDEO #
	#########
	
	var window_mode_id = config.get_value("video", "window_mode")
	var borderless = false
	var fullscreen = false
	var maximized = OS.window_maximized
	
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
	
	var shadow_filter = 1
	var shadow_size = 4096
	var shadow_detail_id = config.get_value("video", "shadow_detail")
	
	match shadow_detail_id:
		0:
			shadow_filter = 1 # PCF5.
			shadow_size = 2048
		1:
			shadow_filter = 1 # PCF5.
			shadow_size = 4096
		2:
			shadow_filter = 2 # PCF13.
			shadow_size = 8192
		3:
			shadow_filter = 2 # PCF13.
			shadow_size = 16384
	
	# The game needs to be restarted for these changes to take effect.
	var override_file = ConfigFile.new()
	override_file.set_value("rendering", "quality/directional_shadow/size", shadow_size)
	override_file.set_value("rendering", "quality/shadow_atlas/size", shadow_size)
	override_file.set_value("rendering", "quality/shadows/filter_mode", shadow_filter)
	override_file.save("user://override.cfg")
	
	var msaa = Viewport.MSAA_DISABLED
	var msaa_id = config.get_value("video", "msaa")
	
	match msaa_id:
		1:
			msaa = Viewport.MSAA_2X
		2:
			msaa = Viewport.MSAA_4X
		3:
			msaa = Viewport.MSAA_8X
		4:
			msaa = Viewport.MSAA_16X
	
	get_viewport().msaa = msaa

# Apply the audio options in the given config. We need to be able to do this
# separately to the rest of the options, as the volume sliders should affect
# the audio levels immediately.
# config: The options to apply.
func _apply_audio_config(config: ConfigFile) -> void:
	for volume_key in config.get_section_keys("audio"):
		var bus_name = volume_key.split("_")[0].capitalize()
		var bus_index = AudioServer.get_bus_index(bus_name)
		var bus_volume = config.get_value("audio", volume_key)
		
		AudioServer.set_bus_mute(bus_index, bus_volume == 0)
		if bus_volume > 0:
			var bus_db = _volume_to_db(bus_volume)
			AudioServer.set_bus_volume_db(bus_index, bus_db)

# Create a config file from the current options.
# Returns: A config file whose values are based on the current options.
func _create_config_from_current() -> ConfigFile:
	var config = ConfigFile.new()
	
	for tab in _tab_container.get_children():
		if tab is OptionsTab:
			var section_name = tab.section_name
			
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
				
				var key_name = _keyify_string(key.name)
				var key_value = null
				
				if value is BindButton:
					# Special case for key bindings: saving the action name as
					# the key is more efficient, since we can just bind it on
					# load straight away.
					key_name = value.action
					key_value = value.get_button_input_event()
				elif value is CheckBox:
					key_value = value.pressed
				elif value is ColorPicker:
					key_value = value.color
				elif value is ColorPickerButton:
					key_value = value.color
				elif value is LineEdit:
					key_value = value.text
				elif value is OptionButton:
					if key_name == "language":
						# Save the locale instead of the index.
						key_value = value.get_selected_metadata()
					else:
						key_value = value.selected
				elif value is Slider:
					key_value = value.value
				elif value is SpinBox:
					key_value = value.value
				else:
					push_error(value.name + " is an unknown type!")
				
				config.set_value(section_name, key_name, key_value)
	
	return config

# Make a string suitable to be a key in a config file.
# Returns: A key-string.
# string: The string to keyify.
func _keyify_string(string: String) -> String:
	var from = string.strip_edges()
	var out = ""
	
	var hit_lower = false
	
	for i in range(from.length()):
		var ch = from.substr(i, 1)
		var lower = ch.to_lower()
		
		if lower == ch:
			hit_lower = true
		else:
			if hit_lower and (not out.ends_with("_")):
				out += "_"
		
		out += lower
	
	return out

# Load the options from the options file to the given config file.
# config: The config to overwrite.
func _load_file(config: ConfigFile) -> void:
	var check = File.new()
	if not check.file_exists(OPTIONS_FILE_PATH):
		return
	
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
		print("Failed to load options (error ", err, ")")

# Save the given options to the option file.
# config: The options to save.
func _save_file(config: ConfigFile) -> void:
	config.save(OPTIONS_FILE_PATH)

# Set the current values with the given config file.
# It is assumed that the options are all validated.
# config: The values to set.
func _set_current_with_config(config: ConfigFile) -> void:
	for tab in _tab_container.get_children():
		if tab is OptionsTab:
			var section_name = tab.section_name
			
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
				
				var key_name = _keyify_string(key.name)
				# Special case for key bindings: the key is the name of the
				# action that is being bound, not the label.
				if section_name == "key_bindings" and value is BindButton:
					key_name = value.action
				var key_value = config.get_value(section_name, key_name)
				
				if key_value != null:
					if value is BindButton:
						value.input_event = key_value
						value.update_text()
					elif value is CheckBox:
						value.pressed = key_value
					elif value is ColorPicker:
						value.color = key_value
					elif value is ColorPickerButton:
						value.color = key_value
					elif value is LineEdit:
						value.text = key_value
					elif value is OptionButton:
						if key_name == "language":
							# Load the locale instead of the index.
							var locale = key_value
							var index = -1
							for locale_index in range(len(LOCALES)):
								if LOCALES[locale_index]["locale"] == locale:
									index = locale_index
									break
							if index >= 0:
								value.selected = index
						else:
							value.selected = key_value
					elif value is Slider:
						value.value = key_value
					elif value is SpinBox:
						value.value = key_value
					else:
						push_error(value.name + " is an unknown type!")

# Show the restart required popup if it hasn't already been shown to the user.
func _show_restart_popup() -> void:
	if not _restart_popup_shown:
		_restart_required_dialog.popup_centered()
		_restart_popup_shown = true

# Convert a volume value to a decibel value.
# Returns: The associated decibel value.
# volume: The volume to convert.
func _volume_to_db(volume: float) -> float:
	return 8.656170245 * log(volume)

func _on_rebinding_action(action: String) -> void:
	_action_to_bind = action
	_binding_background.visible = true

func _on_OKButton_pressed():
	_apply_changes()
	visible = false

func _on_ApplyButton_pressed():
	_apply_changes()

func _on_BackButton_pressed():
	visible = false

func _on_BindingBackground_unhandled_input(event: InputEvent):
	if not _action_to_bind.empty():
		var valid = false
		if event is InputEventKey:
			valid = true
		elif event is InputEventMouseButton:
			valid = true
		
		if valid:
			for node in _key_bindings_parent.get_children():
				if node is BindButton:
					if node.action == _action_to_bind:
						node.input_event = event
						node.update_text()
			
			_action_to_bind = ""
			_binding_background.visible = false

func _on_CancelBindButton_pressed():
	_binding_background.visible = false

func _on_EffectsVolumeSlider_value_changed(_value: float):
	_apply_audio_config(_create_config_from_current())

func _on_LanguageButton_item_selected(index: int):
	var locale = LOCALES[index]["locale"]
	if locale.empty():
		locale = Global.system_locale
	TranslationServer.set_locale(locale)
	
	emit_signal("locale_changed", locale)

func _on_MasterVolumeSlider_value_changed(_value: float):
	_apply_audio_config(_create_config_from_current())

func _on_MusicVolumeSlider_value_changed(_value: float):
	_apply_audio_config(_create_config_from_current())

func _on_OpenAssetsButton_pressed():
	var asset_paths = AssetDB.get_asset_paths()
	if asset_paths.empty():
		return
	
	# Opening folders is not supported on OSX.
	if OS.get_name() == "OSX":
		return
	
	var dir = Directory.new()
	var found = false
	for dir_path in asset_paths:
		var err = dir.open(dir_path)
		if err == OK:
			found = true
			break
	
	# If no asset directory exists, make the first one in the list.
	if not found:
		var err = dir.open(".")
		if err == OK:
			var path = asset_paths[0]
			err = dir.make_dir_recursive(path)
			if err == OK:
				err = dir.open(path)
				if err == OK:
					found = true
				else:
					print("Failed to open directory at ", path, " (error ", err, ")")
			else:
				print("Failed to create directory at ", path, " (error ", err, ")")
		else:
			print("Failed to open current working directory (error ", err, ")")
	
	if found:
		OS.shell_open(dir.get_current_dir())

func _on_ReimportButton_pressed():
	_reimport_confirm.popup_centered()

func _on_ReimportConfirm_confirmed():
	AssetDB.clear_db()
	
	var dir = Directory.new()
	var err = dir.open("user://.import")
	if err == OK:
		dir.list_dir_begin(true, true)
		
		var file = dir.get_next()
		while file:
			err = dir.remove(file)
			if err:
				print("Failed to remove '", file, "' (error ", err, ")")
			file = dir.get_next()
	else:
		print("Failed to open the import cache directory (error ", err, ")")
	
	err = dir.open("user://assets")
	if err == OK:
		dir.list_dir_begin(true, true)
		
		var pack_name = dir.get_next()
		while pack_name:
			if dir.dir_exists(pack_name):
				var pack_dir = Directory.new()
				err = pack_dir.open("user://assets/" + pack_name)
				
				if err == OK:
					for subfolder in AssetDB.ASSET_PACK_SUBFOLDERS:
						if pack_dir.dir_exists(subfolder):
							var sub_dir = Directory.new()
							err = sub_dir.open("user://assets/" + pack_name + "/" + subfolder)
							
							if err == OK:
								sub_dir.list_dir_begin(true, true)
								
								var file = sub_dir.get_next()
								while file:
									err = sub_dir.remove(file)
									if err:
										print("Failed to remove '", pack_name, "/", subfolder, "/", file, "' (error ", err, ")")
									file = sub_dir.get_next()
							else:
								print("Failed to open '", pack_name, "/", subfolder, "' imported directory (error ", err, ")")
				else:
					print("Failed to open '", pack_name, "' imported directory (error ", err, ")")
			pack_name = dir.get_next()
	else:
		print("Failed to open the imported assets directory (error ", err, ")")
	
	Global.restart_game()

func _on_ResetBindingsButton_pressed():
	_reset_bindings_confirm.popup_centered()

func _on_ResetBindingsConfirm_confirmed():
	for node in _key_bindings_parent.get_children():
		if node is BindButton:
			var project_setting = ProjectSettings.get_setting("input/" + node.action)
			if project_setting:
				var events = project_setting.events
				var event = null
				if not events.empty():
					event = events[0]
				node.input_event = event
				node.update_text()

func _on_ShadowDetailButton_item_selected(_index: int):
	_show_restart_popup()

func _on_SoundsVolumeSlider_value_changed(_value: float):
	_apply_audio_config(_create_config_from_current())
