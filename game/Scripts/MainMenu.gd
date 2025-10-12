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

extends Control

onready var _credits_dialog = $CreditsDialog
onready var _credits_label = $CreditsDialog/CreditsLabel
onready var _enter_code_dialog = $EnterCodeDialog
onready var _error_dialog = $ErrorDialog
onready var _import_error_button = $MainView/MainList/HBoxContainer/ImportErrorButton
onready var _import_error_dialog = $ImportErrorDialog
onready var _import_error_tree = $ImportErrorDialog/ErrorTree
onready var _info_dialog = $InfoDialog
onready var _license_label = $InfoDialog/ScrollContainer/VBoxContainer/LicenseLabel
onready var _multiplayer_dialog = $MultiplayerDialog
onready var _options_button = $MainView/MainList/OptionsButton
onready var _options_menu = $OptionsMenu
onready var _random_music_player = $RandomMusicPlayer
onready var _room_code_edit = $EnterCodeDialog/VBoxContainer/RoomCodeContainer/RoomCodeEdit
onready var _singleplayer_button = $MainView/MainList/SingleplayerButton
onready var _version_label = $InfoDialog/ScrollContainer/VBoxContainer/VersionLabel

const ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

# Display an error.
# error: The error to display.
func display_error(error: String) -> void:
	_error_dialog.dialog_text = error
	_error_dialog.popup_centered()

func _ready():
	_update_credits_text()
	_update_license_text()
	
	_version_label.text = ProjectSettings.get_setting("application/config/name")
	if ProjectSettings.has_setting("application/config/version"):
		_version_label.text += " " + ProjectSettings.get_setting("application/config/version")
	
	# Start playing the music once every child node is ready.
	_random_music_player.next_track()
	
	# Focus on the singleplayer button so users can navigate the main menu with
	# just the keyboard.
	_singleplayer_button.grab_focus()
	
	# Show any errors and warnings that occured when importing.
	var error_dict = AssetDB.get_error_dict()
	var error_count = 0
	
	var tree_root = _import_error_tree.create_item()
	
	for source in error_dict:
		var err_source: Array = error_dict[source]
		error_count += err_source.size()
		
		var source_node = _import_error_tree.create_item(tree_root)
		source_node.set_text(0, source)
		
		for err in err_source:
			var err_node = _import_error_tree.create_item(source_node)
			err_node.set_text(0, err)
			
			if err.begins_with("E"):
				err_node.set_custom_color(0, Color.red)
			elif err.begins_with("W"):
				err_node.set_custom_color(0, Color.yellow)
	
	_import_error_button.text = str(error_count)
	_import_error_button.visible = (error_count > 0)

# Update the credits dialog text.
func _update_credits_text() -> void:
	var credits_file = preload("res://CREDITS.tres")
	
	var credits_text = credits_file.text
	credits_text = credits_text.replace("ALPHA TESTERS", tr("Alpha Testers"))
	credits_text = credits_text.replace("CONTRIBUTORS", tr("Contributors"))
	credits_text = credits_text.replace("CURSORS", tr("Cursors"))
	credits_text = credits_text.replace("DEVELOPERS", tr("Developers"))
	credits_text = credits_text.replace("FONTS", tr("Fonts"))
	credits_text = credits_text.replace("IMAGES", tr("Images"))
	credits_text = credits_text.replace("LOGO AND ICON", tr("Logo and Icon"))
	credits_text = credits_text.replace("SOUND EFFECTS", tr("Sound Effects"))
	credits_text = credits_text.replace("TOOL ICONS", tr("Tool Icons"))
	credits_text = credits_text.replace("TRANSLATORS", tr("Translators"))
	
	credits_text = credits_text.replace("BULGARIAN", tr("Bulgarian"))
	credits_text = credits_text.replace("CHINESE", tr("Chinese"))
	credits_text = credits_text.replace("DUTCH", tr("Dutch"))
	credits_text = credits_text.replace("ESPERANTO", tr("Esperanto"))
	credits_text = credits_text.replace("FRENCH", tr("French"))
	credits_text = credits_text.replace("GERMAN", tr("German"))
	credits_text = credits_text.replace("HUNGARIAN", tr("Hungarian"))
	credits_text = credits_text.replace("INDONESIAN", tr("Indonesian"))
	credits_text = credits_text.replace("ITALIAN", tr("Italian"))
	credits_text = credits_text.replace("KOREAN", tr("Korean"))
	credits_text = credits_text.replace("NORWEGIAN", tr("Norwegian"))
	credits_text = credits_text.replace("POLISH", tr("Polish"))
	credits_text = credits_text.replace("PORTUGUESE", tr("Portuguese"))
	credits_text = credits_text.replace("RUSSIAN", tr("Russian"))
	credits_text = credits_text.replace("SPANISH", tr("Spanish"))
	credits_text = credits_text.replace("TAMIL", tr("Tamil"))
	
	var credits_lines = credits_text.split("\n")
	
	for i in range(credits_lines.size() - 1, -1, -1):
		var line = credits_lines[i]
		if line.begins_with("-"):
			credits_lines[i - 1] = "[i]" + credits_lines[i - 1] + "[/i]"
			credits_lines.remove(i)
		elif line.begins_with("="):
			credits_lines[i - 1] = "[u]" + credits_lines[i - 1] + "[/u]"
			credits_lines.remove(i)
	
	_credits_label.bbcode_text = "[center]"
	for line in credits_lines:
		_credits_label.bbcode_text += line + "\n"
	_credits_label.bbcode_text += "[/center]"

