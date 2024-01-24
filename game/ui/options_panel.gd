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

extends AttentionPanel

## The options menu, which interfaces with the GameConfig class.
##
## NOTE: If a control is named "opt_NAME", where NAME is the name of a property
## in GameConfig, then this script will automatically link the control with the
## corresponding property, removing the need to manually connect signals or to
## write functions for each individual control.


# A dictionary mapping controls to the name of the property that they represent
# in the GameConfig.
var _control_property_map := {}

# The property that is currently in focus, and for which a hint should be shown.
var _property_in_focus := ""


onready var _section_parent := $MainContainer/OptionContainer/ScrollContainer/SectionParent/
onready var _audio_container := $MainContainer/OptionContainer/ScrollContainer/SectionParent/AudioContainer
onready var _control_container := $MainContainer/OptionContainer/ScrollContainer/SectionParent/ControlContainer
onready var _general_container := $MainContainer/OptionContainer/ScrollContainer/SectionParent/GeneralContainer
onready var _player_container := $MainContainer/OptionContainer/ScrollContainer/SectionParent/PlayerContainer
onready var _video_container := $MainContainer/OptionContainer/ScrollContainer/SectionParent/VideoContainer
onready var _advanced_container := $MainContainer/OptionContainer/ScrollContainer/SectionParent/VideoContainer/GraphicsContainer/AdvancedContainer

onready var _language_button: OptionButton = $MainContainer/OptionContainer/ScrollContainer/SectionParent/GeneralContainer/LanguageContainer/OptionContainer/opt_general_language
onready var _autosave_interval_button: OptionButton = $MainContainer/OptionContainer/ScrollContainer/SectionParent/GeneralContainer/AutosaveContainer/opt_general_autosave_interval
onready var _chat_font_size_button: OptionButton = $MainContainer/OptionContainer/ScrollContainer/SectionParent/GeneralContainer/ChatContainer/opt_multiplayer_chat_font_size
onready var _window_mode_button: OptionButton = $MainContainer/OptionContainer/ScrollContainer/SectionParent/VideoContainer/WindowContainer/OptionContainer/opt_video_window_mode
onready var _quality_preset_button: OptionButton = $MainContainer/OptionContainer/ScrollContainer/SectionParent/VideoContainer/GraphicsContainer/PresetContainer/QualityPresetButton
onready var _shadow_detail_button: OptionButton = $MainContainer/OptionContainer/ScrollContainer/SectionParent/VideoContainer/GraphicsContainer/AdvancedContainer/MainContainer/opt_video_shadow_detail
onready var _aa_method_button: OptionButton = $MainContainer/OptionContainer/ScrollContainer/SectionParent/VideoContainer/GraphicsContainer/AdvancedContainer/MainContainer/opt_video_aa_method
onready var _msaa_samples_button: OptionButton = $MainContainer/OptionContainer/ScrollContainer/SectionParent/VideoContainer/GraphicsContainer/AdvancedContainer/MainContainer/opt_video_msaa_samples
onready var _ssao_button: OptionButton = $MainContainer/OptionContainer/ScrollContainer/SectionParent/VideoContainer/GraphicsContainer/AdvancedContainer/MainContainer/opt_video_ssao
onready var _skybox_radiance_button: OptionButton = $MainContainer/OptionContainer/ScrollContainer/SectionParent/VideoContainer/GraphicsContainer/AdvancedContainer/MainContainer/opt_video_skybox_radiance_detail
onready var _depth_of_field_button: OptionButton = $MainContainer/OptionContainer/ScrollContainer/SectionParent/VideoContainer/GraphicsContainer/AdvancedContainer/DOFContainer/opt_video_depth_of_field

