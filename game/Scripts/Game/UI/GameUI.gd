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

signal about_to_save_table()
signal applying_options(config)
signal clear_pieces()
signal flipping_table()
signal leaving_room()
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
signal undo_state()

onready var _chat_box = $HideableUI/ChatBox
onready var _clear_table_button = $HideableUI/TopPanel/ClearTableButton
onready var _clear_table_dialog = $ClearTableConfirmDialog
onready var _flip_table_button = $HideableUI/TopPanel/FlipTableButton
onready var _game_menu_background = $CanvasLayer/GameMenuBackground
onready var _games_dialog = $GamesDialog
onready var _hideable_ui = $HideableUI
onready var _multiplayer_container = $HideableUI/MultiplayerContainer
onready var _notebook_dialog = $NotebookDialog
onready var _objects_dialog = $ObjectsDialog
onready var _options_menu = $CanvasLayer/OptionsMenu
onready var _player_list_container = $HideableUI/MultiplayerContainer/PlayerListContainer
onready var _room_code_label = $HideableUI/MultiplayerContainer/RoomCodeLabel
onready var _room_code_toggle_button = $HideableUI/MultiplayerContainer/RoomCodeVisibleContainer/RoomCodeToggleButton
onready var _room_dialog = $RoomDialog
onready var _rotation_option = $HideableUI/TopPanel/RotationOption
onready var _save_dialog = $CanvasLayer/GameMenuBackground/SaveDialog
onready var _undo_button = $HideableUI/TopPanel/UndoButton

var spawn_point_container_name: String = ""
var spawn_point_origin: Vector3 = Vector3(0, Piece.SPAWN_HEIGHT, 0)
var spawn_point_temp_offset: Vector3 = Vector3()

var _room_code: String = ""
var _room_code_visible: bool = true

# From the custom module:
# https://github.com/drwhut/tabletop_club_godot_module
var _error_reporter

func add_notification_info(message: String) -> void:
	_chat_box.add_raw_message("[color=aqua][INFO][/color] %s" % message, true)

func add_notification_warning(message: String) -> void:
	_chat_box.add_raw_message("[color=yellow][WARN] %s[/color]" % message, false)

func add_notification_error(message: String) -> void:
	_chat_box.add_raw_message("[color=red][ERROR] %s[/color]" % message, false)

# Apply options from the options menu.
# config: The options to apply.
func apply_options(config: ConfigFile) -> void:
	_chat_box.apply_options(config)

# Hide the multiplayer section of the UI.
func hide_multiplayer_ui() -> void:
	_multiplayer_container.visible = false

# Popup the objects menu dialog.
func popup_objects_dialog() -> void:
	_objects_dialog.popup_centered()

# Re-configure all of the asset dialogs, forcing them to read the AssetDB again.
# Use this if you know the AssetDB contents have changed.
func reconfigure_asset_dialogs() -> void:
	_objects_dialog.reconfigure()
	_games_dialog.reconfigure()
	_room_dialog.reconfigure()

# Set the room code that is displayed in the UI.
# room_code: The room code to display.
func set_room_code(room_code: String) -> void:
	_room_code = room_code
	_update_room_code_display()

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
# flip_table_status: If true, the table is assumed to have been flipped, and
# the flip table button is disabled. Otherwise, the table is assumed to be in
# it's normal state, and the button is enabled.
func set_flip_table_status(flip_table_status: bool) -> void:
	_flip_table_button.disabled = flip_table_status
	_clear_table_button.disabled = flip_table_status

func _ready():
	Lobby.connect("player_added", self, "_on_Lobby_player_added")
	Lobby.connect("player_modified", self, "_on_Lobby_player_modified")
	Lobby.connect("player_removed", self, "_on_Lobby_player_removed")
	
	if Global.error_reporter != null:
		Global.error_reporter.connect("error_received", self, "_on_error_received")
		Global.error_reporter.connect("warning_received", self, "_on_warning_received")
	else:
		push_warning("ErrorReporter does not exist! Make sure to install the TabletopClub Godot module.")
	
	# Make sure we emit the signal when all of the nodes are ready:
	call_deferred("_set_rotation_amount")
	
	# Make the save dialog point to the default "saves" folder.
	_save_dialog.save_dir = Global.get_output_subdir("saves").get_current_dir()

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		_game_menu_background.visible = not _game_menu_background.visible
		if not _game_menu_background.visible:
			_options_menu.visible = false
	
	elif event.is_action_pressed("game_toggle_ui"):
		_hideable_ui.visible = not _hideable_ui.visible

# Popup the save dialog in the given mode.
# save_mode: If the save dialog should open in save mode.
func _popup_save_dialog(save_mode: bool) -> void:
	_save_dialog.save_mode = save_mode
	_save_dialog.popup_centered()
	
	if save_mode:
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
	var player_id_list: Array = Lobby.get_player_list()
	
	# Before setting the names, check if there are any labels for players who
	# have since left the game.
	for label in _player_list_container.get_children():
		if label.name.is_valid_integer():
			if not int(label.name) in player_id_list:
				_player_list_container.remove_child(label)
				label.queue_free()
		else:
			push_warning("Player label name %s is not an integer, ignoring." % label.name)
	
	for player_id in player_id_list:
		var player_id_str = str(player_id)
		var label: RichTextLabel = null
		
		if _player_list_container.has_node(player_id_str):
			label = _player_list_container.get_node(player_id_str)
		else:
			label = RichTextLabel.new()
			label.name = player_id_str
			label.rect_min_size.y = 20
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.bbcode_enabled = true
			label.scroll_active = false
			_player_list_container.add_child(label)
		
		if label == null:
			push_error("Label for player %d could not be created!" % player_id)
			continue
		
		label.bbcode_text = "[right]%s[/right]" % Lobby.get_name_bb_code(player_id)

