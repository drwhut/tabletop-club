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

extends HBoxContainer

onready var _chat_container = $VBoxContainer
onready var _chat_text = $VBoxContainer/ChatText
onready var _message_edit = $VBoxContainer/HBoxContainer/MessageEdit
onready var _toggle_button = $ToggleButton

export(bool) var censoring_profanity: bool = true

var _profanity_list: Array = []

# Add a message in BBCode format to the chat box.
# raw_message: The message to add in BBCode format.
func add_raw_message(raw_message: String) -> void:
	_chat_text.bbcode_text += "\n" + raw_message
	
	# Print an unformatted version of the message to stdout.
	print(_chat_text.text.rsplit("\n", true, 1)[1])

# Apply options from the options menu.
# config: The options to apply.
func apply_options(config: ConfigFile) -> void:
	censoring_profanity = config.get_value("multiplayer", "censor_profanity")
	
	if censoring_profanity:
		_chat_text.bbcode_text = censor_profanity(_chat_text.bbcode_text)

# Given a string, return a new string with profanity hidden.
# Returns: A (hopefully) profanity-less string.
# string: The string to censor.
func censor_profanity(string: String) -> String:
	var lower_string = string.to_lower()
	
	# We are assuming the profanity list is in alphabetical order, and thus
	# prefixes will come first.
	for i in range(_profanity_list.size() - 1, -1, -1):
		var profanity = _profanity_list[i].to_lower()
		var j = 0
		while j >= 0:
			j = lower_string.find_last(profanity)
			if j >= 0:
				var censor = false
				if lower_string.length() == profanity.length():
					censor = true
				elif j == 0:
					# Most control and punctuation characters are below 65.
					if lower_string.ord_at(profanity.length()) < 65:
						censor = true
				elif j == lower_string.length() - profanity.length():
					if lower_string.ord_at(j - 1) < 65:
						censor = true
				else:
					if lower_string.ord_at(j - 1) < 65 and lower_string.ord_at(j + profanity.length()) < 65:
						censor = true
				
				if censor:
					string.erase(j, profanity.length())
					string = string.insert(j, "*".repeat(profanity.length()))
				lower_string = lower_string.substr(0, j)
	
	return string

# Check if the chat box is visible.
# Returns: If the chat box is visible.
func is_chat_visible() -> bool:
	return _chat_container.visible

# Send a message to the server if there is valid text in the text box.
func prepare_send_message() -> void:
	var message = _message_edit.text.strip_edges()
	if message.length() > 0:
		rpc_id(1, "send_message", message)
	
	_message_edit.clear()

# Called by the server to say a message was sent by someone.
remotesync func receive_message(sender_id: int, message: String) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	# Security!
	message = message.strip_edges().strip_escapes().replace("[", "[ ")
	if message.length() == 0:
		return
	
	if sender_id == 1:
		message = tr("Server: ") + message
	else:
		message = Lobby.get_name_bb_code(sender_id) + ": " + message
	
	if censoring_profanity:
		message = censor_profanity(message)
	
	add_raw_message(message)

# Send a message to the server.
# message: The message to send.
master func send_message(message: String) -> void:
	rpc("receive_message", get_tree().get_rpc_sender_id(), message)

# Set the chat box to be visible.
# chat_visible: Whether the chat box should be visible or not.
func set_chat_visible(chat_visible: bool) -> void:
	_chat_container.visible = chat_visible
	
	var text = ">"
	if chat_visible:
		text = "<"
	_toggle_button.text = text

func _ready():
	Lobby.connect("player_added", self, "_on_Lobby_player_added")
	Lobby.connect("player_modified", self, "_on_Lobby_player_modified")
	Lobby.connect("player_removed", self, "_on_Lobby_player_removed")
	
	set_chat_visible(true)
	
	_profanity_list = preload("res://Text/Profanity.tres").text.split("\n", false)

# Get a random string from an array.
# Returns: A random line from the given array.
# text_file: The array to get the line from.
func _random_string_from_array(array: Array) -> String:
	if array.empty():
		return ""
	
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var line = array[rng.randi() % array.size()]
	
	return line

func _on_Lobby_player_added(id: int):
	var name = Lobby.get_name_bb_code(id)
	add_raw_message(tr("%s has joined the game.") % name)

func _on_Lobby_player_modified(id: int, old: Dictionary):
	if old.empty():
		return
	
	var old_name = Lobby.get_name_bb_code_custom(old)
	var new_name = Lobby.get_name_bb_code(id)
	add_raw_message(tr("%s changed their name to %s") % [old_name, new_name])

func _on_Lobby_player_removed(id: int):
	var name = Lobby.get_name_bb_code(id)
	add_raw_message(tr("%s has left the game.") % name)

func _on_MessageEdit_text_entered(_new_text: String):
	prepare_send_message()

func _on_SendButton_pressed():
	prepare_send_message()

func _on_ToggleButton_pressed():
	set_chat_visible(not is_chat_visible())