# The video settings configuration for each of the graphics quality presets.
# For optimisation purposes, the keys for each preset are the option buttons
# themselves, not the name of the property they are linked to.
# TODO: Make array typed in 4.x
onready var _quality_preset_settings: Array = [
	{ # Low
		_shadow_detail_button: GameConfig.SHADOW_DETAIL_LOW,
		_aa_method_button: GameConfig.AA_OFF,
		_msaa_samples_button: GameConfig.MSAA_4X,
		_ssao_button: GameConfig.SSAO_NONE,
		_skybox_radiance_button: GameConfig.RADIANCE_LOW
	},
	{ # Medium
		_shadow_detail_button: GameConfig.SHADOW_DETAIL_MEDIUM,
		_aa_method_button: GameConfig.AA_FXAA,
		_msaa_samples_button: GameConfig.MSAA_4X,
		_ssao_button: GameConfig.SSAO_NONE,
		_skybox_radiance_button: GameConfig.RADIANCE_LOW
	},
	{ # High
		_shadow_detail_button: GameConfig.SHADOW_DETAIL_HIGH,
		_aa_method_button: GameConfig.AA_MSAA,
		_msaa_samples_button: GameConfig.MSAA_4X,
		_ssao_button: GameConfig.SSAO_LOW,
		_skybox_radiance_button: GameConfig.RADIANCE_MEDIUM
	},
	{ # Very High
		_shadow_detail_button: GameConfig.SHADOW_DETAIL_VERY_HIGH,
		_aa_method_button: GameConfig.AA_MSAA,
		_msaa_samples_button: GameConfig.MSAA_8X,
		_ssao_button: GameConfig.SSAO_MEDIUM,
		_skybox_radiance_button: GameConfig.RADIANCE_HIGH
	},
	{ # Ultra
		_shadow_detail_button: GameConfig.SHADOW_DETAIL_VERY_HIGH,
		_aa_method_button: GameConfig.AA_MSAA,
		_msaa_samples_button: GameConfig.MSAA_16X,
		_ssao_button: GameConfig.SSAO_HIGH,
		_skybox_radiance_button: GameConfig.RADIANCE_HIGH
	}
]

onready var _player_name_edit: LineEdit = $MainContainer/OptionContainer/ScrollContainer/SectionParent/PlayerContainer/MainContainer/DetailContainer/opt_multiplayer_name
onready var _player_name_warning_label := $MainContainer/OptionContainer/ScrollContainer/SectionParent/PlayerContainer/MainContainer/DetailContainer/NameWarningLabel
onready var _player_button := $MainContainer/OptionContainer/ScrollContainer/SectionParent/PlayerContainer/MainContainer/PreviewContainer/PlayerButton

onready var _section_button_container := $MainContainer/SectionContainer
onready var _scroll_container := $MainContainer/OptionContainer/ScrollContainer
onready var _language_warning_label := $MainContainer/OptionContainer/ScrollContainer/SectionParent/GeneralContainer/LanguageContainer/LanguageWarningLabel
onready var _msaa_samples_label := $MainContainer/OptionContainer/ScrollContainer/SectionParent/VideoContainer/GraphicsContainer/AdvancedContainer/MainContainer/SamplesLabel
onready var _hint_label := $MainContainer/HintLabel
onready var _apply_button := $MainContainer/ButtonContainer/ApplyButton

onready var _discard_dialog := $DiscardDialog