# Update the license dialog text.
func _update_license_text() -> void:
	# The label will already contain the copyright and license for the project
	# itself.
	_license_label.bbcode_text = _license_label.text
	_license_label.bbcode_enabled = true
	if not _license_label.bbcode_text.ends_with("\n"):
		_license_label.bbcode_text += "\n"
	
	# Include copyright and license information about the resources that this
	# project uses.
	_license_label.bbcode_text += "\n[center][u]Resources[/u][/center]\n\n\n"
	_license_label.bbcode_text += preload("res://LICENSES.tres").text
	if not _license_label.bbcode_text.ends_with("\n"):
		_license_label.bbcode_text += "\n"
	
	# Include copyright and license information about Godot, and the third-party
	# libraries it uses.
	_license_label.bbcode_text += "\n[center][u]Godot Engine & Libraries[/u][/center]"
	var copyright_info = Engine.get_copyright_info()
	
	for component in copyright_info:
		var component_name: String = component["name"]
		_license_label.bbcode_text += "\n\n\n- %s" % component_name
		
		for subcomponent in component["parts"]:
			var files: Array = subcomponent["files"]
			var copyright: Array = subcomponent["copyright"]
			var license: String = subcomponent["license"]
			
			_license_label.bbcode_text += "\n\n\tFiles:\n"
			for file in files:
				_license_label.bbcode_text += "\t\t" + file + "\n"
			for copyright_line in copyright:
				_license_label.bbcode_text += "\t(c) " + copyright_line + "\n"
			_license_label.bbcode_text += "\tLicense: " + license
	
	# Include all of the license information at the end.
	_license_label.bbcode_text += "\n\n[center][u]Licenses[/u][/center]"
	var license_info = Engine.get_license_info()
	
	# Include any licenses that are not used by the engine.
	license_info["CC-BY-SA-4.0"] = preload("res://LICENSE_CC_BY-SA_4.0.tres").text
	var license_names_sorted = license_info.keys()
	license_names_sorted.sort()
	
	for license_name in license_names_sorted:
		var display_name: String = license_name
		if "Expat" in display_name:
			display_name += " / MIT"
		var license_data: String = license_info[license_name]
		
		if not _license_label.text.ends_with("\n"):
			_license_label.bbcode_text += "\n"
		
		_license_label.bbcode_text += "\n\n- %s\n\n[indent]%s[/indent]" % [
				display_name, license_data]

func _on_SingleplayerButton_pressed():
	Global.start_game_singleplayer()

func _on_MultiplayerButton_pressed():
	_multiplayer_dialog.popup_centered()

func _on_HostGameButton_pressed():
	Global.start_game_as_server()

func _on_EnterCodeButton_pressed():
	_enter_code_dialog.popup_centered()
	_multiplayer_dialog.visible = false

func _on_RoomCodeEdit_text_changed(new_text: String):
	var caret_position = _room_code_edit.caret_position
	_room_code_edit.text = new_text.to_upper()
	_room_code_edit.caret_position = caret_position

func _on_RoomCodeEdit_text_entered(_new_text):
	_on_JoinGameButton_pressed()

func _on_JoinGameButton_pressed():
	var room_code = _room_code_edit.text.to_upper()
	
	if room_code.length() != 4:
		display_error(tr("Room code must be four characters long!"))
		return
	
	for c in room_code:
		if not c in ALPHABET:
			display_error(tr("Invalid room code!"))
			return
	
	Global.start_game_as_client(room_code)

func _on_OptionsButton_pressed():
	_options_menu.visible = true

func _on_OptionsMenu_keep_video_dialog_hide():
	if not _options_menu.visible:
		_options_button.grab_focus()

func _on_OptionsMenu_locale_changed(_locale: String):
	_update_credits_text()
	_random_music_player.update_label_text()

func _on_OptionsMenu_visibility_changed():
	if not _options_menu.visible:
		_options_button.grab_focus()

func _on_CreditsButton_pressed():
	_credits_dialog.popup_centered()
	_credits_label.grab_focus()

func _on_QuitButton_pressed():
	get_tree().quit()

func _on_ImportErrorButton_pressed():
	_import_error_dialog.popup_centered()

func _on_WebsiteButton_pressed():
	OS.shell_open("https://tabletopclub.net")

func _on_CodeIcon_pressed():
	OS.shell_open("https://github.com/drwhut/tabletop-club")

func _on_HelpButton_pressed():
	OS.shell_open("https://docs.tabletopclub.net")

func _on_CommunityButton_pressed():
	OS.shell_open("https://tabletopclub.net/community")

func _on_DonateButton_pressed():
	OS.shell_open("https://ko-fi.com/drwhut")

func _on_InfoButton_pressed():
	_info_dialog.popup_centered()
	_license_label.grab_focus()
