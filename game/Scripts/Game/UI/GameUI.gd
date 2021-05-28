# tabletop-club
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

extends Control

signal about_to_save_table()
signal applying_options(config)
signal clear_pieces()
signal flipping_table(reset_table)
signal lighting_requested(lamp_color, lamp_intensity, lamp_sunlight)
signal load_table(path)
signal piece_requested(piece_entry, position)
signal piece_requested_in_container(piece_entry, container_name)
signal requesting_room_details()
signal rotation_amount_updated(rotation_amount)
signal save_table(path)
signal skybox_requested(skybox_entry)
signal stopped_saving_table()
signal table_requested(table_entry)

onready var _chat_box = $ChatBox
onready var _clear_table_button = $TopPanel/ClearTableButton
onready var _clear_table_dialog = $ClearTableConfirmDialog
onready var _file_dialog = $GameMenuBackground/FileDialog
onready var _flip_table_button = $TopPanel/FlipTableButton
onready var _game_menu_background = $GameMenuBackground
onready var _games_dialog = $GamesDialog
onready var _objects_dialog = $ObjectsDialog
onready var _options_menu = $OptionsMenu
onready var _player_list = $PlayerList
onready var _room_dialog = $RoomDialog
onready var _rotation_option = $TopPanel/RotationOption

var spawn_point_container_name: String = ""
var spawn_point_origin: Vector3 = Vector3(0, Piece.SPAWN_HEIGHT, 0)
var spawn_point_temp_offset: Vector3 = Vector3()

var _flip_table_status = false

# Apply options from the options menu.
# config: The options to apply.
func apply_options(config: ConfigFile) -> void:
	_chat_box.apply_options(config)

# Hide the chat box from the UI.
func hide_chat_box() -> void:
	_chat_box.visible = false

# Popup the objects menu dialog.
func popup_objects_dialog() -> void:
	_objects_dialog.popup_centered()

# Set the room details in the room dialog.
# table_entry: The table's asset DB entry.
# skybox_entry: The skybox's asset DB entry.
# lamp_color: The color of the room lamp.
# lamp_intensity: The intensity of the room lamp.
# lamp_sunlight: If the room lamp is emitting sunlight.
func set_room_details(table_entry: Dictionary, skybox_entry: Dictionary,
	lamp_color: Color, lamp_intensity: float, lamp_sunlight: bool) -> void:
	
	_room_dialog.set_room_details(table_entry, skybox_entry, lamp_color,
		lamp_intensity, lamp_sunlight)

# Set the table flipped status, so the flip table button can be updated.
# flip_table_status: If true, the button will represent resetting the table.
# If false, the button will represent flipping the table.
func set_flip_table_status(flip_table_status: bool) -> void:
	_flip_table_status = flip_table_status
	
	if flip_table_status:
		_flip_table_button.text = tr("Reset Table")
	else:
		_flip_table_button.text = tr("Flip Table")
	
	_clear_table_button.disabled = flip_table_status

func _ready():
	Lobby.connect("player_added", self, "_on_Lobby_player_added")
	Lobby.connect("player_modified", self, "_on_Lobby_player_modified")
	Lobby.connect("player_removed", self, "_on_Lobby_player_removed")
	
	# Make sure we emit the signal when all of the nodes are ready:
	call_deferred("_set_rotation_amount")
	
	# Make the file dialog point to the default "saves" folder.
	_file_dialog.current_dir = Global.get_output_subdir("saves").get_current_dir()

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		_game_menu_background.visible = not _game_menu_background.visible
		if not _game_menu_background.visible:
			_options_menu.visible = false
	
	elif event.is_action_pressed("game_toggle_ui"):
		visible = not visible

# Popup the file dialog in the given mode.
# mode: The mode to open the file dialog in.
func _popup_file_dialog(mode: int) -> void:
	if _file_dialog.current_dir == "/":
		_file_dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	_file_dialog.mode = mode
	_file_dialog.popup_centered()
	
	if mode == FileDialog.MODE_SAVE_FILE:
		emit_signal("about_to_save_table")

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

func _on_ClearTableButton_pressed():
	_clear_table_dialog.popup_centered()

func _on_ClearTableConfirmDialog_confirmed():
	emit_signal("clear_pieces")

func _on_DesktopButton_pressed():
	get_tree().quit()

func _on_FileDialog_file_selected(path: String):
	if _file_dialog.mode == FileDialog.MODE_OPEN_FILE:
		emit_signal("load_table", path)
	elif _file_dialog.mode == FileDialog.MODE_SAVE_FILE:
		emit_signal("save_table", path)
	
	_game_menu_background.visible = false

func _on_FileDialog_popup_hide():
	if _file_dialog.mode == FileDialog.MODE_SAVE_FILE:
		emit_signal("stopped_saving_table")

func _on_FlipTableButton_pressed():
	emit_signal("flipping_table", _flip_table_status)

func _on_GameMenuButton_pressed():
	_game_menu_background.visible = true

func _on_GamesButton_pressed():
	_games_dialog.popup_centered()

func _on_GamesDialog_entry_requested(_pack: String, _type: String, entry: Dictionary):
	_games_dialog.visible = false
	emit_signal("load_table", entry["table_path"])

func _on_LoadGameButton_pressed():
	_popup_file_dialog(FileDialog.MODE_OPEN_FILE)

func _on_Lobby_player_added(_id: int):
	_update_player_list()

func _on_Lobby_player_modified(_id: int, _old: Dictionary):
	_update_player_list()

func _on_Lobby_player_removed(_id: int):
	_update_player_list()

func _on_MainMenuButton_pressed():
	Global.start_main_menu()

func _on_ObjectsButton_pressed():
	spawn_point_container_name = ""
	spawn_point_temp_offset = Vector3()
	popup_objects_dialog()

func _on_ObjectsDialog_entry_requested(_pack: String, _type: String, entry: Dictionary):
	if spawn_point_container_name.empty():
		emit_signal("piece_requested", entry, spawn_point_origin + spawn_point_temp_offset)
	else:
		emit_signal("piece_requested_in_container", entry, spawn_point_container_name)

func _on_OptionsButton_pressed():
	_options_menu.visible = true

func _on_OptionsMenu_applying_options(config: ConfigFile):
	emit_signal("applying_options", config)

func _on_RoomButton_pressed():
	_room_dialog.popup_centered()

func _on_RoomDialog_requesting_room_details():
	emit_signal("requesting_room_details")

func _on_RoomDialog_setting_lighting(lamp_color: Color, lamp_intensity: float,
	lamp_sunlight: bool):
	
	_room_dialog.visible = false
	emit_signal("lighting_requested", lamp_color, lamp_intensity, lamp_sunlight)

func _on_RoomDialog_setting_skybox(skybox_entry: Dictionary):
	_room_dialog.visible = false
	emit_signal("skybox_requested", skybox_entry)

func _on_RoomDialog_setting_table(table_entry: Dictionary):
	_room_dialog.visible = false
	emit_signal("table_requested", table_entry)

func _on_RotationOption_item_selected(_index: int):
	_set_rotation_amount()

func _on_SaveGameButton_pressed():
	_popup_file_dialog(FileDialog.MODE_SAVE_FILE)