func _ready():
	# Before we do anything, we need to populate the control property map so
	# that we can start displaying and modifying the GameConfig properties.
	var node_stack: Array = [_section_parent]
	while not node_stack.empty():
		var current_node: Node = node_stack.pop_front()
		if current_node is Control and current_node.name.begins_with("opt_"):
			var property_name := current_node.name.substr(4)
			
			if GameConfig.get(property_name) != null:
				_control_property_map[current_node] = property_name
				
				# If the control is updated, we want to know so we can allow the
				# user to press the apply button.
				if current_node is LabeledSlider:
					current_node.connect("value_changed", self,
							"_on_any_value_changed")
				elif current_node is IntegerSpinBox:
					current_node.connect("value_changed", self,
							"_on_any_value_changed")
				elif current_node is ColorSlider:
					current_node.connect("color_changed", self,
							"_on_any_value_changed")
				elif current_node is CheckBox:
					current_node.connect("toggled", self,
							"_on_any_value_changed")
				elif current_node is LineEdit:
					current_node.connect("text_changed", self,
							"_on_any_value_changed")
				elif current_node is OptionButton:
					current_node.connect("item_selected", self,
							"_on_any_value_changed")
				
				# We also want to know if the mouse starts hovering over the
				# control, or if it grabs focus, so that we can start showing a
				# hint to the user about what the property does.
				current_node.connect("focus_entered", self,
						"_on_option_focus_entered", [property_name])
				current_node.connect("focus_exited", self,
						"_on_option_focus_exited", [property_name])
				current_node.connect("mouse_entered", self,
						"_on_option_focus_entered", [property_name])
				current_node.connect("mouse_exited", self,
						"_on_option_focus_exited", [property_name])
			else:
				push_error("Property '%s' does not exist in the GameConfig (from: '%s')" % [
						property_name, current_node.name])
		
		node_stack.append_array(current_node.get_children())
	
	# For the graphics settings, we need to connect them separately so that we
	# can update the quality preset button if needed.
	var low_quality_settings: Dictionary = _quality_preset_settings[0]
	for key in low_quality_settings:
		var control: Control = key
		if control is OptionButton:
			control.connect("item_selected", self, "_on_graphics_setting_changed")
	
	# We can't set the item label fonts in option buttons directly from the
	# editor, so we need to do it in code.
	for element in [ _language_button, _autosave_interval_button,
			_chat_font_size_button, _window_mode_button, _quality_preset_button,
			_shadow_detail_button, _aa_method_button, _msaa_samples_button,
			_ssao_button, _skybox_radiance_button, _depth_of_field_button]:
		
		var button: OptionButton = element
		var popup: Popup = button.get_popup()
		popup.add_font_override("font", button.get_font("font"))
		
		# We want to catch when a popup is about to be shown so that we can stop
		# the scroll container from moving to adjust for it's height.
		popup.connect("about_to_show", self,
				"_on_option_button_popup_about_to_show")
	
	# There is a chance that the names of languages (in their own language)
	# appear elsewhere in the game (most likely in the credits if the English
	# name of the languge is the same), which will cause the option button to
	# translate them automatically, which we don't want in this specific case.
	_language_button.get_popup().set_message_translation(false)
	
	# Godot stores both the bbcode_text and the regular text of rich text labels
	# in the *.tscn file, and I can't be bothered to configure the translation
	# template extractor to filter out the regular text, so the BBCode is here.
	_language_warning_label.bbcode_text = tr("NOTE: Translations are graciously provided by the community, however, this may mean that translations for your language are either incomplete or missing.") \
			+ "\n" + tr("If you wish to help make the game accessible to a wider audience of players, please visit our [url]Weblate[/url] page to contribute translations for your language.")
	
	# Set the items for all of the OptionButton controls in the scene, with the
	# labels of the items translated to the current locale.
	set_option_button_items()
	
	# We don't necessarily want to close the panel straight away if the user
	# presses the back button, we may want to show a confirm dialog.
	close_on_cancel = false


func _unhandled_input(event: InputEvent):
	if visible and event.is_action_pressed("ui_cancel"):
		# This will either close the window, or show a confirm dialog depending
		# on if there are changes that have not been applied yet.
		_on_BackButton_pressed()
		
		get_tree().set_input_as_handled()


## Have the controls show the current values from the GameConfig.
func read_config() -> void:
	for key in _control_property_map:
		var control: Control = key
		var property_name: String = _control_property_map[key]
		var property_value = GameConfig.get(property_name)
		
		if control is LabeledSlider:
			control.value = property_value
		elif control is IntegerSpinBox:
			control.value = property_value
		elif control is ColorSlider:
			control.color = property_value
		elif control is CheckBox:
			control.pressed = property_value
		elif control is LineEdit:
			control.text = property_value
		elif control is OptionButton:
			var item_found := false
			for index in range(control.get_item_count()):
				var metadata = control.get_item_metadata(index)
				if metadata == property_value:
					control.select(index)
					item_found = true
					break
			
			if not item_found:
				push_error("Cannot show value of '%s' with option button '%s', item with value '%s' not found" % [
						property_name, control.name, str(property_value)])
		else:
			push_error("Cannot show value of '%s' with control '%s', unimplemented type" % [
					property_name, control.name])


