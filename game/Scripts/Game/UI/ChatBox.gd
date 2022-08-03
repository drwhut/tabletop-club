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

extends HBoxContainer

onready var _chat_container = $VBoxContainer
onready var _chat_text = $VBoxContainer/ChatBackground/ChatText
onready var _message_edit = $VBoxContainer/HBoxContainer/MessageEdit
onready var _toggle_button = $ToggleButton

const NUM_CHARS_BEFORE_TIMEOUT: int = 1000
const TIMEOUT_WAIT_TIME: float = 1.0

var _num_chars_recent: int = 0
var _time_since_last_msg: float = 0.0

# Add a message in BBCode format to the chat box.
# raw_message: The message to add in BBCode format.
# stdout: If true, also prints the message to the stdout buffer.
func add_raw_message(raw_message: String, stdout: bool = true) -> void:
	if _time_since_last_msg > TIMEOUT_WAIT_TIME:
		if _num_chars_recent >= NUM_CHARS_BEFORE_TIMEOUT:
			_chat_text.clear() # Clear tag stack.
		_num_chars_recent = 0
	
	if _num_chars_recent < NUM_CHARS_BEFORE_TIMEOUT:
		_num_chars_recent += raw_message.length()
		if _num_chars_recent >= NUM_CHARS_BEFORE_TIMEOUT:
			_chat_text.add_text("\n[%s]" % tr("Too much text being sent, waiting..."))
		else:
			_chat_text.bbcode_text += "\n" + raw_message
			_time_since_last_msg = 0.0
			
			# Print an unformatted version of the message to stdout.
			if stdout:
				print(_chat_text.text.rsplit("\n", true, 1)[1])

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
	
	message = Lobby.get_name_bb_code(sender_id) + ": " + message
	
	if Global.censoring_profanity:
		message = Global.censor_profanity(message)
	
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
	set_chat_visible(true)
	
	Global.connect("censor_changed", self, "_on_Global_censor_changed")

func _process(delta):
	_time_since_last_msg += delta

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

func _on_Global_censor_changed():
	if Global.censoring_profanity:
		_chat_text.bbcode_text = Global.censor_profanity(_chat_text.bbcode_text)

func _on_MessageEdit_text_entered(_new_text: String):
	prepare_send_message()

func _on_SendButton_pressed():
	prepare_send_message()

func _on_ToggleButton_pressed():
	set_chat_visible(not is_chat_visible())
