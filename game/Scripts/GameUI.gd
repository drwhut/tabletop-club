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

signal applying_options(config)
signal load_table(path)
signal piece_requested(piece_entry)
signal rotation_amount_updated(rotation_amount)
signal save_table(path)

onready var _chat_box = $ChatBox
onready var _file_dialog = $GameMenuBackground/FileDialog
onready var _game_menu_background = $GameMenuBackground
onready var _games_dialog = $GamesDialog
onready var _objects_dialog = $ObjectsDialog
onready var _options_menu = $OptionsMenu
onready var _player_list = $PlayerList
onready var _rotation_option = $TopPanel/RotationOption

# Apply options from the options menu.
# config: The options to apply.
func apply_options(config: ConfigFile) -> void:
	_chat_box.apply_options(config)

# Hide the chat box from the UI.
func hide_chat_box() -> void:
	_chat_box.visible = false

# Set the piece database contents, based on the piece database given.
# pieces: The database from the PieceDB.
func set_piece_db(pieces: Dictionary) -> void:
	_games_dialog.set_piece_db(pieces)
	_objects_dialog.set_piece_db(pieces)

func _ready():
	Lobby.connect("player_added", self, "_on_Lobby_player_added")
	Lobby.connect("player_modified", self, "_on_Lobby_player_modified")
	Lobby.connect("player_removed", self, "_on_Lobby_player_removed")
	
	# Make sure we emit the signal when all of the nodes are ready:
	call_deferred("_set_rotation_amount")

func _unhandled_input(event):
	if event.is_action_pressed("game_menu"):
		_game_menu_background.visible = not _game_menu_background.visible
		if not _game_menu_background.visible:
			_options_menu.visible = false

# Popup the file dialog in the given mode.
# mode: The mode to open the file dialog in.
func _popup_file_dialog(mode: int) -> void:
	_file_dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	_file_dialog.mode = mode
	_file_dialog.popup_centered()

# Call to emit a signal for the camera to set it's piece rotation amount.
func _set_rotation_amount() -> void:
	if _rotation_option.selected >= 0:
		var deg_id = _rotation_option.get_item_id(_rotation_option.selected)
		var deg_text = _rotation_option.get_item_text(deg_id)
		var rad = deg2rad(float(deg_text))
		emit_signal("rotation_amount_updated", rad)

# Update the player list based on what is in the Lobby.
func _update_player_list() -> void:
	var code = "[right][table=1]"
	
	for id in Lobby.get_player_list():
		code += "[cell]" + Lobby.get_name_bb_code(id) + "[/cell]"
	
	code += "[/table][/right]"
	_player_list.bbcode_text = code

func _on_BackToGameButton_pressed():
	_game_menu_background.visible = false

func _on_DesktopButton_pressed():
	get_tree().quit()

func _on_FileDialog_file_selected(path: String):
	if _file_dialog.mode == FileDialog.MODE_OPEN_FILE:
		emit_signal("load_table", path)
	elif _file_dialog.mode == FileDialog.MODE_SAVE_FILE:
		emit_signal("save_table", path)
	
	_game_menu_background.visible = false

func _on_GameMenuButton_pressed():
	_game_menu_background.visible = true

func _on_GamesButton_pressed():
	_games_dialog.popup_centered()

func _on_GamesDialog_loading_game(game_entry: Dictionary):
	_games_dialog.visible = false
	emit_signal("load_table", game_entry["table_path"])

func _on_LoadGameButton_pressed():
	_popup_file_dialog(FileDialog.MODE_OPEN_FILE)

func _on_Lobby_player_added(id: int):
	_update_player_list()

func _on_Lobby_player_modified(id: int, old: Dictionary):
	_update_player_list()

func _on_Lobby_player_removed(id: int):
	_update_player_list()

func _on_MainMenuButton_pressed():
	Global.start_main_menu()

func _on_ObjectsButton_pressed():
	_objects_dialog.popup_centered()

func _on_ObjectsDialog_piece_requested(piece_entry: Dictionary):
	emit_signal("piece_requested", piece_entry)

func _on_OptionsButton_pressed():
	_options_menu.visible = true

func _on_OptionsMenu_applying_options(config: ConfigFile):
	emit_signal("applying_options", config)

func _on_RotationOption_item_selected(index: int):
	_set_rotation_amount()

func _on_SaveGameButton_pressed():
	_popup_file_dialog(FileDialog.MODE_SAVE_FILE)