## Use the controls to set the values of the properties in GameConfig.
func write_config() -> void:
	for key in _control_property_map:
		var control: Control = key
		var property_name: String = _control_property_map[key]
		
		if control is LabeledSlider:
			GameConfig.set(property_name, control.value)
		elif control is IntegerSpinBox:
			GameConfig.set(property_name, control.value)
		elif control is ColorSlider:
			GameConfig.set(property_name, control.color)
		elif control is CheckBox:
			GameConfig.set(property_name, control.pressed)
		elif control is LineEdit:
			GameConfig.set(property_name, control.text)
		elif control is OptionButton:
			var metadata = control.get_selected_metadata()
			if metadata == null:
				push_error("Cannot set value of '%s' with option button '%s', no item selected" % [
						property_name, control.name])
				continue
			
			GameConfig.set(property_name, metadata)
		else:
			push_error("Cannot set value of '%s' with control '%s', unimplemented type" % [
					property_name, control.name])


## For each of the [OptionButton] controls in the options menu, set the required
## items with the correct metadata for each item. The text for each item is also
## localised, so if the locale of the project changes, this function needs to be
## called again.
func set_option_button_items() -> void:
	var prev_selected := _language_button.selected
	_language_button.clear()
	
	_add_option_button_item(_language_button, tr("System Default"), "")
	_add_option_button_item(_language_button, "Deutsch", "de")
	_add_option_button_item(_language_button, "English", "en")
	_add_option_button_item(_language_button, "Esperanto", "eo")
	_add_option_button_item(_language_button, "Español", "es")
	_add_option_button_item(_language_button, "Français", "fr")
	_add_option_button_item(_language_button, "Italiano", "it")
	_add_option_button_item(_language_button, "Nederlands", "nl")
	_add_option_button_item(_language_button, "Português", "pt")
	_add_option_button_item(_language_button, "Русский", "ru")
	
	if prev_selected >= 0:
		_language_button.select(prev_selected)
	
	prev_selected = _autosave_interval_button.selected
	_autosave_interval_button.clear()
	
	_add_option_button_item(_autosave_interval_button, tr("Never"),
			GameConfig.AUTOSAVE_NEVER)
	_add_option_button_item(_autosave_interval_button, tr("30 seconds"),
			GameConfig.AUTOSAVE_30_SEC)
	_add_option_button_item(_autosave_interval_button, tr("1 minute"),
			GameConfig.AUTOSAVE_1_MIN)
	_add_option_button_item(_autosave_interval_button, tr("5 minutes"),
			GameConfig.AUTOSAVE_5_MIN)
	_add_option_button_item(_autosave_interval_button, tr("10 minutes"),
			GameConfig.AUTOSAVE_10_MIN)
	_add_option_button_item(_autosave_interval_button, tr("30 minutes"),
			GameConfig.AUTOSAVE_30_MIN)
	
	if prev_selected >= 0:
		_autosave_interval_button.select(prev_selected)
	
	prev_selected = _chat_font_size_button.selected
	_chat_font_size_button.clear()
	
	_add_option_button_item(_chat_font_size_button, tr("Small"),
			GameConfig.FONT_SIZE_SMALL)
	_add_option_button_item(_chat_font_size_button, tr("Medium"),
			GameConfig.FONT_SIZE_MEDIUM)
	_add_option_button_item(_chat_font_size_button, tr("Large"),
			GameConfig.FONT_SIZE_LARGE)
	
	if prev_selected >= 0:
		_chat_font_size_button.select(prev_selected)
	
	prev_selected = _window_mode_button.selected
	_window_mode_button.clear()
	
	_add_option_button_item(_window_mode_button, tr("Windowed"),
			GameConfig.MODE_WINDOWED)
	_add_option_button_item(_window_mode_button, tr("Borderless Fullscreen"),
			GameConfig.MODE_BORDERLESS_FULLSCREEN)
	_add_option_button_item(_window_mode_button, tr("Fullscreen"),
			GameConfig.MODE_FULLSCREEN)
	
	if prev_selected >= 0:
		_window_mode_button.select(prev_selected)
	
	prev_selected = _quality_preset_button.selected
	_quality_preset_button.clear()
	
	# The graphics preset button uses the index instead of the metadata.
	_add_option_button_item(_quality_preset_button, tr("Low"), null)
	_add_option_button_item(_quality_preset_button, tr("Medium"), null)
	_add_option_button_item(_quality_preset_button, tr("High"), null)
	_add_option_button_item(_quality_preset_button, tr("Very High"), null)
	_add_option_button_item(_quality_preset_button, tr("Ultra"), null)
	_add_option_button_item(_quality_preset_button, tr("Custom"), null)
	
	if prev_selected >= 0:
		_quality_preset_button.select(prev_selected)
	
	prev_selected = _shadow_detail_button.selected
	_shadow_detail_button.clear()
	
	_add_option_button_item(_shadow_detail_button, tr("Low"),
			GameConfig.SHADOW_DETAIL_LOW)
	_add_option_button_item(_shadow_detail_button, tr("Medium"),
			GameConfig.SHADOW_DETAIL_MEDIUM)
	_add_option_button_item(_shadow_detail_button, tr("High"),
			GameConfig.SHADOW_DETAIL_HIGH)
	_add_option_button_item(_shadow_detail_button, tr("Very High"),
			GameConfig.SHADOW_DETAIL_VERY_HIGH)
	
	if prev_selected >= 0:
		_shadow_detail_button.select(prev_selected)
	
	prev_selected = _aa_method_button.selected
	_aa_method_button.clear()
	
	_add_option_button_item(_aa_method_button, tr("Off"), GameConfig.AA_OFF)
	_add_option_button_item(_aa_method_button, tr("FXAA"), GameConfig.AA_FXAA)
	_add_option_button_item(_aa_method_button, tr("MSAA"), GameConfig.AA_MSAA)
	
	if prev_selected >= 0:
		_aa_method_button.select(prev_selected)
	
	prev_selected = _msaa_samples_button.selected
	_msaa_samples_button.clear()
	
	_add_option_button_item(_msaa_samples_button, "2X", GameConfig.MSAA_2X)
	_add_option_button_item(_msaa_samples_button, "4X", GameConfig.MSAA_4X)
	_add_option_button_item(_msaa_samples_button, "8X", GameConfig.MSAA_8X)
	_add_option_button_item(_msaa_samples_button, "16X", GameConfig.MSAA_16X)
	
	if prev_selected >= 0:
		_msaa_samples_button.select(prev_selected)
	
	prev_selected = _ssao_button.selected
	_ssao_button.clear()
	
	_add_option_button_item(_ssao_button, tr("None"), GameConfig.SSAO_NONE)
	_add_option_button_item(_ssao_button, tr("Low"), GameConfig.SSAO_LOW)
	_add_option_button_item(_ssao_button, tr("Medium"), GameConfig.SSAO_MEDIUM)
	_add_option_button_item(_ssao_button, tr("High"), GameConfig.SSAO_HIGH)
	
	if prev_selected >= 0:
		_ssao_button.select(prev_selected)
	
	prev_selected = _skybox_radiance_button.selected
	_skybox_radiance_button.clear()
	
	_add_option_button_item(_skybox_radiance_button, tr("Low"),
			GameConfig.RADIANCE_LOW)
	_add_option_button_item(_skybox_radiance_button, tr("Medium"),
			GameConfig.RADIANCE_MEDIUM)
	_add_option_button_item(_skybox_radiance_button, tr("High"),
			GameConfig.RADIANCE_HIGH)
	_add_option_button_item(_skybox_radiance_button, tr("Very High"),
			GameConfig.RADIANCE_VERY_HIGH)
	_add_option_button_item(_skybox_radiance_button, tr("Ultra"),
			GameConfig.RADIANCE_ULTRA)
	
	if prev_selected >= 0:
		_skybox_radiance_button.select(prev_selected)
	
	prev_selected = _depth_of_field_button.selected
	_depth_of_field_button.clear()
	
	_add_option_button_item(_depth_of_field_button, tr("None"),
			GameConfig.DOF_NONE)
	_add_option_button_item(_depth_of_field_button, tr("Low"),
			GameConfig.DOF_LOW)
	_add_option_button_item(_depth_of_field_button, tr("Medium"),
			GameConfig.DOF_MEDIUM)
	_add_option_button_item(_depth_of_field_button, tr("High"),
			GameConfig.DOF_HIGH)
	
	if prev_selected >= 0:
		_depth_of_field_button.select(prev_selected)


