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

onready var _language_button: OptionButton = $MainContainer/OptionContainer/ScrollContainer/SectionParent/GeneralContainer/LanguageContainer/OptionContainer/opt_general_language
onready var _autosave_interval_button: OptionButton = $MainContainer/OptionContainer/ScrollContainer/SectionParent/GeneralContainer/AutosaveContainer/opt_general_autosave_interval
onready var _chat_font_size_button: OptionButton = $MainContainer/OptionContainer/ScrollContainer/SectionParent/GeneralContainer/ChatContainer/opt_multiplayer_chat_font_size

onready var _player_name_edit: LineEdit = $MainContainer/OptionContainer/ScrollContainer/SectionParent/PlayerContainer/MainContainer/DetailContainer/opt_multiplayer_name
onready var _player_name_warning_label := $MainContainer/OptionContainer/ScrollContainer/SectionParent/PlayerContainer/MainContainer/DetailContainer/NameWarningLabel
onready var _player_button := $MainContainer/OptionContainer/ScrollContainer/SectionParent/PlayerContainer/MainContainer/PreviewContainer/PlayerButton

onready var _section_button_container := $MainContainer/SectionContainer
onready var _language_warning_label := $MainContainer/OptionContainer/ScrollContainer/SectionParent/GeneralContainer/LanguageContainer/LanguageWarningLabel
onready var _hint_label := $MainContainer/HintLabel
onready var _apply_button := $MainContainer/ButtonContainer/ApplyButton


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
	
	# We can't set the item label fonts in option buttons directly from the
	# editor, so we need to do it in code.
	_language_button.get_popup().add_font_override("font",
			_language_button.get_font("font"))
	_autosave_interval_button.get_popup().add_font_override("font",
			_autosave_interval_button.get_font("font"))
	_chat_font_size_button.get_popup().add_font_override("font",
			_chat_font_size_button.get_font("font"))
	
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


# Add an item to the given option button along with some metadata.
func _add_option_button_item(option_button: OptionButton, label: String, metadata) -> void:
	option_button.add_item(label)
	var item_index := option_button.get_item_count() - 1
	option_button.set_item_metadata(item_index, metadata)


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


func _on_OptionsPanel_about_to_show():
	# Update the controls to match the current values of GameConfig properties.
	read_config()
	
	# Now that they match, we can update the PlayerButton preview.
	_player_button.text = GameConfig.multiplayer_name
	_player_button.bg_color = GameConfig.multiplayer_color
	
	# The player name is guaranteed to be valid now.
	_player_name_warning_label.visible = false
	
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
	pass # Replace with function body.


func _on_KeyBindingsButton_pressed():
	pass # Replace with function body.


func _on_ControllerBindingsButton_pressed():
	pass # Replace with function body.


func _on_any_value_changed(_new_value):
	_apply_button.disabled = false


func _on_option_focus_entered(property_name: String):
	_property_in_focus = property_name
	_hint_label.text = GameConfig.get_description(property_name)


func _on_option_focus_exited(property_name: String):
	if property_name == _property_in_focus:
		_property_in_focus = ""
		_hint_label.text = ""


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


func _on_LanguageWarningLabel_meta_clicked(_meta):
	OS.shell_open("https://hosted.weblate.org/engage/tabletop-club/")


func _on_BackButton_pressed():
	visible = false


func _on_ApplyButton_pressed():
	_fix_invalid_properties()
	
	write_config()
	GameConfig.apply_all()
	GameConfig.save_to_file()
	
	_apply_button.disabled = true
