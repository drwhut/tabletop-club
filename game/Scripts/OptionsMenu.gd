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

extends Control

signal applying_options(config)
signal keep_video_dialog_hide()
signal locale_changed(locale)

var LOCALES = [
	{ "locale": "", "name": tr("System Default") },
	{ "locale": "bg", "name": "Български" },
	{ "locale": "de", "name": "Deutsch" },
	{ "locale": "en", "name": "English" },
	{ "locale": "eo", "name": "Esperanto" },
	{ "locale": "es", "name": "Español" },
	{ "locale": "fr", "name": "Français" },
	{ "locale": "hu", "name": "Magyar" },
	{ "locale": "id", "name": "Bahasa Indonesia" },
	{ "locale": "it", "name": "Italiano" },
	{ "locale": "ko", "name": "한국어" },
	{ "locale": "nb_NO", "name": "Norsk Bokmål" },
	{ "locale": "nl", "name": "Nederlands" },
	{ "locale": "pl", "name": "Polski" },
	{ "locale": "pt", "name": "Português" },
	{ "locale": "pt_BR", "name": "Português (Brasil)" },
	{ "locale": "ru", "name": "Русский" },
	# Characters are here for Tamil, but Godot's font does not display them.
	{ "locale": "ta", "name": "தமிழ்" },
	{ "locale": "zh", "name": "简体中文" }
]

const OPTIONS_FILE_PATH = "user://options.cfg"

onready var _back_button = $MarginContainer/VBoxContainer/HBoxContainer/BackButton
onready var _binding_background = $BindingBackground
onready var _keep_video_confirm = $KeepVideoConfirm
onready var _key_bindings_parent = $"MarginContainer/VBoxContainer/TabContainer/Key Bindings/GridContainer"
onready var _language_button = $MarginContainer/VBoxContainer/TabContainer/General/GridContainer/LanguageButton
onready var _open_assets_button = $MarginContainer/VBoxContainer/TabContainer/General/GridContainer/OpenAssetsButton
onready var _reimport_confirm = $ReimportConfirm
onready var _reset_bindings_confirm = $ResetBindingsConfirm
onready var _restart_required_dialog = $RestartRequiredDialog
onready var _tab_container = $MarginContainer/VBoxContainer/TabContainer
onready var _window_mode_button = $MarginContainer/VBoxContainer/TabContainer/Video/GridContainer/WindowModeButton

var _action_to_bind = ""
var _bind_ignore_next_enter = false
var _restart_popup_shown = false

func _init():
	# A workaround to ensure that options in drop-down menus are captured by
	# game/Translations/extract_pot.sh, allowing them to be translated.
	# TODO: Find a non-workaround way of allowing the translations.
	var _ignore = ""
	_ignore = tr("Never")
	_ignore = tr("30 seconds")
	_ignore = tr("1 minute")
	_ignore = tr("5 minutes")
	_ignore = tr("10 minutes")
	_ignore = tr("30 minutes")
	
	_ignore = tr("Windowed")
	_ignore = tr("Borderless Fullscreen")
	_ignore = tr("Fullscreen")
	
	_ignore = tr("None")
	_ignore = tr("Low")
	_ignore = tr("Medium")
	_ignore = tr("High")
	_ignore = tr("Very High")
	_ignore = tr("Ultra")
	
	_ignore = tr("Small")
	#_ignore = tr("Medium")
	_ignore = tr("Large")

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
	
	# Connect the "pressed" signal for these buttons, so we can perform actions
	# before the dialog is hidden.
	_keep_video_confirm.get_ok().connect("pressed", self, "_on_KeepVideoConfirm_ok_pressed")
	_keep_video_confirm.get_cancel().connect("pressed", self, "_on_KeepVideoConfirm_cancel_pressed")
	_keep_video_confirm.get_close_button().connect("pressed", self, "_on_KeepVideoConfirm_close_button_pressed")
	
	if OS.get_name() == "OSX":
		# Both borderless fullscreen and fullscreen don't work as intended on
		# OSX, so disable the button - the player can always maximize the
		# window, to get the same affect as making it fullscreen.
		_window_mode_button.disabled = true
	
	# To help keyboard-only users, manually adjust the focus neighbours of all
	# of the setting controls - Godot's default settings can sometimes send the
	# focus back to the main menu.
	for tab in _tab_container.get_children():
		if tab is OptionsTab:
			var grid = tab.get_node("GridContainer")
			if not grid:
				push_error("Options tab %s does not have a grid container child!" % tab.name)
				continue
			
			var old_child: Control = null
			
			for new_child in grid.get_children():
				if new_child is Control:
					if new_child.focus_mode == Control.FOCUS_ALL:
						if old_child != null:
							old_child.focus_neighbour_bottom = new_child.get_path()
							new_child.focus_neighbour_top = old_child.get_path()
						else:
							# Going up from the first control should take the
							# focus back to the tabs.
							new_child.focus_neighbour_top = _tab_container.get_path()
						
						old_child = new_child
			
			# Going down from the last element should take the focus to the
			# back button.
			if old_child != null:
				old_child.focus_neighbour_bottom = _back_button.get_path()