# Update the room code display.
func _update_room_code_display() -> void:
	var room_code_display = _room_code
	if not _room_code_visible:
		room_code_display = "*".repeat(_room_code.length())
	
	var text = "[right]" + tr("Room Code: [b]%s[/b]") % room_code_display + " [/right]"
	_room_code_label.bbcode_text = text
	
	if _room_code_visible:
		_room_code_toggle_button.text = tr("Hide Room Code")
	else:
		_room_code_toggle_button.text = tr("Show Room Code")

func _on_BackToGameButton_pressed():
	_game_menu_background.visible = false

func _on_ClearTableButton_pressed():
	_clear_table_dialog.popup_centered()

func _on_ClearTableConfirmDialog_confirmed():
	emit_signal("clear_pieces")

func _on_DesktopButton_pressed():
	emit_signal("leaving_room")
	get_tree().quit()

func _on_error_received(function: String, file: String, line: int,
	error: String, _errorexp: String):
	
	# In the event that an error is caused by this code, disconnect the signal
	# so that a stack overflow does not occur.
	if Global.error_reporter != null:
		Global.error_reporter.disconnect("error_received", self, "_on_error_received")
	
	# An error could occur while the chat box was in the middle of drawing (in
	# another thread), so wait until a time where the chat box is guaranteed
	# to not be in the middle of it's _draw().
	call_deferred("add_notification_error", "%s:%d %s: %s" % [file, line,
			function, error])
	
	if Global.error_reporter != null:
		Global.error_reporter.connect("error_received", self, "_on_error_received")

func _on_FlipTableButton_pressed():
	emit_signal("flipping_table")

func _on_GameMenuButton_pressed():
	_game_menu_background.visible = true

func _on_GamesButton_pressed():
	_games_dialog.popup_centered()

func _on_GamesDialog_entry_requested(_pack: String, _type: String, entry: Dictionary):
	_games_dialog.visible = false
	emit_signal("load_table", entry["table_path"])

func _on_GameUI_tree_exiting():
	if Global.error_reporter != null:
		if Global.error_reporter.is_connected("error_received", self, "_on_error_received"):
			Global.error_reporter.disconnect("error_received", self, "_on_error_received")
		
		if Global.error_reporter.is_connected("warning_received", self, "_on_warning_received"):
			Global.error_reporter.disconnect("warning_received", self, "_on_warning_received")

func _on_LoadGameButton_pressed():
	_popup_save_dialog(false)

func _on_Lobby_player_added(id: int):
	var name = Lobby.get_name_bb_code(id)
	add_notification_info(tr("%s has joined the game.") % name)
	_update_player_list()

func _on_Lobby_player_modified(id: int, old: Dictionary):
	if not old.empty():
		var old_name = Lobby.get_name_bb_code_custom(old)
		var new_name = Lobby.get_name_bb_code(id)
		add_notification_info(tr("%s changed their name to %s") % [old_name, new_name])
	_update_player_list()

func _on_Lobby_player_removed(id: int):
	var name = Lobby.get_name_bb_code(id)
	add_notification_info(tr("%s has left the game.") % name)
	call_deferred("_update_player_list")

func _on_MainMenuButton_pressed():
	emit_signal("leaving_room")
	Global.start_main_menu()

func _on_NotebookButton_pressed():
	_notebook_dialog.popup_centered()

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

func _on_Room_undo_stack_empty():
	_undo_button.disabled = true

func _on_Room_undo_stack_pushed():
	_undo_button.disabled = false

func _on_RoomButton_pressed():
	_room_dialog.popup_centered()

func _on_RoomCodeToggleButton_pressed():
	_room_code_visible = not _room_code_visible
	_update_room_code_display()

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

func _on_SaveDialog_load_file(path: String):
	emit_signal("load_table", path)
	_game_menu_background.visible = false

func _on_SaveDialog_popup_hide():
	if _save_dialog.save_mode:
		emit_signal("stopped_saving_table")

func _on_SaveDialog_save_file(path: String):
	emit_signal("save_table", path)
	_game_menu_background.visible = false

func _on_SaveGameButton_pressed():
	_popup_save_dialog(true)

func _on_UndoButton_pressed():
	emit_signal("undo_state")

func _on_warning_received(function: String, file: String, line: int,
	error: String, _errorexp: String):
	
	# In the event that a warning is caused by this code, disconnect the signal
	# so that a stack overflow does not occur.
	if Global.error_reporter != null:
		Global.error_reporter.disconnect("warning_received", self, "_on_warning_received")
	
	# An error could occur while the chat box was in the middle of drawing (in
	# another thread), so wait until a time where the chat box is guaranteed
	# to not be in the middle of it's _draw().
	call_deferred("add_notification_warning", "%s:%d %s: %s" % [file, line,
			function, error])
	
	if Global.error_reporter != null:
		Global.error_reporter.connect("warning_received", self, "_on_warning_received")