# Add an item to the given option button along with some metadata.
func _add_option_button_item(option_button: OptionButton, label: String, metadata) -> void:
	option_button.add_item(label)
	var item_index := option_button.get_item_count() - 1
	option_button.set_item_metadata(item_index, metadata)


# Check whether the current graphics settings correspond to one of the presets.
# If not, then "Custom" is automatically selected.
func _check_quality_preset() -> void:
	for index in range(_quality_preset_settings.size()):
		var preset_settings: Dictionary = _quality_preset_settings[index]
		var values_match_preset := true
		
		for key in preset_settings:
			var property_control: Control = key
			var expected_value = preset_settings[key]
			var expected_type := typeof(expected_value)
			
			if property_control is OptionButton:
				var actual_value = property_control.get_selected_metadata()
				var actual_type := typeof(actual_value)
				
				if actual_type != expected_type:
					push_error("%s: Data type of metadata '%s' (%s) does not match type of check value '%s' (%s)" %
							[property_control.name, str(actual_value),
							SanityCheck.get_type_name(actual_type),
							str(expected_value),
							SanityCheck.get_type_name(expected_type)])
					return
				
				if actual_value != expected_value:
					values_match_preset = false
					break
			else:
				push_error("Cannot check value of control '%s', unimplemented type" %
						property_control.name)
				return
		
		if values_match_preset:
			_quality_preset_button.select(index)
			return
	
	# None of the presets match the current values, so display "Custom".
	_quality_preset_button.select(_quality_preset_button.get_item_count() - 1)