func _unhandled_input(event):
	if visible and not _binding_background.visible and event.is_action_pressed("ui_cancel"):
		visible = false
		get_tree().set_input_as_handled()

# Apply the changes made and save them in the options file.
func _apply_changes() -> void:
	var config = _create_config_from_current()
	_apply_config(config)
	
	# If the video settings have changed, then don't save them to the file just
	# yet - we'll wait and ask the player if they want to keep them after they
	# have been applied.
	var old_config = _create_config_from_current()
	_load_file(old_config)
	
	var video_settings_changed = false
	for key in config.get_section_keys("video"):
		var new_value = config.get_value("video", key)
		if old_config.has_section_key("video", key):
			var old_value = old_config.get_value("video", key)
			
			if new_value != old_value:
				# Save the old value to the file, in case we need to revert
				# back to it.
				config.set_value("video", key, old_value)
				video_settings_changed = true
	
	_save_file(config)
	
	if video_settings_changed:
		_keep_video_confirm.popup_centered()

# Apply the given options. Not all settings can be applied here, e.g. the
# controls settings will need to be applied by the camera controller.
# It can be assumed that the entire list of values are in the config.
# config: The options to apply.
func _apply_config(config: ConfigFile) -> void:
	emit_signal("applying_options", config)
	
	##########
	# LOCALE #
	##########
	
	# The majority of the work is done by the TranslationServer, but we need to
	# manually get the translations from the asset packs.
	if not AssetDB.is_importing():
		AssetDB.parse_translations(TranslationServer.get_locale())
	
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
	
	###############
	# MULTIPLAYER #
	###############
	
	Global.censoring_profanity = config.get_value("multiplayer", "censor_profanity")
	
	#########
	# VIDEO #
	#########
	
	# As stated above, just let the player maximize the window if they want the
	# game to be fullscreen on OSX.
	if OS.get_name() != "OSX":
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

# Save the override file, given a set of options. The override.cfg file takes
# effect when the engine starts.
# config: The options to save.
func _save_override_file(config: ConfigFile) -> void:
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
	return 8.656170245 * log(0.5 * volume)

func _on_rebinding_action(action: String) -> void:
	_action_to_bind = action
	_bind_ignore_next_enter = true
	_binding_background.visible = true
	
	_binding_background.grab_focus()

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
			var key_is_select = (event.scancode == KEY_ENTER or event.scancode == KEY_SPACE)
			if _bind_ignore_next_enter and key_is_select:
				_bind_ignore_next_enter = false
			else:
				valid = not event.is_pressed()
		elif event is InputEventMouseButton:
			valid = true
		
		if valid:
			get_tree().set_input_as_handled()
			
			for node in _key_bindings_parent.get_children():
				if node is BindButton:
					if node.action == _action_to_bind:
						node.input_event = event
						node.update_text()
						
						node.grab_focus()
			
			_action_to_bind = ""
			_bind_ignore_next_enter = false
			_binding_background.visible = false

func _on_CancelBindButton_pressed():
	_binding_background.visible = false

func _on_EffectsVolumeSlider_value_changed(_value: float):
	_apply_audio_config(_create_config_from_current())

func _on_KeepVideoConfirm_cancel_pressed():
	# Revert back to the original video settings.
	var config = _create_config_from_current()
	_load_file(config)
	_set_current_with_config(config)
	_apply_config(config)

func _on_KeepVideoConfirm_close_button_pressed():
	_on_KeepVideoConfirm_cancel_pressed()

func _on_KeepVideoConfirm_ok_pressed():
	# Save all settings, including video.
	var config = _create_config_from_current()
	_save_file(config)
	_save_override_file(config)

func _on_KeepVideoConfirm_visibility_changed():
	if _keep_video_confirm.visible:
		_keep_video_confirm.get_cancel().grab_focus()
	else:
		emit_signal("keep_video_dialog_hide")
		
		if visible:
			_tab_container.grab_focus()

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
	var asset_dir_paths = AssetDB.get_asset_paths()
	asset_dir_paths.invert() # From most convenient to access, to least.
	
	var dir = Directory.new()
	for dir_path in asset_dir_paths:
		if dir.dir_exists(dir_path):
			OS.shell_open("file://" + dir_path)
			return
	
	push_warning("Could not find a valid asset directory to open!")

func _on_OptionsMenu_visibility_changed():
	if visible:
		_tab_container.grab_focus()
		
		# Prevents focus from going back to the main menu.
		_back_button.focus_neighbour_left = NodePath(".")

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
	
	Global.start_importing_assets()

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