# If there are any invalid properties, set their values such that they are valid
# again. This should be used before any changes are applied.
func _fix_invalid_properties() -> void:
	var player_name := _player_name_edit.text
	player_name = player_name.strip_edges().strip_escapes()
	
	if player_name.empty():
		# Guaranteed to be valid at all times.
		player_name = GameConfig.multiplayer_name
	
	_player_name_edit.text = player_name
	_player_button.text = player_name
	_player_name_warning_label.visible = false


# Show the given section, and hide the others.
func _show_section(section_root: Control) -> void:
	for child in _section_parent.get_children():
		if child is Control:
			child.visible = (child == section_root)
	
	# Reset the vertical scroll to the top of the section.
	_scroll_container.scroll_vertical = 0.0


func _on_OptionsPanel_about_to_show():
	# Update the controls to match the current values of GameConfig properties.
	read_config()
	
	# Now that they match, we can update the PlayerButton preview.
	_player_button.text = GameConfig.multiplayer_name
	_player_button.bg_color = GameConfig.multiplayer_color
	
	# The player name is guaranteed to be valid now.
	_player_name_warning_label.visible = false
	
	# We want to update the quality preset button to reflect the new graphics
	# settings.
	_check_quality_preset()
	
	# We may or may not want to show the MSAA Quality setting depending on if
	# the currently selected AA Method is MSAA.
	_on_opt_video_aa_method_item_selected(_aa_method_button.selected)
	
	# Since the controls have just been updated, no changes can be applied yet.
	_apply_button.disabled = true
	
	# If the mouse was hovering over a property when the option menu was
	# hidden, then the hint for that property will still be there.
	_property_in_focus = ""
	_hint_label.text = ""
	
	# By default, the first control node to take focus will be the audio section
	# button. But it's not guaranteed that when we show the options menu, that
	# the audio section will be visible (since the user could have left the
	# options menu while another section was shown) - so have the button of the
	# section currently being shown grab focus at the start.
	for section_button in _section_button_container.get_children():
		if section_button is Button:
			if section_button.pressed:
				# The options menu is about to be shown, but it is not visible
				# quite yet, so wait until the end of the frame to grab focus.
				section_button.call_deferred("grab_focus")
				break


func _on_OptionsPanel_popup_hide():
	# Some options can be adjusted before the user presses the apply button,
	# like the language for example. However, if the user exits the options menu
	# while these "live" changes have been made, we want to revert those changes
	# back to what the GameConfig says.
	if _apply_button.disabled:
		return
	
	GameConfig.apply_audio()
	GameConfig.set_locale(GameConfig.general_language)
	
	# The locale has potentially changed again, so we need to update the option
	# button labels for the new locale.
	set_option_button_items()


func _on_AudioSectionButton_pressed():
	_show_section(_audio_container)


func _on_ControlSectionButton_pressed():
	_show_section(_control_container)


func _on_GeneralSectionButton_pressed():
	_show_section(_general_container)


func _on_MultiplayerSectionButton_pressed():
	_show_section(_player_container)


func _on_VideoSectionButton_pressed():
	_show_section(_video_container)


func _on_KeyBindingsButton_pressed():
	pass # Replace with function body.


func _on_ControllerBindingsButton_pressed():
	pass # Replace with function body.


func _on_KeyBindingsButton_focus_entered():
	_on_option_focus_entered("%KEY_BINDINGS%")


func _on_KeyBindingsButton_focus_exited():
	_on_option_focus_exited("%KEY_BINDINGS%")


func _on_KeyBindingsButton_mouse_entered():
	_on_option_focus_entered("%KEY_BINDINGS%")


func _on_KeyBindingsButton_mouse_exited():
	_on_option_focus_exited("%KEY_BINDINGS%")


func _on_ControllerBindingsButton_focus_entered():
	_on_option_focus_entered("%CONTROLLER_BINDINGS%")


func _on_ControllerBindingsButton_focus_exited():
	_on_option_focus_exited("%CONTROLLER_BINDINGS%")


func _on_ControllerBindingsButton_mouse_entered():
	_on_option_focus_entered("%CONTROLLER_BINDINGS%")


func _on_ControllerBindingsButton_mouse_exited():
	_on_option_focus_exited("%CONTROLLER_BINDINGS%")


func _on_QualityPresetButton_focus_entered():
	_on_option_focus_entered("%QUALITY_PRESET%")


func _on_QualityPresetButton_focus_exited():
	_on_option_focus_exited("%QUALITY_PRESET%")


func _on_QualityPresetButton_mouse_entered():
	_on_option_focus_entered("%QUALITY_PRESET%")


func _on_QualityPresetButton_mouse_exited():
	_on_option_focus_exited("%QUALITY_PRESET%")


func _on_AdvancedGraphicsButton_focus_entered():
	_on_option_focus_entered("%ADVANCED_GRAPHICS%")


func _on_AdvancedGraphicsButton_focus_exited():
	_on_option_focus_exited("%ADVANCED_GRAPHICS%")


func _on_AdvancedGraphicsButton_mouse_entered():
	_on_option_focus_entered("%ADVANCED_GRAPHICS%")


func _on_AdvancedGraphicsButton_mouse_exited():
	_on_option_focus_exited("%ADVANCED_GRAPHICS%")


func _on_any_value_changed(_new_value):
	_apply_button.disabled = false


func _on_graphics_setting_changed(_new_value):
	# Check if changing the graphics setting moves us out of a quality preset
	# into "Custom", or if it moves us into one.
	_check_quality_preset()


func _on_option_focus_entered(property_name: String):
	_property_in_focus = property_name
	
	var hint_text := ""
	if property_name.begins_with("%"):
		match property_name:
			"%KEY_BINDINGS%":
				hint_text = tr("Edit which keyboard or mouse buttons are assigned to each action.")
			"%CONTROLLER_BINDINGS%":
				hint_text = tr("Edit which controller buttons are assigned to each action.")
			"%QUALITY_PRESET%":
				hint_text = tr("Sets the overall visual quality of the game. The higher the quality, the better the game will look, at the cost of performance.")
			"%ADVANCED_GRAPHICS%":
				hint_text = tr("If enabled, more specific graphics settings will be shown. For most players, it is advised to use the Graphics Quality setting instead, as it will automatically adjust these settings for you.")
	else:
		hint_text = GameConfig.get_description(property_name)
	
	_hint_label.text = hint_text


func _on_option_focus_exited(property_name: String):
	if property_name == _property_in_focus:
		_property_in_focus = ""
		_hint_label.text = ""


func _on_option_button_popup_about_to_show():
	# If a popup is about to be shown, then by default the scroll container will
	# scroll down to fit all of the contents of the popup in, which to be honest
	# looks jarring when it happens - so just after it does so, set the scroll
	# back to what it just was, so the user doesn't see any scrolling.
	_scroll_container.call_deferred("set_v_scroll",
			_scroll_container.scroll_vertical)


func _on_opt_audio_master_volume_value_changed(new_value: float):
	GameConfig.set_audio_bus_volume("Master", new_value)


func _on_opt_audio_music_volume_value_changed(new_value: float):
	GameConfig.set_audio_bus_volume("Music", new_value)


func _on_opt_audio_sounds_volume_value_changed(new_value: float):
	GameConfig.set_audio_bus_volume("Sounds", new_value)


func _on_opt_audio_effects_volume_value_changed(new_value: float):
	GameConfig.set_audio_bus_volume("Effects", new_value)


func _on_opt_general_language_item_selected(index: int):
	var selected_locale: String = _language_button.get_item_metadata(index)
	GameConfig.set_locale(selected_locale)
	
	# With the new locale having being set across the game, we need to update
	# the option button items throughout the options menu so that their labels
	# are from the new locale.
	set_option_button_items()


func _on_opt_multiplayer_name_text_changed(new_text: String):
	_player_button.text = new_text
	
	var stripped_name := new_text.strip_edges().strip_escapes()
	_player_name_warning_label.visible = stripped_name.empty()


func _on_opt_multiplayer_color_color_changed(new_color: Color):
	_player_button.bg_color = new_color


func _on_opt_video_aa_method_item_selected(index: int):
	var selected_method: int = _aa_method_button.get_item_metadata(index)
	var method_is_msaa := (selected_method == GameConfig.AA_MSAA)
	_msaa_samples_label.visible = method_is_msaa
	_msaa_samples_button.visible = method_is_msaa


func _on_QualityPresetButton_item_selected(index: int):
	# If "Custom" was selected, do not do anything.
	if index >= _quality_preset_settings.size():
		return
	
	# This signal won't fire when the same item is selected again by the user.
	_apply_button.disabled = false
	
	var video_settings: Dictionary = _quality_preset_settings[index]
	for key in video_settings:
		var property_control: Control = key
		var target_value = video_settings[key]
		
		if property_control is OptionButton:
			var metadata_found := false
			
			for index in range(property_control.get_item_count()):
				var metadata_at_index = property_control.get_item_metadata(index)
				
				if typeof(metadata_at_index) != typeof(target_value):
					continue
				
				if metadata_at_index == target_value:
					property_control.select(index)
					metadata_found = true
					break
			
			if not metadata_found:
				push_error("Unable to find metadata value '%s' in control '%s'" %
						[str(target_value), property_control.name])
		else:
			push_error("Cannot set value of control '%s', unimplemented type" %
					property_control.name)
	
	# Changing the preset can change which anti-aliasing method is used. If the
	# new method is MSAA, we need to show the MSAA Samples setting.
	_on_opt_video_aa_method_item_selected(_aa_method_button.selected)


func _on_AdvancedGraphicsButton_toggled(button_pressed: bool):
	_advanced_container.visible = button_pressed


func _on_LanguageWarningLabel_meta_clicked(_meta):
	OS.shell_open("https://hosted.weblate.org/engage/tabletop-club/")


func _on_BackButton_pressed():
	if _apply_button.disabled:
		visible = false
	else:
		_discard_dialog.popup_centered()


func _on_ApplyButton_pressed():
	_fix_invalid_properties()
	
	write_config()
	GameConfig.apply_all()
	GameConfig.save_to_file()
	
	_apply_button.disabled = true


func _on_DiscardDialog_discarding_changes():
	visible = false
